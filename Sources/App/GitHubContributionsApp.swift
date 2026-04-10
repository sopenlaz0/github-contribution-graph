// Sources/App/GitHubContributionsApp.swift
// Entry point for the GitHub Contributions menu bar app.
// Uses MenuBarExtra to live in the macOS menu bar — no dock icon.
// RELEVANT FILES: Sources/Views/MenuBarView.swift, Sources/State/AppState.swift

import SwiftUI

// MARK: - App Entry Point

@main
struct GitHubContributionsApp: App {

    @StateObject private var appState = AppState()

    init() {
        // Keep the app menu-bar-only even if launch configuration or plist handling drifts.
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: appState)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "square.grid.3x3.fill")
                if let value = appState.menuBarValueText {
                    Text(value)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
