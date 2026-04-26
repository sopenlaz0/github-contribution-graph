// Sources/Views/CountryLeaderboardView.swift
// Country leaderboard panel powered by committers.top seed lists + GitHub GraphQL totals.
// RELEVANT FILES: Sources/Models/CountryLeaderboardModels.swift, Sources/Services/CountryLeaderboardService.swift, Sources/State/AppState.swift

import SwiftUI

struct CountryLeaderboardView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .onAppear {
                appState.refreshCountryLeaderboardIfNeeded()
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
        stateCard(systemImage: "flag", title: "Load \(appState.selectedCountryTitle)", subtitle: "Fetch the fast country preview for this period.") {
            Button("Load") { appState.refreshCountryLeaderboard() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
    }

    private var loadingState: some View {
        stateCard(systemImage: "arrow.triangle.2.circlepath", title: "Ranking \(appState.selectedCountryTitle)…", subtitle: "Fetching top seed users and your account.") {
            ProgressView()
                .controlSize(.small)
        }
    }

    private func errorState(_ message: String) -> some View {
        stateCard(systemImage: "exclamationmark.triangle", title: "Couldn’t load country preview", subtitle: message) {
            Button("Retry") { appState.refreshCountryLeaderboard() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }

    private func stateCard<Action: View>(
        systemImage: String,
        title: String,
        subtitle: String,
        @ViewBuilder action: () -> Action
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.green)
                .frame(width: 34, height: 34)
                .background(Circle().fill(.green.opacity(0.12)))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)
            action()
        }
        .padding(14)
        .frame(minHeight: 112)
        .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.26)))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.quaternary.opacity(0.65), lineWidth: 1)
        )
    }

    private func leaderboard(_ snapshot: CountryLeaderboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                rankCard(snapshot)
                    .frame(width: 176)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Preview top 5")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)

                    topRows(snapshot.entries.prefix(5), currentUsername: appState.username)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            footer(snapshot)
        }
    }

    private func rankCard(_ snapshot: CountryLeaderboardSnapshot) -> some View {
        let currentEntry = snapshot.entry(for: appState.username)
        let currentRank = snapshot.rank(for: appState.username)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(snapshot.isComplete ? "Your rank" : "Your preview rank")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                Spacer()
                if currentRank == 1 {
                    Text("#1")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.green))
                }
            }

            Text(currentRank.map { "#\($0)" } ?? "—")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(currentRank == 1 ? .green : .primary)
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 2) {
                Text("@\(appState.username)")
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)

                Text(currentEntry.map { "\($0.contributions.formatted()) contributions" } ?? "Not in seed list")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(.green.opacity(0.10)))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.green.opacity(0.22), lineWidth: 1)
        )
    }

    private func topRows(_ entries: ArraySlice<CountryLeaderboardEntry>, currentUsername: String) -> some View {
        VStack(spacing: 5) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                leaderboardRow(
                    rank: index + 1,
                    entry: entry,
                    isCurrentUser: isCurrentUser(entry, currentUsername: currentUsername)
                )
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
                    .truncationMode(.middle)

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
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(rowBackground(isCurrentUser: isCurrentUser))
            .clipShape(RoundedRectangle(cornerRadius: 8))
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
            Text(footerSummary(snapshot))
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .lineLimit(1)

            Spacer()

            Text(snapshot.lastUpdated.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
    }

    private func footerSummary(_ snapshot: CountryLeaderboardSnapshot) -> String {
        if snapshot.isComplete {
            return "Seeded by committers.top · \(snapshot.entries.count) users"
        }

        return "Fast preview · fetched \(snapshot.fetchedUserCount) of \(snapshot.seedUserCount) seed users"
    }

    private func isCurrentUser(_ entry: CountryLeaderboardEntry, currentUsername: String) -> Bool {
        entry.username.caseInsensitiveCompare(currentUsername) == .orderedSame
    }

    private func openUser(_ entry: CountryLeaderboardEntry) {
        guard let url = entry.githubURL else { return }
        NSWorkspace.shared.open(url)
    }
}
