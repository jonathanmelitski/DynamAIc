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
    let container = try! ModelContainer(for: DynamAIcResponse.self)
    let context: ModelContext
    
    @ObservedObject static var shared = ApplicationViewModel()
    
    @MainActor init() {
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
