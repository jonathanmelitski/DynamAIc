//
//  OpenAINetworkManager.swift
//  DynamAIc
//
//  Created by Jonathan Melitski on 4/14/25.
//
import Foundation
import AppKit

class OpenAINetworkManager {
    
    static let strategist = false
    static let strategistModel = "gpt-4.1-mini"
    
    static func getAssistantResponse(_ message: String, continuing previous: DynamAIcResponse? = nil) async throws -> DynamAIcResponse {
        let finalResponse = DynamAIcResponse(message)
        let executorResponse: OpenAIAPIResponse
        if strategist {
            // Strategist function calls not included in final front-end response
            let strategistRequest = OpenAIAPIRequest(model: Self.strategistModel, input: message, instructions: Self.strategistInstructionContents, previousResponseId: previous?.response.id, toolChoice: .init(value: "required"))
            let strategistResponse = try await Self.executeOpenAIRequest(strategistRequest)
            guard let strategy = strategistResponse.textMessage else { throw OpenAIError.noStrategy(finalResponse) }
            let messageCombined =
                    """
                        <REQUEST>
                        \(message)
                        </REQUEST>
                    
                        <PLAN FROM STRATEGIST>
                        \(strategy)
                        </PLAN>
                    """
            let executorRequest = OpenAIAPIRequest(input: messageCombined, instructions: Self.executorInstructionContents, previousResponseId: previous?.response.id)
            executorResponse = try await executeOpenAIRequest(executorRequest)
        } else {
            let request = OpenAIAPIRequest(model: "gpt-4.1", input: message, instructions: Self.singleExecutorInstructionContents, previousResponseId: previous?.response.id)
            executorResponse = try await Self.executeOpenAIRequest(request)
        }
        finalResponse.response.id = executorResponse.id
        finalResponse.response.error = executorResponse.error?.message
        finalResponse.response.outputText = executorResponse.textMessage
        if let err = finalResponse.response.error { throw OpenAIError.openAIReportedError(err, finalResponse) }
        guard let _ = finalResponse.response.outputText else { throw OpenAIError.noMessageReturned(finalResponse) }
        
        return finalResponse
    }
    
    static func executeOpenAIRequest(_ req: OpenAIAPIRequest, forInProgressResponse response: DynamAIcResponse? = nil) async throws -> OpenAIAPIResponse {
        let res = try await Self.sendOpenAIAPIRequest(req)
        return try await Self.executeFunctionCalls(for: res, given: req, reportCallsTo: response)
    }
    
    static func sendOpenAIAPIRequest(_ req: OpenAIAPIRequest) async throws -> OpenAIAPIResponse {
        let url = URL(string: "https://api.openai.com/v1/responses")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(try ConfigurationKey.openAIAPIKey.getString())", forHTTPHeaderField: "Authorization")

        request.httpBody = try JSONEncoder().encode(req)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        return try JSONDecoder().decode(OpenAIAPIResponse.self, from: data)
    }
    
    static func executeFunctionCalls(for response: OpenAIAPIResponse, given request: OpenAIAPIRequest, reportCallsTo inProgressResponse: DynamAIcResponse? = nil) async throws -> OpenAIAPIResponse {
        if response.functionCalls.isEmpty {
            return response
        }
        
        return try await withThrowingTaskGroup(of: (OpenAIFunctionInput, (any OpenAIInput)?).self) { group in
            let functions = response.functionCalls
            functions.forEach { function in
                group.addTask {
                    print(function.name)
                    guard let matchedFunc = OpenAIFunction.defaultFunctions.first(where: { $0.name == function.name }) else {
                        throw OpenAIError.callToNonExistantFunction(function, inProgressResponse)
                    }
                    
                    let result: OpenAIFunctionInput
                    let callbackInput: (any OpenAIInput)?
                    
                    let out = await matchedFunc.executorFunction?(function.arguments)
                        ?? "Failed to execute this function. Consider using a different function or workaround. Be creative."
                    result = OpenAIFunctionInput(
                        callId: function.callId,
                        output: out)
                    callbackInput = await matchedFunc.callbackInput?(function)
                    
                    inProgressResponse?.functionCalled(function: function, result: result, sentCallback: callbackInput)
                    return (result, callbackInput)
                }
            }
            
            var functionOutputsToSend: [OpenAIFunctionInput] = []
            var callbackOutputsToSend: [any OpenAIInput] = []
            for try await (res, callbackInput) in group {
                functionOutputsToSend.append(res)
                if let callbackInput {
                    callbackOutputsToSend.append(callbackInput)
                }
            }
        
            var finalResponse: OpenAIAPIResponse = response
            
            // Recursively call all functions prior to sending callback message to ensure valid state.
            if !functionOutputsToSend.isEmpty {
                let res = try await Self.sendOpenAIAPIRequest(.init(
                    model: request.model,
                    input: functionOutputsToSend,
                    instructions: request.instructions, previousResponseId: finalResponse.id,
                    tools: request.tools
                ))
                finalResponse = try await Self.executeFunctionCalls(for: res, given: request, reportCallsTo: inProgressResponse)
            }
            
            if !callbackOutputsToSend.isEmpty {
                let res = try await Self.sendOpenAIAPIRequest(.init(
                    model: request.model,
                    input: callbackOutputsToSend,
                    instructions: request.instructions, previousResponseId: finalResponse.id,
                    tools: request.tools
                ))
                finalResponse = try await Self.executeFunctionCalls(for: res, given: request, reportCallsTo: inProgressResponse)
            }

            return try await Self.executeFunctionCalls(for: finalResponse, given: request, reportCallsTo: inProgressResponse)
        }
    }
}

enum OpenAIError: LocalizedError {
    case callToNonExistantFunction(OpenAIFunctionCallRequest, DynamAIcResponse?)
    case openAIReportedError(String, DynamAIcResponse)
    case noMessageReturned(DynamAIcResponse)
    case noStrategy(DynamAIcResponse)
}
