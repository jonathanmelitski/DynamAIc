//
//  MenuView.swift
//  DynamAIc
//
//  Created by Jonathan Melitski on 4/14/25.
//

import SwiftUI

struct MenuView: View {
    @StateObject var viewModel = WidgetViewModel()
    @FocusState var isFocused
    
    var body: some View {
        VStack(spacing: 12) {
            switch viewModel.state {
            case .userEntry:
                UserEntryView()
            case .waitingForResponse:
                WaitingForResponseView()
            case .response(let req, let res):
                ShowingResponseView(req: req, res: res)
            case .error(let error):
                ResponseErrorView(error: error)
            case .continuing(let previous):
                ShowingResponseView(req: previous.request, res: previous)
                UserEntryView()
            }
        }
        .padding()
        .frame(width: 400)
        .environmentObject(viewModel)
        .onSubmit {
            if case .response(_,_) = viewModel.state {
                withAnimation {
                    viewModel.reset()
                }
            }
        }
    }
}

#Preview {
    MenuView()
}
