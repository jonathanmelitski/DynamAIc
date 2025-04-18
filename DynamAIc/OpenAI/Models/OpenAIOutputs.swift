//
//  OpenAIOutputs.swift
//  DynamAIc
//
//  Created by Jonathan Melitski on 4/18/25.
//

import Foundation

protocol OpenAIOutput: Codable, Identifiable {
    var id: String { get }
}

struct OpenAIGenericOutput: Codable {
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
