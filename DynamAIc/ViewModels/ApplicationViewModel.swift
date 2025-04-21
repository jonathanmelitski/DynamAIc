//
//  ApplicationViewModel.swift
//  DynamAIc
//
//  Created by Jonathan Melitski on 4/14/25.
//

import Foundation
import SwiftData
import SwiftUI

class ApplicationViewModel: ObservableObject {
    let context: ModelContext
    let container: ModelContainer
    static let dataConfiguration = ModelConfiguration(url: URL.documentsDirectory.appending(path: "dynamaic.database.sqlite"))
    
    @ObservedObject static var shared = ApplicationViewModel()
    
    @Published var accessTokens: [any AccessToken] = []
    
    @MainActor init() {
        self.container = try! ModelContainer(for: DynamAIcResponse.self, DynamAIcSingleStorageContainer.self, DynamAIcMultipleStorageContainer.self, configurations: Self.dataConfiguration)
        context = container.mainContext
        // TODO: Get AccessTokens
    }
    
    func addToHistory(_ response: DynamAIcResponse) {
        context.insert(response)
        do {
            try context.save()
        } catch {
            print("Unable to save recent history")
        }
    }
}
