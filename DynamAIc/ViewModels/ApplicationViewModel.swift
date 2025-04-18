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
    
    @ObservedObject static var shared = ApplicationViewModel()
    
    @MainActor init() {
        let storeURL = URL.documentsDirectory.appending(path: "dynamaic.database.sqlite")
        let config = ModelConfiguration(url: storeURL)
        self.container = try! ModelContainer(for: DynamAIcResponse.self, configurations: config)
        context = container.mainContext
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
