//
//  ContainersManager.swift
//  DynamAIc
//
//  Created by Jonathan Melitski on 4/21/25.
//

import Foundation
import SwiftData

struct ContainersManager {
    static func getContainerByKey(_ key: String, type: String) throws -> any DynamAIcContainer {
        let containers = try Self.getAllContainers()
        let filtered = containers.filter { $0.key == key }
        guard let first = filtered.first else { throw ContainersError.containerNotFound }
        guard filtered.count < 2 else { throw ContainersError.multipleKeys }
        return first
    }
    
    
    static func getAllContainers() throws -> [DynamAIcContainer] {
        let single = try Self.getSingleContainers()
        let multiple = try Self.getMultipleContainers()
        let containers: [DynamAIcContainer] = single + multiple
        return containers
    }
    
    private static func getSingleContainers() throws -> [DynamAIcSingleStorageContainer] {
        return try ApplicationViewModel.shared.context.fetch(DynamAIcSingleStorageContainer.fetchDescriptor)
    }
    
    private static func getMultipleContainers() throws -> [DynamAIcMultipleStorageContainer] {
        return try ApplicationViewModel.shared.context.fetch(DynamAIcMultipleStorageContainer.fetchDescriptor)
    }
}

enum ContainersError: String, LocalizedError {
    case multipleKeys = "There are multiple containers with this key, so this data cannot be fetched."
    case containerTypeMismatch = "A container was found, but its type (single/multiple) does not match that requested."
    case containerNotFound = "There is no container with this key."
    
    var errorDescription: String? {
        return self.rawValue
    }
}
