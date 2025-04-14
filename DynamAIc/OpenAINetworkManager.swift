//
//  OpenAINetworkManager.swift
//  DynamAIc
//
//  Created by Jonathan Melitski on 4/14/25.
//
import Foundation

class OpenAINetworkManager {
    static func getAssistantResponse(_ message: String) async throws {
        let url = URL(string: "https://api.openai.com/v1/responses")
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        request.addValue("Bearer \()", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONEncoder().encode(OpenAIAPIRequest(input: message, instructions: Self.markdownInstructionContents))
    }
}

// MARK: Context and Instructions
extension OpenAINetworkManager {
    static var markdownInstructionContents: String {
        guard let file = Bundle.main.path(forResource: "Instructions", ofType: "md"),
              let contents = try? String(contentsOfFile: file, encoding: .utf8) else { return "" }
        return contents
    }
    
    
    static let developerMessage: OpenAIMessage = .init(
        role: "developer",
        content: OpenAINetworkManager.markdownInstructionContents)
}

struct OpenAIAPIRequest: Codable {
    var model: String = "gpt-4.1-mini"
    let input: String
    let instructions: String
}

struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIFunction: Codable {
    let name: String
    let description: String
    let parameters: OpenAIFunctionParameter
    let strict: Bool
}

struct OpenAIFunctionParameter: Codable {
    let type: String
    let properties: [String: OpenAIParameterProperty]
    let required: [String]
    let additionalProperties: Bool
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

struct OpenAIToolCallRequest: Codable {
    let id: String
    let type: String
    let function: OpenAIFunctionCallRequest?
}

struct OpenAIFunctionCallRequest: Codable {
    let name: String
    let arguments: String
}
