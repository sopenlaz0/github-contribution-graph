// Sources/Views/SettingsView.swift
// Simple settings sheet showing account info and logout.
// Only accessible when logged in (via gear icon in the footer).
// RELEVANT FILES: Sources/State/AppState.swift, Sources/Views/MenuBarView.swift

import SwiftUI

// MARK: - Settings View

struct SettingsView: View {

    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            header
            accountCard
            actions
        }
        .padding(20)
        .frame(width: 320)
    }

    // MARK: - Header

    private var header: some View {
        Text("Settings")
            .font(.system(size: 15, weight: .semibold))
    }

    // MARK: - Account Card

    private var accountCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.green)

            Text("@\(appState.username)")
                .font(.system(size: 13, weight: .medium))

            Button("Logout") {
                appState.logout()
                dismiss()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.red)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.5)))
    }

    // MARK: - Actions

    private var actions: some View {
        HStack {
            Button("Quit App") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)

            Spacer()

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }
}
