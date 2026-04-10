// Sources/Models/ContributionModels.swift
// Data models for GitHub contribution calendar data.
// Maps the GitHub GraphQL API response into Swift structs.
// RELEVANT FILES: Sources/Services/GitHubService.swift, Sources/State/AppState.swift

import SwiftUI

// MARK: - GraphQL Response Models

struct GraphQLResponse: Codable {
    let data: GraphQLData?
    let errors: [GraphQLError]?
}

struct GraphQLData: Codable {
    let user: GitHubUser?
}

struct GraphQLError: Codable {
    let message: String
}

struct GitHubUser: Codable {
    let contributionsCollection: ContributionsCollection
}

struct ContributionsCollection: Codable {
    let contributionCalendar: ContributionCalendar
}

// MARK: - Contribution Calendar

struct ContributionCalendar: Codable {
    let totalContributions: Int
    let weeks: [ContributionWeek]
}

struct ContributionWeek: Codable, Identifiable {
    let contributionDays: [ContributionDay]

    /// Deterministic ID — uses the first day's date, or a stable fallback.
    var id: String {
        contributionDays.first?.date ?? "empty-week"
    }
}

struct ContributionDay: Codable, Identifiable {
    let contributionCount: Int
    let date: String
    let color: String
    let isVisible: Bool

    var id: String { date }

    var swiftUIColor: Color {
        Color(hex: color)
    }

    init(
        contributionCount: Int,
        date: String,
        color: String,
        isVisible: Bool = true
    ) {
        self.contributionCount = contributionCount
        self.date = date
        self.color = color
        self.isVisible = isVisible
    }

    private enum CodingKeys: String, CodingKey {
        case contributionCount
        case date
        case color
        case isVisible
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        contributionCount = try container.decode(Int.self, forKey: .contributionCount)
        date = try container.decode(String.self, forKey: .date)
        color = try container.decode(String.self, forKey: .color)
        isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(contributionCount, forKey: .contributionCount)
        try container.encode(date, forKey: .date)
        try container.encode(color, forKey: .color)
        try container.encode(isVisible, forKey: .isVisible)
    }
}

// MARK: - Contribution Helpers

struct ContributionSummary {
    let currentStreak: Int
    let longestStreak: Int
    let bestDay: ContributionDay?
    let averagePerDay: Double
}

extension ContributionCalendar {
    var allDays: [ContributionDay] {
        weeks.flatMap(\.contributionDays)
    }

    func clipped(to bounds: ClosedRange<Date>) -> ContributionCalendar {
        let clippedWeeks = weeks.map { week in
            ContributionWeek(
                contributionDays: week.contributionDays.map { day in
                    guard let date = day.parsedDate else { return day }
                    if bounds.contains(date) {
                        return day
                    }

                    return ContributionDay(
                        contributionCount: day.contributionCount,
                        date: day.date,
                        color: day.color,
                        isVisible: false
                    )
                }
            )
        }

        return ContributionCalendar(
            totalContributions: totalContributions,
            weeks: clippedWeeks
        )
    }

    func summary(dayCount: Int) -> ContributionSummary? {
        let visibleDays = allDays.filter { $0.isVisible }
        guard !visibleDays.isEmpty, dayCount > 0 else { return nil }

        let sortedDays = visibleDays.sorted { $0.date < $1.date }
        let activeDays = sortedDays.filter { $0.contributionCount > 0 }

        var longestStreak = 0
        var runningLongest = 0

        for day in sortedDays {
            if day.contributionCount > 0 {
                runningLongest += 1
                longestStreak = max(longestStreak, runningLongest)
            } else {
                runningLongest = 0
            }
        }

        var currentStreak = 0
        for day in sortedDays.reversed() {
            if day.contributionCount > 0 {
                currentStreak += 1
            } else if currentStreak > 0 {
                break
            }
        }

        let bestDay = activeDays.max {
            if $0.contributionCount == $1.contributionCount {
                return $0.date < $1.date
            }
            return $0.contributionCount < $1.contributionCount
        }

        return ContributionSummary(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            bestDay: bestDay,
            averagePerDay: Double(totalContributions) / Double(dayCount)
        )
    }
}

extension ContributionDay {
    var parsedDate: Date? {
        Self.dateParser.date(from: date)
    }

    private static let dateParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()
}

// MARK: - Color Extension

extension Color {
    /// Creates a Color from a hex string like "#30a14e".
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0

        guard hex.count == 6, scanner.scanHexInt64(&rgbValue) else {
            self.init(red: 0, green: 0, blue: 0)
            return
        }

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double((rgbValue & 0x0000FF)) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
