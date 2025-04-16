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
        let res = try await Self.sendOpenAIAPIRequest(OpenAIAPIRequest(input: message, instructions: Self.markdownInstructionContents))
        
        var fCalls = res.output?.filter({ $0.type == "function_call" && $0.body != nil }).compactMap {($0.body! as! OpenAIFunctionCallRequest)} ?? []
        
        var prev = res
        while !fCalls.isEmpty {
            let f = fCalls.removeFirst()
            print(f.name)
            let matchedFunc = Self.defaultFunctions.first(where: { $0.name == f.name })
             // handle image logic
            let req: OpenAIAPIRequest
            if matchedFunc?.name == "take-screenshot" {
                // get screenshot image
                // create a new request state where:
                //      input_text is the original request
                //      image is the base64
                // prev response ID should be the id (not call_id of function request)
                if let img = await AIScreenshotManager.getBase64ScreenshotImage(patchSize: 32, maxPatches: 1536) {
                    let functionReturn = OpenAIAPIRequest(
                        input: OpenAIFunctionInput(callId: f.callId, output: "Screenshot successful, sending output. Will be handled by another call."),
                        previousResponseId: prev.id, tools: [], toolChoice: "none")
                    prev = try await Self.sendOpenAIAPIRequest(functionReturn)
                    req = OpenAIAPIRequest(
                        input: OpenAIImageContentInput(base64Img: img, message: message),
                        previousResponseId: prev.id
                    )
                } else {
                    // send a normal response saying failed
                    req = OpenAIAPIRequest(
                        input: OpenAIFunctionInput(callId: f.callId, output: "Failed to capture image"),
                        previousResponseId: prev.id)
                }
                
            } else {
                let out = await matchedFunc?.executorFunction?(f.arguments) ?? "function call failed"
                req = OpenAIAPIRequest(
                    input: OpenAIFunctionInput(callId: f.callId, output: out),
                    previousResponseId: prev.id)
            }
            
            prev = try await Self.sendOpenAIAPIRequest(req)
            fCalls.append(contentsOf: prev.output?.filter({ $0.type == "function_call" && $0.body != nil }).compactMap {($0.body! as! OpenAIFunctionCallRequest)} ?? [])
        }
        
        
        let msgBody = prev.output?.first(where: {
            $0.body is OpenAIMessageResponse
        })
        
        guard let body = msgBody?.body,
              let msg = body as? OpenAIMessageResponse,
              let first = msg.content.first else {
            throw OpenAINetworkError.noMessageReturned }
        
        return DynamAIcResponse(message: first.text)
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
}



enum OpenAINetworkError: Error {
    case noMessageReturned
}

// MARK: Context and Instructions
extension OpenAINetworkManager {
    static var markdownInstructionContents: String {
        guard let file = Bundle.main.path(forResource: "Instructions", ofType: "md"),
              let contents = try? String(contentsOfFile: file, encoding: .utf8) else { return "" }
        return contents
    }
    
    static var defaultTools: [OpenAIGenericTool] {
        return Self.defaultFunctions.map({ return OpenAIGenericTool($0) })
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
              executorFunction: nil)
    ]
    
    
    private static let developerMessage: OpenAIMessage = .init(
        role: "developer",
        content: OpenAINetworkManager.markdownInstructionContents)
    
    
    
}



// MARK: Models
struct OpenAIAPIRequest: Encodable {
    var model: String
    let input: [any OpenAIInput]
    let instructions: String
    let tools: [OpenAIGenericTool]
    let previousResponseId: String?
    let toolChoice: String
    let parallelToolCalls: Bool
    
    init(model: String = "gpt-4.1-mini", input: any OpenAIInput, instructions: String = OpenAINetworkManager.markdownInstructionContents, previousResponseId: String? = nil, tools: [OpenAIGenericTool] = OpenAINetworkManager.defaultTools, toolChoice: String = "auto") {
        self.init(model: model, input: [input], instructions: instructions, previousResponseId: previousResponseId, tools: tools, toolChoice: toolChoice)
        
    }
    
    init(model: String = "gpt-4.1-mini", input: String, instructions: String = OpenAINetworkManager.markdownInstructionContents, previousResponseId: String? = nil, tools: [OpenAIGenericTool] = OpenAINetworkManager.defaultTools, toolChoice: String = "auto") {
        self.init(model: model, input: OpenAIContentInput(content: input), instructions: instructions, previousResponseId: previousResponseId, tools: tools, toolChoice: toolChoice)
    }
    
    private init(model: String = "gpt-4.1-mini", input: [any OpenAIInput], instructions: String = OpenAINetworkManager.markdownInstructionContents, previousResponseId: String? = nil, tools: [OpenAIGenericTool], toolChoice: String) {
        self.model = model
        self.input = input
        self.instructions = instructions
        self.previousResponseId = previousResponseId
        self.toolChoice = toolChoice
        self.tools = tools
        self.parallelToolCalls = false
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
        
        guard let first = input.first else { return }
        switch first {
        case let value as OpenAIContentInput:
            try container.encode([value], forKey: .input)
        case let value as OpenAIFunctionInput:
            try container.encode([value], forKey: .input)
        case let value as OpenAIImageContentInput:
            try container.encode([value], forKey: .input)
        default:
            throw EncodingError.invalidValue(first as Any, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
        }
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
    
    init(base64Img: String, message: String, role: String = "user") {
        self.content = OpenAIImageContent(
            text: OpenAIImageContentText(
                text: message,
                type: "input_text"),
            image: OpenAIImageContentImage(
                type: "input_image",
                imageUrl: "data:image/png;base64,\(base64Img)"))
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

