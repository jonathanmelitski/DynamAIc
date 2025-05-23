//
//  ContainerModels.swift
//  DynamAIc
//
//  Created by Jonathan Melitski on 4/21/25.
//

import SwiftData
import Foundation

extension Array where Element == DynamAIcContainer {
    var keysAndContainers: [OpenAIContainerDetails] {
        return self.compactMap {
            let typeStr: String
            switch $0 {
            case _ as DynamAIcSingleStorageContainer:
                typeStr = "single"
            case _ as DynamAIcMultipleStorageContainer:
                typeStr = "multiple/array"
            default:
                typeStr = ""
            }
            return OpenAIContainerDetails(
                key: $0.key,
                containerDescription: $0.containerDescription,
                type: typeStr) }
    }
}

struct OpenAIContainerDetails: Codable {
    var key: String
    var containerDescription: String
    var type: String
    
    enum CodingKeys: String, CodingKey {
        case key
        case type
        case containerDescription = "container_description"
    }
}

protocol DynamAIcContainer: Encodable {
    var key: String { get set }
    var containerDescription: String { get set }
}

@Model
class DynamAIcSingleStorageContainer: DynamAIcContainer {
    var key: String
    var containerDescription: String
    var data: Data
    
    init(key: String, containerDescription: String, data: Data) {
        self.key = key
        self.containerDescription = containerDescription
        self.data = data
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(key, forKey: .key)
        try container.encode(containerDescription, forKey: .containerDescription)
        try container.encode(data, forKey: .data)
    }
    
    enum CodingKeys: String, CodingKey {
        case key
        case containerDescription = "container_description"
        case data
    }
    
    static let fetchDescriptor: FetchDescriptor = FetchDescriptor(
        predicate: #Predicate<DynamAIcSingleStorageContainer> { _ in true },
        sortBy: [.init(\.key)])
}

@Model
class DynamAIcMultipleStorageContainer: DynamAIcContainer {
    var key: String
    var containerDescription: String
    var dataArray: [DynamAIcData]
    
    init(key: String, containerDescription: String, dataArray: [DynamAIcData]) {
        self.key = key
        self.containerDescription = containerDescription
        self.dataArray = dataArray
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(key, forKey: .key)
        try container.encode(containerDescription, forKey: .containerDescription)
        try container.encode(dataArray, forKey: .dataArray)
    }
    
    enum CodingKeys: String, CodingKey {
        case key
        case containerDescription = "container_description"
        case dataArray = "data_array"
    }
    
    var maxDataKey: Int {
        dataArray.reduce(-1) { result, el in
            return max(result, el.id)
        }
    }
    
    var dataKeysAndIds: [String: Int] {
        var res: [String: Int] = [:]
        dataArray.forEach {
            res.updateValue($0.id, forKey: $0.key)
        }
        return res
    }
    
    static let fetchDescriptor: FetchDescriptor = FetchDescriptor(
        predicate: #Predicate<DynamAIcMultipleStorageContainer> { _ in true },
        sortBy: [.init(\.key)])
}

@Model
class DynamAIcData: Encodable {
    var id: Int
    var key: String
    var data: Data
    
    init(id: Int, key: String, data: Data) {
        self.id = id
        self.key = key
        self.data = data
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(key, forKey: .key)
        try container.encode(data, forKey: .data)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, key, data
    }
}
