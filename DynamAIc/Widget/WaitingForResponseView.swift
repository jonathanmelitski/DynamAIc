//
//  WaitingForResponseView.swift
//  DynamAIc
//
//  Created by Jonathan Melitski on 4/18/25.
//

import SwiftUI

struct WaitingForResponseView: View {
    @EnvironmentObject var vm: WidgetViewModel
    @FocusState var focused
    
    var body: some View {
        ProgressView()
    }
}
