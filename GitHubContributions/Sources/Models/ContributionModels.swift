// Sources/Models/ContributionModels.swift
// Data models for GitHub contribution calendar data.
// Maps the GitHub GraphQL API response into Swift structs.
// RELEVANT FILES: Sources/Services/GitHubService.swift, Sources/State/AppState.swift

import SwiftUI

// MARK: - GraphQL Response Models

/// Top-level GraphQL response wrapper.
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

/// The full year contribution calendar — contains weeks, total count, and colors.
struct ContributionCalendar: Codable {
    let totalContributions: Int
    let weeks: [ContributionWeek]
}

struct ContributionWeek: Codable, Identifiable {
    let contributionDays: [ContributionDay]

    var id: String {
        contributionDays.first?.date ?? UUID().uuidString
    }
}

struct ContributionDay: Codable, Identifiable {
    let contributionCount: Int
    let date: String
    let color: String

    var id: String { date }

    /// Converts the hex color string from GitHub into a SwiftUI Color.
    var swiftUIColor: Color {
        Color(hex: color)
    }
}

// MARK: - Color Extension

extension Color {
    /// Creates a Color from a hex string like "#30a14e".
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double((rgbValue & 0x0000FF)) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
