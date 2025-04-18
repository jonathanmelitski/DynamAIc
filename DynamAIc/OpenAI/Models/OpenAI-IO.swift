//
//  OpenAI-IO.swift
//  DynamAIc
//
//  Created by Jonathan Melitski on 4/18/25.
//
import Foundation

// MARK: Send TO OpenAI
struct OpenAIAPIRequest: Encodable {
    var model: String
    let input: OpenAIInputs
    let instructions: String
    let tools: [OpenAITool]
    let previousResponseId: String?
    let toolChoice: String
    let parallelToolCalls: Bool
    
    var textInput: String? {
        guard let firstText = input.inputs.first(where: { $0 is OpenAIContentInput }) else {
            return nil
        }
        return (firstText as? OpenAIContentInput)?.content
    }
    
    init(model: String = "gpt-4.1-mini", input: any OpenAIInput, instructions: String = OpenAINetworkManager.markdownInstructionContents, previousResponseId: String? = nil, tools: [OpenAITool] = OpenAINetworkManager.defaultTools, toolChoice: String = "auto") {
        self.init(model: model, input: [input], instructions: instructions, previousResponseId: previousResponseId, tools: tools, toolChoice: toolChoice)
        
    }
    
    init(model: String = "gpt-4.1-mini", input: String, instructions: String = OpenAINetworkManager.markdownInstructionContents, previousResponseId: String? = nil, tools: [OpenAITool] = OpenAINetworkManager.defaultTools, toolChoice: String = "auto") {
        self.init(model: model, input: OpenAIContentInput(content: input), instructions: instructions, previousResponseId: previousResponseId, tools: tools, toolChoice: toolChoice)
    }
    
    init(model: String = "gpt-4.1-mini", input: [any OpenAIInput], instructions: String = OpenAINetworkManager.markdownInstructionContents, previousResponseId: String? = nil, tools: [OpenAITool] = OpenAINetworkManager.defaultTools, toolChoice: String = "auto") {
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

// MARK: Receive FROM OpenAI

struct OpenAIAPIResponse: Codable, Identifiable {
    let id: String?
    let error: OpenAIErrorBody?
    let output: [OpenAIOutput]?
    
    var functionCalls: [OpenAIFunctionCallRequest] {
        return output?.filter({ $0.type == "function_call" }).compactMap {($0.body as! OpenAIFunctionCallRequest)} ?? []
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

struct OpenAIErrorBody: Codable {
    let code: String
    let message: String
}
