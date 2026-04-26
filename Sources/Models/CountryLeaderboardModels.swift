// Sources/Models/CountryLeaderboardModels.swift
// Models for country/region contribution leaderboards.
// RELEVANT FILES: Sources/Services/CountryLeaderboardService.swift, Sources/State/AppState.swift, Sources/Views/CountryLeaderboardView.swift

import Foundation

struct CountryOption: Codable, Hashable, Identifiable {
    let slug: String
    let title: String
    let userCount: Int

    var id: String { slug }

    static let cambodia = CountryOption(slug: "cambodia", title: "Cambodia", userCount: 0)
}

struct CountryLeaderboardEntry: Codable, Identifiable, Hashable {
    let username: String
    let contributions: Int
    let sourceRank: Int
    let countrySlug: String
    let countryTitle: String

    var id: String { username.lowercased() }

    var githubURL: URL? {
        URL(string: "https://github.com/\(username)")
    }

    var averagePerDay: Double {
        let elapsed = max(1, Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1)
        return Double(contributions) / Double(elapsed)
    }

    var isSuspiciouslyAutomated: Bool {
        averagePerDay >= 500
    }
}

struct CountryLeaderboardSnapshot: Codable, Equatable {
    let countrySlug: String
    let countryTitle: String
    let range: ContributionRange
    let entries: [CountryLeaderboardEntry]
    let lastUpdated: Date

    func rank(for username: String) -> Int? {
        entries.firstIndex { $0.username.caseInsensitiveCompare(username) == .orderedSame }.map { $0 + 1 }
    }

    func entry(for username: String) -> CountryLeaderboardEntry? {
        entries.first { $0.username.caseInsensitiveCompare(username) == .orderedSame }
    }
}

enum CountryLeaderboardStatus: Equatable {
    case idle
    case loading
    case loaded
    case error(String)
}

struct CommittersTopCountryPayload: Codable {
    let title: String
    let user: [String]
}
