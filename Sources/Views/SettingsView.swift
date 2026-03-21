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

            Menu {
                Button("Last 12 months") { appState.selectYear(nil) }
                Divider()
                ForEach(appState.availableYears, id: \.self) { year in
                    Button(String(year)) { appState.selectYear(year) }
                }
            } label: {
                HStack(spacing: 3) {
                    Text(appState.selectedYear.map(String.init) ?? "Last 12 months")
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 7))
                }
                .font(.system(size: 11))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
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

            Spacer()

            Button("Done") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }
}
