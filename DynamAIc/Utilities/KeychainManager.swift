//
//  KeychainManager.swift
//  DynamAIc
//
//  Created by Jonathan Melitski on 4/21/25.
//

import Foundation

public final class KeychainManager {
    
    static let dynamAIcKey = "dynamAIc"
    
    static func save(_ data: Data, service: String) {
        #if targetEnvironment(simulator)
            return
        #else
        let query = [
            kSecValueData: data,
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: KeychainManager.dynamAIcKey
        ] as CFDictionary
        
        // Add data in query to keychain
        let status = SecItemAdd(query, nil)
        
        if status != errSecSuccess && status != errSecDuplicateItem {
            // Print out the error
            print("Error: \(status)")
        }
        
        if status == errSecDuplicateItem {
                // Item already exists, thus update it.
                let query = [
                    kSecAttrService: service,
                    kSecAttrAccount: dynamAIcKey,
                    kSecClass: kSecClassGenericPassword,
                ] as CFDictionary

                let attributesToUpdate = [kSecValueData: data] as CFDictionary

                SecItemUpdate(query, attributesToUpdate)
        }
        #endif
    }
    
    static func read(service: String) -> Data? {
        #if targetEnvironment(simulator)
            return nil
        #else
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: KeychainManager.dynamAIcKey,
            kSecClass: kSecClassGenericPassword,
            kSecReturnData: true
        ] as CFDictionary
        
        var result: AnyObject?
        SecItemCopyMatching(query, &result)
        
        return (result as? Data)
        #endif
    }
    
    static func delete(service: String) {
        #if targetEnvironment(simulator)
            return
        #else
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: KeychainManager.dynamAIcKey,
            kSecClass: kSecClassGenericPassword,
            ] as CFDictionary
        
        // Delete item from keychain
        SecItemDelete(query)
        #endif
    }
}

// MARK: AccessTokenStorage
extension KeychainManager {
    static func saveGoogleCredential(_ credential: GoogleAccessToken) {
        guard let data = try? JSONEncoder().encode(credential) else {
            return
        }
        
        Self.save(data, service: "auth-credentials-google")
    }
    
    static func loadGoogleCredential() -> GoogleAccessToken? {
        guard let data = Self.read(service: "auth-credentials-google") else {
            return nil
        }
        
        return try? JSONDecoder().decode(GoogleAccessToken.self, from: data)
    }
    
    static func clearGoogleCredential() {
        Self.delete(service: "auth-credentials-google")
    }
    
    static func hasGoogleCredential() -> Bool {
        return loadGoogleCredential() != nil
    }
}
