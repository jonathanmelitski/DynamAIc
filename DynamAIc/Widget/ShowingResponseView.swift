//
//  ShowingResponseView.swift
//  DynamAIc
//
//  Created by Jonathan Melitski on 4/18/25.
//

import SwiftUI

struct ShowingResponseView: View {
    @EnvironmentObject var vm: WidgetViewModel
    @FocusState var focused
    
    let req: String
    let res: DynamAIcResponse
    
    init(req: String, res: DynamAIcResponse) {
        self.req = req
        self.res = res
    }
    
    var body: some View {
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
                Text(LocalizedStringKey(res.response.outputText ?? "Maybe an error idk?"))
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
    }
}
