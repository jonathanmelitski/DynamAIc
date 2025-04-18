//
//  UserEntryView.swift
//  DynamAIc
//
//  Created by Jonathan Melitski on 4/18/25.
//

import SwiftUI

struct UserEntryView: View {
    @EnvironmentObject var viewModel: WidgetViewModel
    @FocusState var isFocused
    
    var body: some View {
        TextField("Request", text: $viewModel.promptText, prompt: Text("How can I help?"), axis: .vertical)
            .lineLimit(3, reservesSpace: true)
            .fontDesign(.serif)
            .font(.title)
            .fontWeight(.medium)
            .textFieldStyle(.plain)
            .multilineTextAlignment(.leading)
            .focused($isFocused)
            .clipShape(.rect(cornerRadius: 6))
            .padding(8)
            .padding(.horizontal, 4)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .foregroundStyle(.ultraThickMaterial)
                    .shadow(radius: 4)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8).stroke(Color.white, lineWidth: 2)
            }
            .onSubmit {
                withAnimation {
                    viewModel.submit()
                }
            }
            .onAppear {
                isFocused = true
            }
            .transition(.blurReplace)
    }
}
