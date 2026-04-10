// Sources/Views/SettingsView.swift
// Inline settings panel showing account info, year selection, and logout.
// Rendered inside the menu bar popover (not as a sheet).
// RELEVANT FILES: Sources/State/AppState.swift, Sources/Views/MenuBarView.swift

import SwiftUI

// MARK: - Settings View

struct SettingsView: View {

    @ObservedObject var appState: AppState
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            header
            accountCard
            yearSection
            menuBarSection
            refreshSection
            reminderSection
            Divider()
            actions
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: onDismiss) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10))
                    Text("Back")
                        .font(.system(size: 11))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .keyboardShortcut(.escape, modifiers: [])

            Spacer()

            Text("Settings")
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            Color.clear.frame(width: 40)
        }
    }

    // MARK: - Account Card

    private var accountCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text("@\(appState.username)")
                    .font(.system(size: 12, weight: .medium))

                Text("Authenticated via GitHub CLI")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button("Logout") {
                appState.logout()
            }
            .buttonStyle(.plain)
            .font(.system(size: 10))
            .foregroundStyle(.red)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.5)))
    }

    // MARK: - Year Section

    private var yearSection: some View {
        HStack {
            Text("Time period")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer()

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
    }

    private var menuBarSection: some View {
        HStack {
            Text("Menu bar label")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer()

            Picker("", selection: menuBarDisplayModeBinding) {
                ForEach(MenuBarDisplayMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
            .fixedSize()
        }
    }

    private var refreshSection: some View {
        Toggle(isOn: automaticRefreshBinding) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Automatic refresh")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("Refresh in the background every 15 minutes")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }

    private var reminderSection: some View {
        Toggle(isOn: dailyReminderBinding) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Daily reminder")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("Send a notification at 6:00 PM if today is still empty")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }

    // MARK: - Actions

    private var actions: some View {
        HStack {
            Button("Quit App") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .keyboardShortcut("q", modifiers: .command)

            Spacer()

            Button("Done") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .keyboardShortcut(.defaultAction)
        }
    }

    private var selectedRangeBinding: Binding<ContributionRange> {
        Binding(
            get: { appState.selectedRange },
            set: { appState.selectRange($0) }
        )
    }

    private var menuBarDisplayModeBinding: Binding<MenuBarDisplayMode> {
        Binding(
            get: { appState.menuBarDisplayMode },
            set: { appState.selectMenuBarDisplayMode($0) }
        )
    }

    private var automaticRefreshBinding: Binding<Bool> {
        Binding(
            get: { appState.automaticRefreshEnabled },
            set: { appState.setAutomaticRefreshEnabled($0) }
        )
    }

    private var dailyReminderBinding: Binding<Bool> {
        Binding(
            get: { appState.dailyReminderEnabled },
            set: { appState.setDailyReminderEnabled($0) }
        )
    }
}
