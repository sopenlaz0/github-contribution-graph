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
        .frame(width: popoverWidth)
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
            if let summary = appState.contributionSummary {
                summaryRow(summary)
            }
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                ContributionGraphView(calendar: calendar, todayId: appState.todayDateString)
                Spacer(minLength: 0)
            }
            footer
        }
        .padding(.horizontal, compactContentInset)
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

            rangePicker

            Button(action: { appState.refreshContributions() }) {
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
            .padding(.leading, 4)
            .keyboardShortcut("r", modifiers: .command)
            .help("Refresh")
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

    private func summaryRow(_ summary: ContributionSummary) -> some View {
        HStack(spacing: 6) {
            metricChip(title: "Streak", value: "\(summary.currentStreak)d")
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

    // MARK: - Time Range Picker

    private var rangePicker: some View {
        Picker("", selection: selectedRangeBinding) {
            Text("Last 12 months").tag(ContributionRange.last12Months)
            Text("This month").tag(ContributionRange.thisMonth)
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

            if let syncStatusLabel = appState.syncStatusLabel {
                Text(syncStatusLabel)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
            .keyboardShortcut(",", modifiers: .command)
            .help("Settings")

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Image(systemName: "power")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
            .keyboardShortcut("q", modifiers: .command)
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
        case .thisMonth:
            return "Loading this month..."
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

    private var popoverWidth: CGFloat {
        switch appState.selectedRange {
        case .thisMonth:
            return 430
        case .last12Months, .year:
            return 700
        }
    }

    private var compactContentInset: CGFloat {
        switch appState.selectedRange {
        case .thisMonth:
            return 12
        case .last12Months, .year:
            return 0
        }
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
