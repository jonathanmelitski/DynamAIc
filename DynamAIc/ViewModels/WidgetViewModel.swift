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
        var prev: DynamAIcResponse? = nil
        if case .continuing(let p) = self.state { prev = p }
        let input = promptText
        promptText = ""
        state = .waitingForResponse
        Task { @MainActor in
            do {
                let res = try await OpenAINetworkManager.getAssistantResponse(input, continuing: prev)
                self.state = .response(request: input, response: res)
                ApplicationViewModel.shared.addToHistory(res)
                DispatchQueue.main.asyncAfter(deadline: .now().advanced(by: .seconds(8))) {
                    guard case .response(_, _) = self.state else {
                        return
                    }
                    
                    withAnimation {
                        self.state = .userEntry
                    }
                }
            } catch {
                self.state = .error(error)
                let failedResponse: DynamAIcResponse?
                if let error = error as? OpenAIError {
                    switch error {
                    case .callToNonExistantFunction(_, let res):
                        failedResponse = res
                    case .openAIReportedError(let err, let res):
                        failedResponse = res
                    case .noMessageReturned(let res):
                        failedResponse = res
                    case .noStrategy(let res):
                        failedResponse = res
                    }
                } else { failedResponse = nil }
                
                if let failedResponse {
                    ApplicationViewModel.shared.addToHistory(failedResponse)
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now().advanced(by: .seconds(8))) {
                    withAnimation {
                        self.state = .userEntry
                    }
                }
            }
        }
    }
    
    func continueResponse(_ res: DynamAIcResponse) {
        self.state = .continuing(previous: res)
    }
    
    func reset() {
        promptText = ""
        state = .userEntry
    }
}


enum WidgetState {
    case userEntry, waitingForResponse, response(request: String, response: DynamAIcResponse), error(_ error: any Error), continuing(previous: DynamAIcResponse)
}
