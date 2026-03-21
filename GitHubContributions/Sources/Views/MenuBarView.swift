// Sources/Views/MenuBarView.swift
// Main popover view shown when clicking the menu bar icon.
// Displays the contribution graph, stats, and quick actions.
// RELEVANT FILES: Sources/Views/ContributionGraphView.swift, Sources/State/AppState.swift

import SwiftUI

// MARK: - Menu Bar View

struct MenuBarView: View {

    @ObservedObject var appState: AppState

    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            if !appState.isConfigured {
                onboardingView
            } else if let calendar = appState.calendar {
                contributionView(calendar)
            } else if appState.isLoading {
                loadingView
            } else if let error = appState.errorMessage {
                errorView(error)
            } else {
                loadingView
            }
        }
        .frame(width: 620)
        .padding(16)
        .onAppear {
            if appState.isConfigured && appState.calendar == nil {
                appState.fetchContributions()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(appState: appState)
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

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Image(systemName: "power")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
            .help("Quit GitHubContributions")
        }
    }

    // MARK: - Onboarding

    private var onboardingView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("Welcome to GitHub Contributions")
                .font(.system(size: 13, weight: .semibold))

            Text("Add your GitHub username and a Personal Access Token\nto see your contribution graph.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Open Settings") {
                showSettings = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
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
