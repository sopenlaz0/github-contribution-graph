// Sources/Views/MenuBarView.swift
// Main popover view shown when clicking the menu bar icon.
// Shows contribution graph with year dropdown, or setup instructions.
// RELEVANT FILES: Sources/Views/ContributionGraphView.swift, Sources/State/AppState.swift

import SwiftUI

// MARK: - Menu Bar View

struct MenuBarView: View {

    @ObservedObject var appState: AppState

    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            if showSettings && appState.isLoggedIn {
                SettingsView(appState: appState, onDismiss: { showSettings = false })
            } else {
                mainContent
            }
        }
        .frame(width: 700)
        .padding(16)
        .onAppear {
            if !appState.isLoggedIn {
                appState.checkAuth()
            } else if appState.calendar == nil {
                appState.fetchContributions()
            }
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
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

    // MARK: - Needs GH / Login

    private var needsGHView: some View {
        setupPrompt(
            icon: "terminal", title: "GitHub CLI not found",
            subtitle: "Install it with Homebrew, then log in:",
            commands: ["brew install gh", "gh auth login"]
        )
    }

    private var needsLoginView: some View {
        setupPrompt(
            icon: "person.crop.circle.badge.xmark", title: "Not logged in to GitHub CLI",
            subtitle: "Run this in your terminal:",
            commands: ["gh auth login"]
        )
    }

    private func setupPrompt(icon: String, title: String, subtitle: String, commands: [String]) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 28)).foregroundStyle(.secondary)
            Text(title).font(.system(size: 14, weight: .semibold))
            Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(commands, id: \.self) { commandRow($0) }
            }
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
        VStack(alignment: .leading, spacing: 10) {
            header(totalContributions: calendar.totalContributions)
            ContributionGraphView(calendar: calendar, todayId: appState.todayDateString)
            footer
        }
    }

    // MARK: - Header

    private func header(totalContributions: Int) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text("\(totalContributions.formatted()) contributions \(appState.contributionPeriodLabel)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            if let today = appState.todayContributions {
                todayBadge(count: today)
            }

            Spacer()

            yearDropdown

            Button(action: { appState.fetchContributions() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .disabled(appState.isLoading)
            .opacity(appState.isLoading ? 0.5 : 1)
            .padding(.leading, 4)
        }
    }

    private func todayBadge(count: Int) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(.green)
                .frame(width: 6, height: 6)
            Text("\(count) today")
                .font(.system(size: 10, weight: .semibold))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(Capsule().fill(.green.opacity(0.12)))
    }

    // MARK: - Year Dropdown

    private var yearDropdown: some View {
        Menu {
            Button("Last 12 months") { appState.selectYear(nil) }
            Divider()
            ForEach(appState.availableYears, id: \.self) { year in
                Button(String(year)) { appState.selectYear(year) }
            }
        } label: {
            HStack(spacing: 3) {
                Text(appState.selectedYear.map(String.init) ?? "Last 12 months")
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 7))
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 5).fill(.quaternary.opacity(0.5)))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
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
            .help("Quit")
        }
    }

    // MARK: - Shared Components

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
            Image(systemName: "exclamationmark.triangle").font(.system(size: 24)).foregroundStyle(.orange)
            Text(message).font(.system(size: 11)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Retry") { appState.fetchContributions() }.buttonStyle(.borderedProminent).controlSize(.small)
        }.frame(height: 120)
    }
}
