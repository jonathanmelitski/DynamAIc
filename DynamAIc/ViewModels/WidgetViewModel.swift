//
//  DynamAIcViewModel.swift
//  DynamAIc
//
//  Created by Jonathan Melitski on 4/14/25.
//

import Foundation
import SwiftUI

class WidgetViewModel: ObservableObject {
    @Published var promptText: String = ""
    @Published var state: WidgetState = .userEntry
    
    func submit() {
        guard !promptText.isEmpty else { return }
        let input = promptText
        promptText = ""
        state = .waitingForResponse
        Task { @MainActor in
            do {
                let res = try await OpenAINetworkManager.getAssistantResponse(input)
                self.state = .response(request: input, response: res)
                ApplicationViewModel.shared.addToHistory(res)
                DispatchQueue.main.asyncAfter(deadline: .now().advanced(by: .seconds(8))) {
                    withAnimation {
                        self.state = .userEntry
                    }
                }
            } catch {
                self.state = .error
                DispatchQueue.main.asyncAfter(deadline: .now().advanced(by: .seconds(8))) {
                    withAnimation {
                        self.state = .userEntry
                    }
                }
            }
        }
    }
    
    func reset() {
        promptText = ""
        state = .userEntry
    }
}


enum WidgetState {
    case userEntry, waitingForResponse, response(request: String, response: DynamAIcResponse), error
}
