// Sources/Views/SettingsView.swift
// Settings sheet for configuring GitHub username and Personal Access Token.
// Presented as a modal sheet from the menu bar popover.
// RELEVANT FILES: Sources/State/AppState.swift, Sources/Views/MenuBarView.swift

import SwiftUI

// MARK: - Settings View

struct SettingsView: View {

    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var username: String = ""
    @State private var token: String = ""

    var body: some View {
        VStack(spacing: 16) {
            header
            form
            helpText
            actions
        }
        .padding(20)
        .frame(width: 400)
        .onAppear {
            username = appState.username
            token = appState.token
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

    // MARK: - Form

    private var form: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("GitHub Username")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("octocat", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Personal Access Token")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                SecureField("ghp_xxxxxxxxxxxx", text: $token)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
            }
        }
    }

    // MARK: - Help

    private var helpText: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("How to create a token:")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

            Text("GitHub → Settings → Developer Settings → Personal Access Tokens → Fine-grained tokens → Generate new token → enable read-only access to your profile.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                appState.username = username.trimmingCharacters(in: .whitespaces)
                appState.token = token.trimmingCharacters(in: .whitespaces)
                appState.fetchContributions()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(username.trimmingCharacters(in: .whitespaces).isEmpty ||
                      token.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}
