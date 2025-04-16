//
//  MenuView.swift
//  DynamAIc
//
//  Created by Jonathan Melitski on 4/14/25.
//

import SwiftUI

struct MenuView: View {
    @StateObject var viewModel = WidgetViewModel()
    
    var body: some View {
        VStack(spacing: 12) {
            switch viewModel.state {
            case .userEntry:
                TextField("Request", text: $viewModel.promptText, prompt: Text("How can I help?"), axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
                    .fontDesign(.serif)
                    .font(.title)
                    .fontWeight(.medium)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.leading)
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
                    .transition(.blurReplace)
            case .waitingForResponse:
                ProgressView()
            case .response(let req, let res):
                HStack {
                    Text(req)
                        .lineLimit(2)
                        .font(.title2)
                        .fontDesign(.serif)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.leading)
                        .clipShape(.rect(cornerRadius: 6))
                    Spacer()
                }
                .padding(4)
                .padding(.horizontal, 8)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .foregroundStyle(.ultraThickMaterial)
                        .shadow(radius: 4)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8).stroke(Color.white,lineWidth: 2)
                }
                .transition(.blurReplace)
                
                
                
                HStack {
                    ScrollView(.vertical) {
                        Text(LocalizedStringKey(res.message))
                            .font(.title2)
                            .fontDesign(.serif)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.leading)
                            .clipShape(.rect(cornerRadius: 6))
                    }
                    .frame(height: 200)
                    Spacer()
                }
                .padding(4)
                .padding(.horizontal, 8)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .foregroundStyle(.ultraThickMaterial)
                        .shadow(radius: 4)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor,lineWidth: 2)
                }
                .transition(.blurReplace)
            case .error:
                Text("Error on request.")
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
