// Sources/Views/SettingsView.swift
// Settings sheet for OAuth App setup and account management.
// Shows Client ID config when not set, and account info when logged in.
// RELEVANT FILES: Sources/State/AppState.swift, Sources/Views/MenuBarView.swift

import SwiftUI

// MARK: - Settings View

struct SettingsView: View {

    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var clientId: String = ""

    var body: some View {
        VStack(spacing: 16) {
            header

            if appState.isLoggedIn {
                accountSection
            }

            clientIdSection
            actions
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            clientId = appState.clientId
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)

            Text("Settings")
                .font(.system(size: 15, weight: .semibold))
        }
    }

    // MARK: - Account Section (Logged In)

    private var accountSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.green)

                Text("Logged in as @\(appState.username)")
                    .font(.system(size: 12, weight: .medium))

                Spacer()

                Button("Logout") {
                    appState.logout()
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.red)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(.green.opacity(0.08)))

            Divider()
        }
    }

    // MARK: - Client ID Section

    private var clientIdSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OAuth App Client ID")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Ov23li...", text: $clientId)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13, design: .monospaced))

            setupInstructions
        }
    }

    // MARK: - Setup Instructions

    private var setupInstructions: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("How to get a Client ID:")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                instructionRow("1", "Go to github.com/settings/developers")
                instructionRow("2", "Click \"New OAuth App\"")
                instructionRow("3", "Set any name and URL (e.g. http://localhost)")
                instructionRow("4", "Check \"Enable Device Flow\"")
                instructionRow("5", "Copy the Client ID and paste it above")
            }

            Button("Open GitHub Developer Settings") {
                if let url = URL(string: "https://github.com/settings/developers") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 10))
            .foregroundStyle(.blue)
        }
    }

    private func instructionRow(_ num: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text(num)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 12)

            Text(text)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Actions

    private var actions: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.plain)

            Spacer()

            Button("Save") {
                appState.clientId = clientId.trimmingCharacters(in: .whitespaces)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(clientId.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}
