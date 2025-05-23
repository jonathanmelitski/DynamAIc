//
//  OpenAITools.swift
//  DynamAIc
//
//  Created by Jonathan Melitski on 4/18/25.
//

// Note: Adding a new tool requires modifying the behavior of the Generic's encode/decode.
protocol OpenAIToolType: Codable {
    var type: String { get }
}

struct OpenAITool: OpenAIToolType {
    let type: String
    let body: (any OpenAIToolType)?
    
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

struct OpenAIWebSearch: OpenAIToolType {
    var type: String = "web_search_preview"
}

struct OpenAIFunction: OpenAIToolType {
    let type: String
    let name: String
    let description: String
    let parameters: OpenAIFunctionParameter
    let strict: Bool
    let executorFunction: (([String: String]) async -> String)?
    let callbackInput: ((OpenAIFunctionCallRequest) async -> any OpenAIInput)?
    
    init(name: String, description: String, parameters: OpenAIFunctionParameter, strict: Bool, executorFunction: @escaping (([String:String]) async -> String), callbackInput: ((OpenAIFunctionCallRequest) async -> any OpenAIInput)? = nil) {
        self.type = "function"
        self.name = name
        self.description = description
        self.parameters = parameters
        self.strict = strict
        self.executorFunction = executorFunction
        self.callbackInput = callbackInput
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decode(String.self, forKey: .description)
        self.parameters = try container.decode(OpenAIFunctionParameter.self, forKey: .parameters)
        self.strict = try container.decode(Bool.self, forKey: .name)
        self.executorFunction = nil
        self.callbackInput = nil
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
        
        // They really should fix this, this should be snake-cased lol
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

struct OpenAIToolChoice: Encodable {
    let type: String?
    let name: String?
    let value: String?
    
    init(value: String) {
        self.value = value
        self.type = nil
        self.name = nil
    }
    
    init (function: String) {
        self.type = "function"
        self.name = function
        self.value = nil
    }
    
    func encode(to encoder: any Encoder) throws {
        if value != nil {
            try value!.encode(to: encoder)
        } else {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            try container.encode(name, forKey: .name)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case type, name, value
    }
}
