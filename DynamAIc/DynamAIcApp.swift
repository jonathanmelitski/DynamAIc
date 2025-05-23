//
//  DynamAIcApp.swift
//  DynamAIc
//
//  Created by Jonathan Melitski on 4/14/25.
//

import SwiftUI

@main
struct DynamAIcApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContext(ApplicationViewModel.shared.context)
                .modelContainer(ApplicationViewModel.shared.container)
                .onAppear {
                    // Initialize preferences container
                    let _ = try! ContainersManager.getPreferences()
                }
        }
        
//        Window("DynamAIc Virtual Machine", id: "macos-vm") {
//            VirtualMachineView()
//        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popOver = NSPopover()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let menuView = MenuView()
        
        popOver.behavior = .transient
        popOver.animates = true
        popOver.contentViewController = NSViewController()
        popOver.contentViewController?.view = NSHostingView(rootView: menuView)
        popOver.contentViewController?.view.window?.makeKey()
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let MenuButton = statusItem?.button {
            MenuButton.image = NSImage(systemSymbolName: "brain", accessibilityDescription: nil)
            MenuButton.action = #selector(MenuButtonToggle)
        }
    }
    
    @objc func MenuButtonToggle() {
        if let menuButton = statusItem?.button {
            self.popOver.show(relativeTo: menuButton.bounds, of: menuButton, preferredEdge: NSRectEdge.minY)
        }
    }
}
