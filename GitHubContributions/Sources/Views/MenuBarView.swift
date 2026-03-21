// Sources/Views/MenuBarView.swift
// Main popover view shown when clicking the menu bar icon.
// Handles the full flow: setup → login → contribution graph.
// RELEVANT FILES: Sources/Views/ContributionGraphView.swift, Sources/State/AppState.swift

import SwiftUI

// MARK: - Menu Bar View

struct MenuBarView: View {

    @ObservedObject var appState: AppState

    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            if !appState.hasClientId {
                setupView
            } else if appState.isAuthorizing {
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

    // MARK: - Setup View (First Time — No Client ID)

    private var setupView: some View {
        VStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            Text("One-Time Setup")
                .font(.system(size: 13, weight: .semibold))

            Text("Create a GitHub OAuth App to enable login.\nTakes about 30 seconds.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Setup") {
                showSettings = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Login View (Has Client ID, Not Logged In)

    private var loginView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            Text("GitHub Contributions")
                .font(.system(size: 13, weight: .semibold))

            if let error = appState.errorMessage {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button(action: { appState.login() }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Login with GitHub")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            HStack {
                Button(action: { showSettings = true }) {
                    Text("Settings")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Authorizing View (Device Flow In Progress)

    private var authorizingView: some View {
        VStack(spacing: 12) {
            Text("Enter this code on GitHub:")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            if let code = appState.deviceUserCode {
                Text(code)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .textSelection(.enabled)

                Button("Copy Code") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.6)
                Text("Waiting for authorization...")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Button("Cancel") {
                appState.cancelLogin()
            }
            .buttonStyle(.plain)
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
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
