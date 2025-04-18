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
    
    var body: some View {
        TabView {
            ForEach(history, id: \.self) { res in
                Text(LocalizedStringKey(res.response?.textMessage ?? "No result returned"))
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
                Text("Settings View")
                    .padding()
            }
        }
    }
}

#Preview {
    ContentView()
}
