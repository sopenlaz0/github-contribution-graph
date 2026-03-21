// Sources/Views/MenuBarView.swift
// Main popover view shown when clicking the menu bar icon.
// Handles login flow and displays the contribution graph.
// RELEVANT FILES: Sources/Views/ContributionGraphView.swift, Sources/State/AppState.swift

import SwiftUI

// MARK: - Menu Bar View

struct MenuBarView: View {

    @ObservedObject var appState: AppState

    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            if appState.isAuthorizing {
                authorizingView
            } else if appState.isLoggedIn {
                loggedInContent
            } else {
                loginView
            }
        }
        .frame(width: 620)
        .padding(16)
        .onAppear {
            if appState.isLoggedIn && appState.calendar == nil {
                appState.fetchContributions()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(appState: appState)
        }
    }

    // MARK: - Login View

    @State private var clientIdInput: String = ""

    private var loginView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("GitHub Contributions")
                .font(.system(size: 14, weight: .semibold))

            Text("See your contribution graph at a glance.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            if let error = appState.errorMessage {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            // Only show Client ID field when not configured
            if appState.needsClientId {
                clientIdField
            }

            Button(action: {
                if appState.needsClientId {
                    appState.storedClientId = clientIdInput.trimmingCharacters(in: .whitespaces)
                }
                appState.login()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Login with GitHub")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(appState.needsClientId && clientIdInput.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.vertical, 12)
    }

    /// Small inline field for entering the OAuth Client ID (shown only once).
    private var clientIdField: some View {
        VStack(spacing: 6) {
            TextField("OAuth App Client ID", text: $clientIdInput)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .frame(width: 280)

            HStack(spacing: 4) {
                Text("Need one?")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)

                Button("Create a GitHub OAuth App") {
                    if let url = URL(string: "https://github.com/settings/developers") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 9))
                .foregroundStyle(.blue)
            }
        }
    }

    // MARK: - Authorizing View (Device Flow)

    private var authorizingView: some View {
        VStack(spacing: 14) {
            Text("First, copy your one-time code:")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            if let code = appState.deviceUserCode {
                Text(code)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .textSelection(.enabled)

                Button("Copy Code") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Text("Then enter it on the GitHub page that just opened.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.6)
                Text("Waiting for authorization...")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 4)

            Button("Cancel") {
                appState.cancelLogin()
            }
            .buttonStyle(.plain)
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Logged In Content

    @ViewBuilder
    private var loggedInContent: some View {
        if let calendar = appState.calendar {
            contributionView(calendar)
        } else if appState.isLoading {
            loadingView
        } else if let error = appState.errorMessage {
            errorView(error)
        } else {
            loadingView
        }
    }

    // MARK: - Contribution View

    private func contributionView(_ calendar: ContributionCalendar) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            header(totalContributions: calendar.totalContributions)
            ContributionGraphView(calendar: calendar)
            footer
        }
    }

    // MARK: - Header

    private func header(totalContributions: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("@\(appState.username)")
                    .font(.system(size: 13, weight: .semibold))

                Text("\(totalContributions) contributions in the last year")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: { appState.fetchContributions() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .disabled(appState.isLoading)
            .opacity(appState.isLoading ? 0.5 : 1)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            ContributionLegend()

            Spacer()

            if let lastUpdated = appState.lastUpdated {
                Text("Updated \(lastUpdated.formatted(.relative(presentation: .named)))")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Image(systemName: "power")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
            .help("Quit GitHubContributions")
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Fetching contributions...")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(height: 120)
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundStyle(.orange)

            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                appState.fetchContributions()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(height: 120)
    }
}
