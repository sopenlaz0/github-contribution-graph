// Sources/Views/CountryLeaderboardView.swift
// Country leaderboard panel powered by committers.top seed lists + GitHub GraphQL totals.
// RELEVANT FILES: Sources/Models/CountryLeaderboardModels.swift, Sources/Services/CountryLeaderboardService.swift, Sources/State/AppState.swift

import SwiftUI

struct CountryLeaderboardView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            content
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.28)))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.quaternary.opacity(0.7), lineWidth: 1)
        )
        .onAppear {
            appState.refreshCountryLeaderboardIfNeeded()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.green)

            Text("Country rank")
                .font(.system(size: 11, weight: .semibold))

            Text(appState.contributionPeriodLabel)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)

            Spacer(minLength: 8)

            Picker("", selection: selectedCountryBinding) {
                ForEach(appState.countryOptions) { country in
                    Text(country.title).tag(country.slug)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
            .fixedSize()
            .disabled(appState.countryLeaderboardStatus == .loading)

            Button(action: { appState.refreshCountryLeaderboard() }) {
                if appState.countryLeaderboardStatus == .loading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                }
            }
            .buttonStyle(.plain)
            .disabled(appState.countryLeaderboardStatus == .loading)
            .help("Refresh country ranking")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch appState.countryLeaderboardStatus {
        case .idle:
            idleState
        case .loading:
            loadingState
        case .loaded:
            if let snapshot = appState.countryLeaderboard {
                leaderboard(snapshot)
            } else {
                idleState
            }
        case .error(let message):
            errorState(message)
        }
    }

    private var idleState: some View {
        HStack(spacing: 8) {
            Text("Load the \(appState.selectedCountryTitle) leaderboard for this period.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer()
            Button("Load") { appState.refreshCountryLeaderboard() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
    }

    private var loadingState: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Ranking \(appState.selectedCountryTitle) users…")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(height: 26)
    }

    private func errorState(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer()
            Button("Retry") { appState.refreshCountryLeaderboard() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }

    private func leaderboard(_ snapshot: CountryLeaderboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            rankSummary(snapshot)
            topRows(snapshot.entries.prefix(5), currentUsername: appState.username)
            footer(snapshot)
        }
    }

    private func rankSummary(_ snapshot: CountryLeaderboardSnapshot) -> some View {
        let currentEntry = snapshot.entry(for: appState.username)
        let currentRank = snapshot.rank(for: appState.username)

        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your rank")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)

                Text(currentRank.map { "#\($0)" } ?? "Unranked")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(currentRank == 1 ? .green : .primary)
            }
            .frame(width: 72, alignment: .leading)

            Divider()
                .frame(height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text("@\(appState.username)")
                    .font(.system(size: 10, weight: .medium))
                Text(currentEntry.map { "\($0.contributions.formatted()) contributions" } ?? "Not in committers.top seed list")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if currentRank == 1 {
                Text("#1")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.green))
            }
        }
    }

    private func topRows(_ entries: ArraySlice<CountryLeaderboardEntry>, currentUsername: String) -> some View {
        VStack(spacing: 4) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                leaderboardRow(rank: index + 1, entry: entry, isCurrentUser: isCurrentUser(entry, currentUsername: currentUsername))
            }
        }
    }

    private func leaderboardRow(rank: Int, entry: CountryLeaderboardEntry, isCurrentUser: Bool) -> some View {
        Button {
            openUser(entry)
        } label: {
            HStack(spacing: 8) {
                Text("#\(rank)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(rank <= 3 ? .green : .secondary)
                    .frame(width: 30, alignment: .leading)

                Text(entry.username)
                    .font(.system(size: 10, weight: isCurrentUser ? .bold : .medium))
                    .foregroundStyle(isCurrentUser ? .green : .primary)
                    .lineLimit(1)

                if entry.isSuspiciouslyAutomated {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                        .help("Very high contribution velocity; may be automated.")
                }

                Spacer(minLength: 8)

                Text(entry.contributions.formatted())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(rowBackground(isCurrentUser: isCurrentUser))
        }
        .buttonStyle(.plain)
        .help("Open @\(entry.username) on GitHub")
    }

    private func rowBackground(isCurrentUser: Bool) -> Color {
        if isCurrentUser {
            return Color.green.opacity(0.12)
        }
        return Color.primary.opacity(0.04)
    }

    private func footer(_ snapshot: CountryLeaderboardSnapshot) -> some View {
        HStack(spacing: 4) {
            Text("Seeded by committers.top · top \(snapshot.entries.count) users")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)

            Spacer()

            Text(snapshot.lastUpdated.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
    }

    private var selectedCountryBinding: Binding<String> {
        Binding(
            get: { appState.selectedCountrySlug },
            set: { appState.selectCountry($0) }
        )
    }

    private func isCurrentUser(_ entry: CountryLeaderboardEntry, currentUsername: String) -> Bool {
        entry.username.caseInsensitiveCompare(currentUsername) == .orderedSame
    }

    private func openUser(_ entry: CountryLeaderboardEntry) {
        guard let url = entry.githubURL else { return }
        NSWorkspace.shared.open(url)
    }
}
