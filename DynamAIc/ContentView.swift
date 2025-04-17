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
    
    var body: some View {
        TabView {
            ForEach(history, id: \.self) { res in
                Text(LocalizedStringKey(res.message))
                    .textSelection(.enabled)
                    .tabItem {
                        Label(String(res.hashValue), systemImage: "book")
                    }
            }
            
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

#Preview {
    ContentView()
}
