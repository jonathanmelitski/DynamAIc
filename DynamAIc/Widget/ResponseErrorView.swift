//
//  ResponseErrorView.swift
//  DynamAIc
//
//  Created by Jonathan Melitski on 4/18/25.
//

import SwiftUI

struct ResponseErrorView: View {
    @EnvironmentObject var vm: WidgetViewModel
    @FocusState var focused
    
    let error: any Error
    
    var body: some View {
        Text("Error on request.")
            .onAppear {
                print(error.localizedDescription)
            }
    }
}
