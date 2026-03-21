// Sources/Views/MenuBarView.swift
// Main popover view shown when clicking the menu bar icon.
// Shows the contribution graph, or setup instructions if `gh` isn't ready.
// RELEVANT FILES: Sources/Views/ContributionGraphView.swift, Sources/State/AppState.swift

import SwiftUI

// MARK: - Menu Bar View

struct MenuBarView: View {

    @ObservedObject var appState: AppState

    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            switch appState.authStatus {
            case .checking:
                checkingView
            case .loggedIn:
                loggedInContent
            case .needsGH:
                needsGHView
            case .needsLogin:
                needsLoginView
            case .error(let message):
                errorView(message)
            }
        }
        .frame(width: 620)
        .padding(16)
        .onAppear {
            if !appState.isLoggedIn {
                appState.checkAuth()
            } else if appState.calendar == nil {
                appState.fetchContributions()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(appState: appState)
        }
    }

    // MARK: - Checking View

    private var checkingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Checking GitHub CLI...")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(height: 120)
    }

    // MARK: - Needs GH Installed

    private var needsGHView: some View {
        VStack(spacing: 12) {
            Image(systemName: "terminal")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            Text("GitHub CLI not found")
                .font(.system(size: 14, weight: .semibold))

            Text("Install it with Homebrew, then log in:")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                commandRow("brew install gh")
                commandRow("gh auth login")
            }
            .padding(.vertical, 4)

            retryButton
        }
        .padding(.vertical, 12)
    }

    // MARK: - Needs Login

    private var needsLoginView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.xmark")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            Text("Not logged in to GitHub CLI")
                .font(.system(size: 14, weight: .semibold))

            Text("Run this in your terminal:")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            commandRow("gh auth login")
                .padding(.vertical, 4)

            retryButton
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
            dataErrorView(error)
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

    // MARK: - Shared Components

    /// A copyable terminal command row.
    private func commandRow(_ command: String) -> some View {
        HStack(spacing: 8) {
            Text("$")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)

            Text(command)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .textSelection(.enabled)

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 9))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.5)))
    }

    private var retryButton: some View {
        Button(action: { appState.checkAuth() }) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.clockwise")
                Text("Retry")
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
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

    // MARK: - Error Views

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundStyle(.orange)

            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            retryButton
        }
        .padding(.vertical, 12)
    }

    private func dataErrorView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundStyle(.orange)

            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry") { appState.fetchContributions() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .frame(height: 120)
    }
}
