//
//  WiFiPriorityApp.swift
//  WiFiPrioritySwiftUI
//
//  Created with Claude Code
//

import SwiftUI

@main
struct WiFiPriorityApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 500, minHeight: 400)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
