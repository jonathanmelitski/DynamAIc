//
//  MenuViewButtonRow.swift
//  DynamAIc
//
//  Created by Jonathan Melitski on 4/14/25.
//

import SwiftUI

struct MenuViewButtonRow: View {
    @EnvironmentObject var vm: WidgetViewModel
    var body: some View {
        HStack(spacing: 8) {
            
            Button {
                // submit
                withAnimation {
                    vm.submit()
                }
            } label: {
                Image(systemName: "figure.roll.runningpace")
                    .font(.title2)
                    .padding()
                    .shadow(radius: 4)
                    .bold()
                    
            }
            .buttonStyle(.borderedProminent)
            .clipShape(.circle)
            .overlay {
                Circle().stroke(.white, lineWidth: 1)
            }  
        }
    }
}

#Preview {
    MenuViewButtonRow()
}
