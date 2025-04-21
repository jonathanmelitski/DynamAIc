//
//  VirtualMachineView.swift
//  DynamAIc
//
//  Created by Jonathan Melitski on 4/18/25.
//

import SwiftUI
import Virtualization

struct VirtualMachineView: View {
    let mgr = VirtualMachineManager()
    var view: VZVirtualMachineView
    
    init() {
        view = VZVirtualMachineView()
        view.virtualMachine = mgr.machine
    }
    
    
    var body: some View {
        if let machine = mgr.machine {
            VirtualMachineRepresentable(machine: machine)
                .onAppear {
                    Task {
                        try await mgr.installMachine()
                        try await mgr.startMachine()
                    }
                }
        }
    }
}

struct VirtualMachineRepresentable: NSViewRepresentable {
    func updateNSView(_ nsView: NSViewType, context: Context) {}
    
    let machine: VZVirtualMachine
    
    init(machine: VZVirtualMachine) {
        self.machine = machine
    }
    
    func makeNSView(context: Context) -> some NSView {
        let view = VZVirtualMachineView()
        view.virtualMachine = machine
        return view
    }
}
