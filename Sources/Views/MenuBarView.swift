// Sources/Views/MenuBarView.swift
// Main popover view shown when clicking the menu bar icon.
// Shows contribution graph with year dropdown, or setup instructions.
// RELEVANT FILES: Sources/Views/ContributionGraphView.swift, Sources/State/AppState.swift

import SwiftUI

// MARK: - Menu Bar View

struct MenuBarView: View {
    private enum ContentPanel: String, CaseIterable {
        case graph
        case country

        var title: String {
            switch self {
            case .graph:
                return "Graph"
            case .country:
                return "Country"
            }
        }
    }

    private let contentVerticalInset: CGFloat = 8
    private let contentTrailingInset: CGFloat = 8
    private let contentLeadingInset: CGFloat = 32
    private let graphLeadingCompensation: CGFloat = 0
    private let trailingControlSpacing: CGFloat = 10

    @ObservedObject var appState: AppState

    @State private var showSettings = false
    @State private var selectedPanel: ContentPanel = .graph

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
            } else {
                appState.refreshContributionsIfNeeded()
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
            icon: "terminal",
            title: "Set up GitHub CLI",
            subtitle: "This app uses your existing gh login. Install it once, then sign in.",
            steps: [
                SetupStep(title: "Install GitHub CLI", detail: "Run this once in Terminal.", command: "brew install gh"),
                SetupStep(title: "Sign in to GitHub", detail: "Authorize gh with your GitHub account.", command: "gh auth login")
            ],
            primaryActionTitle: "Copy install command",
            primaryCommand: "brew install gh",
            secondaryActionTitle: "GitHub CLI site",
            secondaryAction: openGitHubCLISite
        )
    }

    private var needsLoginView: some View {
        setupPrompt(
            icon: "person.crop.circle.badge.xmark",
            title: "Finish GitHub sign-in",
            subtitle: "GitHub CLI is installed, but this Mac is not authenticated yet.",
            steps: [
                SetupStep(title: "Authenticate with GitHub", detail: "Run this in Terminal and complete the browser flow.", command: "gh auth login")
            ],
            primaryActionTitle: "Copy login command",
            primaryCommand: "gh auth login",
            secondaryActionTitle: "Open Terminal",
            secondaryAction: openTerminal
        )
    }

    private func setupPrompt(
        icon: String,
        title: String,
        subtitle: String,
        steps: [SetupStep],
        primaryActionTitle: String,
        primaryCommand: String,
        secondaryActionTitle: String,
        secondaryAction: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.system(size: 14, weight: .semibold))

            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    setupStepRow(number: index + 1, step: step)
                }
            }
            .padding(.vertical, 4)

            HStack(spacing: 8) {
                Button(primaryActionTitle) {
                    copyToPasteboard(primaryCommand)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(secondaryActionTitle, action: secondaryAction)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

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

            switch selectedPanel {
            case .graph:
                graphPanel(calendar)
            case .country:
                CountryLeaderboardView(appState: appState)
                    .frame(minHeight: 150)
            }

            footer
        }
        .padding(.top, contentVerticalInset)
        .padding(.bottom, contentVerticalInset)
        .padding(.trailing, contentTrailingInset)
        .padding(.leading, contentLeadingInset)
    }

    private func graphPanel(_ calendar: ContributionCalendar) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let summary = appState.contributionSummary {
                summaryRow(summary)
            }
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                ContributionGraphView(
                    calendar: calendar,
                    todayId: appState.todayDateString,
                    onOpenDay: openGitHubDay
                )
                .padding(.leading, graphLeadingCompensation)
                Spacer(minLength: 0)
            }
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

            Spacer(minLength: 12)

            headerTrailingControls
        }
        .frame(maxWidth: .infinity)
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

    private func summaryRow(_ summary: ContributionSummary) -> some View {
        HStack(spacing: 6) {
            metricChip(title: "Streak", value: "\(summary.currentStreak)d")
            metricChip(title: "7d total", value: "\(summary.trailingWeekTotal)")
            metricChip(title: "Vs prev", value: weeklyTrendLabel(summary))
            metricChip(title: "Best", value: bestDayLabel(summary.bestDay))
            metricChip(title: "Avg/day", value: summary.averagePerDay.formatted(.number.precision(.fractionLength(1))))

            if summary.longestStreak > summary.currentStreak {
                metricChip(title: "Longest", value: "\(summary.longestStreak)d")
            }

            Spacer(minLength: 0)
        }
    }

    private func metricChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.45)))
    }

    private func bestDayLabel(_ day: ContributionDay?) -> String {
        guard let day else { return "None" }

        let date = day.parsedDate ?? Date()
        let formatter = Date.FormatStyle().month(.abbreviated).day()
        return "\(day.contributionCount) on \(date.formatted(formatter))"
    }

    private func weeklyTrendLabel(_ summary: ContributionSummary) -> String {
        let delta = summary.trailingWeekDelta
        if delta == 0 {
            return "Flat"
        }

        let prefix = delta > 0 ? "+" : ""
        return "\(prefix)\(delta)"
    }

    // MARK: - Header Controls

    private var panelPicker: some View {
        Picker("", selection: $selectedPanel) {
            ForEach(ContentPanel.allCases, id: \.self) { panel in
                Text(panel.title).tag(panel)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .controlSize(.small)
        .frame(width: 150)
    }

    private var rangePicker: some View {
        Picker("", selection: selectedRangeBinding) {
            Text("Last 12 months").tag(ContributionRange.last12Months)
            ForEach(appState.availableYears, id: \.self) { year in
                Text(String(year)).tag(ContributionRange.year(year))
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .controlSize(.small)
        .fixedSize()
        .disabled(appState.isLoading)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            ContributionLegend()

            Spacer()

            footerTrailingControls
        }
        .frame(maxWidth: .infinity)
    }

    private var headerTrailingControls: some View {
        HStack(spacing: trailingControlSpacing) {
            panelPicker
            rangePicker

            Button(action: refreshSelectedPanel) {
                Group {
                    if appState.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(appState.isLoading)
            .opacity(appState.isLoading ? 0.5 : 1)
            .keyboardShortcut("r", modifiers: .command)
            .help(selectedPanel == .graph ? "Refresh graph" : "Refresh country preview")
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func refreshSelectedPanel() {
        switch selectedPanel {
        case .graph:
            appState.refreshContributions()
        case .country:
            appState.refreshCountryLeaderboard()
        }
    }

    private var footerTrailingControls: some View {
        HStack(spacing: trailingControlSpacing) {
            if let syncStatusLabel = appState.syncStatusLabel {
                Text(syncStatusLabel)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            Button(action: openGitHubProfile) {
                Image(systemName: "globe")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("Open GitHub profile")

            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)
            .help("Settings")

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Image(systemName: "power")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q", modifiers: .command)
            .help("Quit")
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
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
                copyToPasteboard(command)
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

    private func setupStepRow(number: Int, step: SetupStep) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .frame(width: 18, height: 18)
                .background(Circle().fill(.quaternary))

            VStack(alignment: .leading, spacing: 5) {
                Text(step.title)
                    .font(.system(size: 11, weight: .semibold))
                Text(step.detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                commandRow(step.command)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.3)))
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
        .keyboardShortcut("r", modifiers: .command)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text(loadingMessage)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(height: 120)
    }

    private var loadingMessage: String {
        switch appState.selectedRange {
        case .last12Months:
            return "Fetching contributions..."
        case .year(let year):
            return "Loading \(year) contributions..."
        }
    }

    private var selectedRangeBinding: Binding<ContributionRange> {
        Binding(
            get: { appState.selectedRange },
            set: { appState.selectRange($0) }
        )
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

    private func openGitHubProfile() {
        guard let url = URL(string: "https://github.com/\(appState.username)") else { return }
        NSWorkspace.shared.open(url)
    }

    private func openGitHubCLISite() {
        guard let url = URL(string: "https://cli.github.com/") else { return }
        NSWorkspace.shared.open(url)
    }

    private func openGitHubDay(_ day: ContributionDay) {
        guard
            day.isVisible,
            let encodedUsername = appState.username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let url = URL(string: "https://github.com/\(encodedUsername)?tab=overview&from=\(day.date)&to=\(day.date)")
        else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private func openTerminal() {
        let terminalURL = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        NSWorkspace.shared.openApplication(at: terminalURL, configuration: .init())
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

private struct SetupStep {
    let title: String
    let detail: String
    let command: String
}
