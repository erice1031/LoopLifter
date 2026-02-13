//
//  LoopLifterApp.swift
//  LoopLifter
//
//  AI-powered sample pack generator
//  Part of the "Lo" Suite
//

import SwiftUI

@main
struct LoopLifterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 700)

        Settings {
            SettingsView()
        }
    }
}
