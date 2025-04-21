//
//  ContainersManager.swift
//  DynamAIc
//
//  Created by Jonathan Melitski on 4/21/25.
//

import Foundation
import SwiftData

// Note, this places all DB operations on main thread, which could reduce performance given a lot of data/expensive fetch operations.
@MainActor struct ContainersManager {
    
    static var containerContext: ModelContext {
        ApplicationViewModel.shared.context
    }
    
    static func getContainerByKey(_ key: String, type: String) throws -> any DynamAIcContainer {
        let containers = try Self.getAllContainers()
        let filtered = containers.filter { $0.key == key }
        guard let first = filtered.first else { throw ContainersError.containerNotFound }
        guard filtered.count < 2 else { throw ContainersError.multipleKeys }
        
        return first
    }
    
    static func createNewContainer(type: String, key: String, description: String) throws {
        guard !(try Self.getAllContainers().contains(where: { $0.key == key })) else {
            throw ContainersError.containerAlreadyExists
        }
        
        switch type {
        case "single":
            Self.createSingleContainer(key: key, description: description)
        case "multiple/array":
            Self.createMultipleContainer(key: key, description: description)
        default:
            throw ContainersError.invalidContainerType
        }
    }
    
    
    static func getAllContainers() throws -> [DynamAIcContainer] {
        let single = try Self.getSingleContainers()
        let multiple = try Self.getMultipleContainers()
        let containers: [DynamAIcContainer] = single + multiple
        return containers
    }
    
    static func getPreferences() throws -> DynamAIcMultipleStorageContainer {
        let prefsContainer: DynamAIcMultipleStorageContainer
        do {
            prefsContainer = try Self.getContainerByKey("user-preferences", type: "multiple/array") as! DynamAIcMultipleStorageContainer
        } catch {
            Self.createMultipleContainer(key: "user-preferences", description: "A system-created container that contains user preferences. This includes which endpoints can be authenticated, and other settings to which the user has direct control.")
            guard let newPrefs = try? Self.getContainerByKey("user-preferences", type: "multiple/array") else {
                throw ContainersError.containerNotFound
            }
            prefsContainer = newPrefs as! DynamAIcMultipleStorageContainer
        }
        return prefsContainer
    }
    
    private static func getSingleContainers() throws -> [DynamAIcSingleStorageContainer] {
        return try Self.containerContext.fetch(DynamAIcSingleStorageContainer.fetchDescriptor)
    }
    
    private static func createSingleContainer(key: String, description: String) {
        Self.containerContext.insert(DynamAIcSingleStorageContainer(key: key, containerDescription: description, data: Data()))
        
        do {
            try Self.containerContext.save()
        } catch {
            print("Failed to save context after container creation operation.")
        }
    }
    
    private static func createMultipleContainer(key: String, description: String) {
        Self.containerContext.insert(DynamAIcMultipleStorageContainer(key: key, containerDescription: description, dataArray: []))
        
        do {
            try Self.containerContext.save()
        } catch {
            print("Failed to save context after container creation operation.")
        }
    }
    
    private static func getMultipleContainers() throws -> [DynamAIcMultipleStorageContainer] {
        return try Self.containerContext.fetch(DynamAIcMultipleStorageContainer.fetchDescriptor)
    }
}

enum ContainersError: String, LocalizedError {
    case multipleKeys = "There are multiple containers with this key, so this data cannot be fetched."
    case containerTypeMismatch = "A container was found, but its type (single/multiple) does not match that requested."
    case containerNotFound = "There is no container with this key."
    case containerAlreadyExists = "A container already exists with this key."
    case invalidContainerType = "Invalid container type (single vs. multiple/array) given."
    
    var errorDescription: String? {
        return self.rawValue
    }
}
