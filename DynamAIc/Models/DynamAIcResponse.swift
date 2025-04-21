//
//  DynamAIcResponse.swift
//  DynamAIc
//
//  Created by Jonathan Melitski on 4/14/25.
//
import SwiftData
import Foundation
import AppKit

@Model
class DynamAIcResponse {
    var request: String
    var response = DynamAIcResponseBody()
    var date: Date
    private(set) var functionsCalled: [DynamAIcFunctionCall]
    
    init(_ request: String) {
        self.request = request
        self.date = Date.now
        self.functionsCalled = []
    }
    
    func functionCalled(function: OpenAIFunctionCallRequest, result: OpenAIFunctionInput, sentCallback: (any OpenAIInput)? = nil) {
        self.functionsCalled.append(DynamAIcFunctionCall(date: Date.now, function: function, result: result, sentCallback: sentCallback))
    }
}

@Model
class DynamAIcResponseBody {
    var id: String?
    var error: String?
    var outputText: String?
    
    init(id: String? = nil, error: String? = nil, outputText: String? = nil) {
        self.id = id
        self.error = error
        self.outputText = outputText
    }
}

@Model
class DynamAIcFunctionCall {
    var date: Date
    var function: DynamAIcFunction
    var result: DynamAIcFunctionResult
    var sentCallback: DynamAIcFunctionCallbackData?
    
    init(date: Date, function: OpenAIFunctionCallRequest, result: OpenAIFunctionInput, sentCallback: (any OpenAIInput)? = nil) {
        self.date = date
        self.function = DynamAIcFunction(from: function)
        self.result = DynamAIcFunctionResult(from: result)
        if let sentCallback {
            self.sentCallback = DynamAIcFunctionCallbackData(from: sentCallback)
        }
    }
}

@Model
class DynamAIcFunction {
    var id: String
    var type: String
    var callId: String
    var name: String
    var arguments: [String: String]
    
    init(from request: OpenAIFunctionCallRequest) {
        self.id = request.id
        self.type = request.type
        self.callId = request.callId
        self.name = request.name
        self.arguments = request.arguments
    }
}

@Model
class DynamAIcFunctionResult {
    var callId: String
    var output: String
    var type: String
    
    init(from result: OpenAIFunctionInput) {
        self.callId = result.callId
        self.output = result.output
        self.type = result.type
    }
}

@Model
class DynamAIcFunctionCallbackData {
    var textContent: String?
    var functionCallback: DynamAIcFunctionResult?
    var sentImage: Data?
    
    init(from sentCallback: (any OpenAIInput)) {
        switch sentCallback {
        case let value as OpenAIContentInput:
            textContent = value.content
        case let value as OpenAIFunctionInput:
            functionCallback = DynamAIcFunctionResult(from: value)
        case let value as OpenAIImageContentInput:
            sentImage = value.content.image.originalImage
        default:
            break
        }
    }
}
