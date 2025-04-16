//
//  DynamAIcResponse.swift
//  DynamAIc
//
//  Created by Jonathan Melitski on 4/14/25.
//
import SwiftData

@Model
class DynamAIcResponse {
    var message: String
    
    init(message: String) {
        self.message = message
    }
}
