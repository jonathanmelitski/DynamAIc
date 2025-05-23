//
//  ConfigurationManager.swift
//  DynamAIc
//
//  Created by Jonathan Melitski on 4/14/25.
//

import Foundation

struct Configuration {
    enum Error: Swift.Error {
        case missingKey, invalidValue
    }

    static func value<T>(for key: String) throws -> T where T: LosslessStringConvertible {
        guard let object = Bundle.main.object(forInfoDictionaryKey:key) else {
            throw Error.missingKey
        }

        switch object {
        case let value as T:
            return value
        case let string as String:
            guard let value = T(string) else { fallthrough }
            return value
        default:
            throw Error.invalidValue
        }
    }
}

enum ConfigurationKey: String {
    case openAIAPIKey = "OPENAI_CLIENT_ID"
    case googleAPIKey = "GOOGLE_CLIENT_ID"
    
    func getString() throws -> String {
        return try Configuration.value(for: self.rawValue)
    }
}

