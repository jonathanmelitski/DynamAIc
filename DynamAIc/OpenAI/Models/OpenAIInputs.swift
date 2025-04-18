//
//  OpenAIInputs.swift
//  DynamAIc
//
//  Created by Jonathan Melitski on 4/18/25.
//

import Foundation
import AppKit

protocol OpenAIInput: Encodable {}

struct OpenAIContentInput: OpenAIInput {
    let content: String
    let role: String
    
    init(content: String, role: String = "user") {
        self.content = content
        self.role = role
    }
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
