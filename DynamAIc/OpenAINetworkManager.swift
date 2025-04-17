//
//  OpenAINetworkManager.swift
//  DynamAIc
//
//  Created by Jonathan Melitski on 4/14/25.
//
import Foundation
import AppKit

class OpenAINetworkManager {
    static func getAssistantResponse(_ message: String) async throws -> DynamAIcResponse {
        let strategistRequest = OpenAIAPIRequest(model: "gpt-4.1-mini", input: message, instructions: Self.strategistInstructionContents)
        let strategistResponse = try await Self.executeOpenAIRequest(strategistRequest)
        guard let strategy = strategistResponse.textMessage else { throw OpenAINetworkError.noStrategy }
        
        let messageCombined =
                    """
                        <REQUEST>
                        \(message)
                        </REQUEST>

                        <PLAN FROM STRATEGIST>
                        \(strategy)
                        </PLAN>
                    """
        let executorRequest = OpenAIAPIRequest(input: messageCombined)
        let executorResponse = try await executeOpenAIRequest(executorRequest)
        guard let response = executorResponse.textMessage else { throw OpenAINetworkError.noMessageReturned }
        
        return DynamAIcResponse(message: response)
    }
    
    static func executeOpenAIRequest(_ req: OpenAIAPIRequest) async throws -> OpenAIAPIResponse {
        let res = try await Self.sendOpenAIAPIRequest(req)
        return try await Self.executeFunctionCalls(for: res, given: req)
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
    
    static func executeFunctionCalls(for response: OpenAIAPIResponse, given request: OpenAIAPIRequest) async throws -> OpenAIAPIResponse {
        if response.functionCalls.isEmpty {
            return response
        }
        
        return try await withThrowingTaskGroup(of: (OpenAIFunctionInput, (any OpenAIInput)?).self) { group in
            let functions = response.functionCalls
            functions.forEach { function in
                group.addTask {
                    print(function.name)
                    guard let matchedFunc = OpenAIFunction.defaultFunctions.first(where: { $0.name == function.name }) else {
                        throw OpenAIError.callToNonExistantFunction(function)
                    }
                    
                    let result: OpenAIFunctionInput
                    let callbackInput: (any OpenAIInput)?
                    switch matchedFunc.name {
                    case "take-screenshot":
                        let img = await AIScreenshotManager.takeScreenshot()
                        result = OpenAIFunctionInput(
                            callId: function.callId,
                            output: img != nil ?
                            "Screenshot successful, sending output. Will be handled by another call." :
                                "Failed to capture image")
                        if let img {
                            callbackInput = OpenAIImageContentInput(image: img, message: request.textInput ?? "Here is the image. Proceed with the original request.")
                        } else {
                            callbackInput = nil
                        }
                    default:
                        let out = await matchedFunc.executorFunction?(function.arguments)
                            ?? "Failed to execute this function. Consider using a different function or workaround. Be creative."
                        result = OpenAIFunctionInput(
                            callId: function.callId,
                            output: out)
                        callbackInput = nil
                    }
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
            if !functionOutputsToSend.isEmpty {
                let res = try await Self.sendOpenAIAPIRequest(.init(
                    model: request.model,
                    input: functionOutputsToSend,
                    instructions: request.instructions, previousResponseId: finalResponse.id,
                    tools: request.tools,
                    toolChoice: request.toolChoice
                ))
                finalResponse = try await Self.executeFunctionCalls(for: res, given: request)
            }
            
            if !callbackOutputsToSend.isEmpty {
                let res = try await Self.sendOpenAIAPIRequest(.init(
                    model: request.model,
                    input: callbackOutputsToSend,
                    instructions: request.instructions, previousResponseId: finalResponse.id,
                    tools: request.tools,
                    toolChoice: request.toolChoice
                ))
                finalResponse = try await Self.executeFunctionCalls(for: res, given: request)
            }

            return try await Self.executeFunctionCalls(for: finalResponse, given: request)
        }
    }
    
    enum OpenAIError: Error {
        case callToNonExistantFunction(OpenAIFunctionCallRequest)
    }

}



enum OpenAINetworkError: Error {
    case noMessageReturned
    case noStrategy
}

// MARK: Context and Instructions
extension OpenAINetworkManager {
    static var markdownInstructionContents: String {
        guard let file = Bundle.main.path(forResource: "Instructions", ofType: "md"),
              let contents = try? String(contentsOfFile: file, encoding: .utf8) else { return "" }
        return contents
    }
    
    static var strategistInstructionContents: String {
        guard let file = Bundle.main.path(forResource: "StrategistInstructions", ofType: "md"),
              let contents = try? String(contentsOfFile: file, encoding: .utf8) else { return "" }
        return contents
    }
    
    static var defaultTools: [OpenAIGenericTool] {
        return OpenAIFunction.defaultFunctions.map({ return OpenAIGenericTool($0) })
    }
    
    
    private static let developerMessage: OpenAIMessage = .init(
        role: "developer",
        content: OpenAINetworkManager.markdownInstructionContents)
    
    
    
}



// MARK: Models
struct OpenAIAPIRequest: Encodable {
    var model: String
    let input: OpenAIInputs
    let instructions: String
    let tools: [OpenAIGenericTool]
    let previousResponseId: String?
    let toolChoice: String
    let parallelToolCalls: Bool
    
    var textInput: String? {
        guard let firstText = input.inputs.first(where: { $0 is OpenAIContentInput }) else {
            return nil
        }
        return (firstText as? OpenAIContentInput)?.content
    }
    
    init(model: String = "gpt-4.1", input: any OpenAIInput, instructions: String = OpenAINetworkManager.markdownInstructionContents, previousResponseId: String? = nil, tools: [OpenAIGenericTool] = OpenAINetworkManager.defaultTools, toolChoice: String = "auto") {
        self.init(model: model, input: [input], instructions: instructions, previousResponseId: previousResponseId, tools: tools, toolChoice: toolChoice)
        
    }
    
    init(model: String = "gpt-4.1", input: String, instructions: String = OpenAINetworkManager.markdownInstructionContents, previousResponseId: String? = nil, tools: [OpenAIGenericTool] = OpenAINetworkManager.defaultTools, toolChoice: String = "auto") {
        self.init(model: model, input: OpenAIContentInput(content: input), instructions: instructions, previousResponseId: previousResponseId, tools: tools, toolChoice: toolChoice)
    }
    
    init(model: String = "gpt-4.1", input: [any OpenAIInput], instructions: String = OpenAINetworkManager.markdownInstructionContents, previousResponseId: String? = nil, tools: [OpenAIGenericTool] = OpenAINetworkManager.defaultTools, toolChoice: String = "auto") {
        self.model = model
        self.input = OpenAIInputs(inputs: input)
        self.instructions = instructions
        self.previousResponseId = previousResponseId
        self.toolChoice = toolChoice
        self.tools = tools
        self.parallelToolCalls = true
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(instructions, forKey: .instructions)
        if let prev = previousResponseId {
            try container.encode(prev, forKey: .previousResponseId)
        }
        try container.encode(tools, forKey: .tools)
        try container.encode(toolChoice, forKey: .toolChoice)
        try container.encode(parallelToolCalls, forKey: .parallelToolCalls)
        
        try container.encode(input, forKey: .input)
    }
    
    enum CodingKeys: String, CodingKey {
        case model
        case instructions
        case input
        case previousResponseId = "previous_response_id"
        case tools
        case toolChoice = "tool_choice"
        case parallelToolCalls = "parallel_tool_calls"
    }
}

struct OpenAIInputs: Encodable {
    let inputs: [any OpenAIInput]
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        try inputs.forEach {
            switch $0 {
            case let value as OpenAIContentInput:
                try container.encode(value)
            case let value as OpenAIFunctionInput:
                try container.encode(value)
            case let value as OpenAIImageContentInput:
                try container.encode(value)
            default:
                throw EncodingError.invalidValue($0 as Any, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
            }
        }
    }
}

protocol OpenAIInput: Encodable {}

struct OpenAIContentInput: OpenAIInput {
    let content: String
    let role: String
    
    init(content: String, role: String = "user") {
        self.content = content
        self.role = role
    }
}

struct OpenAIImageContentInput: OpenAIInput {
    let content: OpenAIImageContent
    let role: String
    
    init(image: CGImage, message: String, role: String = "user") {
        self.content = OpenAIImageContent(
            text: OpenAIImageContentText(
                text: message,
                type: "input_text"),
            image: OpenAIImageContentImage(image: image, patchSize: 32, maxPatches: 1536))
        self.role = role
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        try container.encode(content, forKey: .content)
    }
    
    enum CodingKeys: String, CodingKey {
        case content
        case role
    }
}

struct OpenAIImageContent: Encodable {
    let text: OpenAIImageContentText
    let image: OpenAIImageContentImage
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(image)
        try container.encode(text)
    }
}

//extension Array where Element == OpenAIImageContent {
//    func encode(to encoder: any Encoder) throws {
//        try self.forEach { el in
//            switch el {
//            case let value as OpenAIFunction:
//                try value.encode(to: encoder)
//            case let value as OpenAIWebSearch:
//                try value.encode(to: encoder)
//            }
//        }
//    }
//}



struct OpenAIImageContentText: Encodable {
    let text: String
    let type: String
}

struct OpenAIImageContentImage: Encodable {
    let type: String
    let imageUrl: String
    
    init(image: CGImage, patchSize: Int, maxPatches: Int) {
        let base64Img = AIScreenshotManager.base64Image(image, patchSize: patchSize, maxPatches: maxPatches)
        self.type = "input_image"
        self.imageUrl = "data:image/png;base64,\(base64Img)"
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case imageUrl = "image_url"
    }
}


struct OpenAIGenericTool: OpenAITool {
    let type: String
    let body: (any OpenAITool)?
    
    init(_ function: OpenAIFunction) {
        self.type = function.type
        self.body = function
    }
    
    init(webSearch web: Bool) {
        let web = OpenAIWebSearch()
        self.type = web.type
        self.body = web
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)
        switch self.type {
        case "function":
            body = try OpenAIFunction(from: decoder)
        case "web_search_preview":
            body = try OpenAIWebSearch(from: decoder)
        default:
            body = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)

        switch body {
        case let value as OpenAIFunction:
            try value.encode(to: encoder)
        case let value as OpenAIWebSearch:
            try value.encode(to: encoder)
        case nil:
            break
        default:
            throw EncodingError.invalidValue(body as Any, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case type
    }
    
}

struct OpenAIWebSearch: OpenAITool {
    let type: String = "web_search_preview"
}

protocol OpenAITool: Codable {
    var type: String { get }
}

struct OpenAIFunctionInput: OpenAIInput {
    let callId: String
    let output: String
    let type: String
    
    init(callId: String, output: String, type: String = "function_call_output") {
        self.callId = callId
        self.output = output
        self.type = type
    }
    
    enum CodingKeys: String, CodingKey {
        case callId = "call_id"
        case output
        case type
    }
}

struct OpenAIError: Codable {
    let code: String
    let message: String
}

struct OpenAIGeneric: Codable {
    let type: String
    let id: String
    let body: (any OpenAIOutput)?
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)
        self.id = try container.decode(String.self, forKey: .id)
        switch self.type {
        case "message":
            body = try OpenAIMessageResponse(from: decoder)
        case "function_call":
            body = try OpenAIFunctionCallRequest(from: decoder)
        default:
            body = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(id, forKey: .id)

        switch body {
        case let value as OpenAIMessageResponse:
            try value.encode(to: encoder)
        case let value as OpenAIFunctionCallRequest:
            try value.encode(to: encoder)
        case nil:
            break
        default:
            throw EncodingError.invalidValue(body as Any, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case id
    }
}

struct OpenAIMessageResponse: OpenAIOutput {
    let id: String
    let role: String
    let content: [OpenAIMessageContent]
}

struct OpenAIMessageContent: Codable {
    let type: String
    let text: String
}

struct OpenAIFunctionCallRequest: OpenAIOutput {
    let id: String
    let type: String
    let callId: String
    let name: String
    let arguments: [String: String]
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.type = try container.decode(String.self, forKey: .type)
        self.callId = try container.decode(String.self, forKey: .callId)
        self.name = try container.decode(String.self, forKey: .name)
        
        let dec = JSONDecoder()
        let strData = try container.decode(String.self, forKey: .arguments).data(using: .utf8)
        self.arguments = try dec.decode([String:String].self, from: strData ?? Data())
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case callId = "call_id"
        case name
        case arguments
    }
}

protocol OpenAIOutput: Codable, Identifiable {
    var id: String { get }
}

struct OpenAIAPIResponse: Codable, Identifiable {
    let id: String?
    let error: OpenAIError?
    let output: [OpenAIGeneric]?
    
    var functionCalls: [OpenAIFunctionCallRequest] {
        return output?.filter({ $0.type == "function_call" && $0.body != nil }).compactMap {($0.body! as! OpenAIFunctionCallRequest)} ?? []
    }
    
    var textMessage: String? {
        let msgBody = self.output?.last(where: {
            $0.body is OpenAIMessageResponse
        })
        
        guard let body = msgBody?.body,
              let msg = body as? OpenAIMessageResponse else {
            return nil }
        return msg.content.first?.text
    }
    
    
}

struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIFunction: OpenAITool {
    let type: String
    let name: String
    let description: String
    let parameters: OpenAIFunctionParameter
    let strict: Bool
    let executorFunction: (([String: String]) async -> String)?
    
    init(type: String = "function", name: String, description: String, parameters: OpenAIFunctionParameter, strict: Bool, executorFunction: (([String:String]) async -> String)?) {
        self.type = type
        self.name = name
        self.description = description
        self.parameters = parameters
        self.strict = strict
        self.executorFunction = executorFunction
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decode(String.self, forKey: .description)
        self.parameters = try container.decode(OpenAIFunctionParameter.self, forKey: .parameters)
        self.strict = try container.decode(Bool.self, forKey: .name)
        self.executorFunction = nil
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(parameters, forKey: .parameters)
        try container.encode(strict, forKey: .strict)
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case name
        case description
        case parameters
        case strict
        
    }
    
    static let defaultFunctions: [OpenAIFunction] = [
        .init(name: "fetch-local-storage",
              description: "When the user asks for something relating to memory/persistent data, this function returns the entire stored data in a key-value dictionary",
              parameters: .init(
                type: "object",
                properties: [:],
                required: [],
                additionalProperties: false),
              strict: false,
              executorFunction: { _ in return "{go to the gym, zoom personal PMI: 3641119944}"}),
        .init(name: "current-date",
              description: "When the user asks for date-specific information, you are granted access to this information using this function, which returns an ISO-8601 string. Note, you do not have to use the entire data for any given response. If the user asks for the time, give it to them in their local time zone.",
              parameters: .init(
                type: "object",
                properties: [:],
                required: [],
                additionalProperties: false),
              strict: false,
              executorFunction: { _ in
                  let formatter = ISO8601DateFormatter()
                  formatter.timeZone = Calendar.current.timeZone
                  return formatter.string(from: Date.now)
              }),
        .init(name: "open-url-in-browser",
              description: "When the user asks to be taken to a specific webpage (or if it would help with your response, like a tutorial or something), you can call this function which will open this page in the default browser.",
              parameters: .init(
                type: "object",
                properties: ["url": .init(
                    type: "string",
                    enumerable: nil,
                    description: "The https url that should be opened by the browser.")],
                required: ["url"],
                additionalProperties: false),
              strict: true,
              executorFunction: { props in
                  guard let urlStr = props["url"],
                        let url = URL(string: urlStr),
                        url.scheme == "https" else {
                      return "Invalid input"
                  }
                  
                  guard let (_,response) = try? await URLSession.shared.data(from: url),
                            let http = response as? HTTPURLResponse else {
                      return "Unable to connect to target website"
                  }
                  guard http.statusCode == 200 else {
                      return "Website does not return OK status code, instead returned \(http.statusCode)"
                  }
                  
                  
                  NSWorkspace.shared.open(url)
                  return "Successfully opened: \(url.absoluteString)"
              }),
        .init(name: "take-screenshot",
              description: "When the user asks for help or information on their screen, you can use this function to get a capture of their running application. Can fail if screenshot permission is not allowed",
              parameters: .init(type: "object", properties: [:], required: [], additionalProperties: false),
              strict: true,
              executorFunction: nil),
        .init(name: "ask-strategist",
              description: "When we deviate from the plan, something isn't where the strategist thought it would be, or something that might change the plan, we should ask the strategist to come up with a revised plan with the information.",
              parameters: .init(type: "object",
                                properties: [
                                    "message": .init(
                                        type: "string",
                                        enumerable: nil,
                                        description: "The message that you're sending the strategist. Should talk about what the original plan was, what you tried, why you think it's not going to work, and what the new plan should be. Ask if there are some more APIs that you could call that might solve the problem."),
                                    "originalRequest": .init(
                                        type: "string",
                                        enumerable: nil,
                                        description: "An exact copy of the user's original request.")],
                                required: ["message", "originalRequest"],
                                additionalProperties: false),
              strict: true,
              executorFunction: { params in
                  guard let msg = params["message"], let req = params["originalRequest"] else { return "You didn't give the strategist a message or the original request."}
                  let messageCombined =
                              """
                                <CALLBACK FROM EXECUTOR>
                                \(msg)
                                </CALLBACK FROM EXECUTOR>
                              
                                <ORIGINAL REQUEST>
                                \(req)
                                </ORIGINAL REQUEST>
                              """
                  let strategistRequest = OpenAIAPIRequest(model: "gpt-4.1", input: messageCombined, instructions: OpenAINetworkManager.strategistInstructionContents)
                  guard let strategistResponse = try? await OpenAINetworkManager.executeOpenAIRequest(strategistRequest),
                        let newStrategy = strategistResponse.textMessage else {
                      return "SYSTEM MESSAGE: The strategist did not respond. Try with the original request as best you can."
                  }
                  
                  return newStrategy
              }),
        .init(name: "get-request-public",
              description: "A general, unauthenticated GET-request for an API. The details you give will be execute exactly as given with no authentication injected into the request. You will be returned the exact data returned by the request, encoded as UTF-8. Importantly, so that you don't lose context, if you have the ability to filter results or only include necessary fields, you should do so.",
              parameters: .init(type: "object",
                                properties: [
                                    "url": .init(
                                        type: "string",
                                        enumerable: nil,
                                        description: "The complete URL that will be placed in the get request. Should include all necessary query parameters in-line")],
                                required: ["url"],
                                additionalProperties: false),
              strict: true,
              executorFunction: { params in
                  guard let urlStr = params["url"] else { return "You didn't provide a URL."}
                  guard let url = URL(string: urlStr) else {return "The URL you provided was invalid."}
                  
                  guard let (data, response) = try? await URLSession.shared.data(from: url),
                        let http = response as? HTTPURLResponse else { return "Unable to execute GET request." }
                  
                  guard http.statusCode == 200 else { return "Server returned error code \(http.statusCode)"}
                  guard let dataStr = String(data: data, encoding: .utf8) else { return "Unable to parse data"}
                  return dataStr
              })
    ]
}

struct OpenAIFunctionParameter: Codable {
    let type: String
    let properties: [String: OpenAIParameterProperty]
    let required: [String]
    let additionalProperties: Bool
    
    enum CodingKeys: String, CodingKey {
        case type
        case properties
        case required
        case additionalProperties = "additionalProperties"
    }
}

struct OpenAIParameterProperty: Codable {
    let type: String
    let enumerable: [String]?
    let description: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case enumerable = "enum"
        case description
    }
}

