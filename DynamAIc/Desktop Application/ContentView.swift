//
//  ContentView.swift
//  DynamAIc
//
//  Created by Jonathan Melitski on 4/14/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Query var history: [DynamAIcResponse]
    @State var settings: Bool = false
    @Environment(\.modelContext) var context: ModelContext
    @Environment(\.openWindow) var openWindow
    
    var body: some View {
        TabView {
            ForEach(history) { res in
                Text(LocalizedStringKey(res.response.outputText ?? "No result returned"))
                    .textSelection(.enabled)
                    .tabItem {
                        Label(String(res.hashValue), systemImage: "book")
                    }
            }
            
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewSidebarBottomBar {
            Button {
                settings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.title2)
                    .padding(4)
            }
            .popover(isPresented: $settings) {
                SettingsView()
                    .padding()
            }
        }
        .onAppear() {
            print(context.container.configurations.first!.url)
        }
    }
}

#Preview {
    ContentView()
}
