// Sources/App/GitHubContributionsApp.swift
// Entry point for the GitHub Contributions menu bar app.
// Uses MenuBarExtra to live in the macOS menu bar — no dock icon.
// RELEVANT FILES: Sources/Views/MenuBarView.swift, Sources/State/AppState.swift

import SwiftUI

// MARK: - App Entry Point

@main
struct GitHubContributionsApp: App {

    @StateObject private var appState = AppState()

    var body: some Scene {
        // Menu bar item — click to show the contribution graph popover.
        MenuBarExtra {
            MenuBarView(appState: appState)
        } label: {
            Label("GitHub Contributions", systemImage: "square.grid.3x3.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
