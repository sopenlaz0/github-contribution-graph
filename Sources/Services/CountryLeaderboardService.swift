// Sources/Services/CountryLeaderboardService.swift
// Fetches committers.top country seed lists and ranks users by GitHub contributions.
// RELEVANT FILES: Sources/Models/CountryLeaderboardModels.swift, Sources/Services/GitHubService.swift, Sources/State/AppState.swift

import Foundation

final class CountryLeaderboardService {
    private let committersBaseURL = URL(string: "https://committers.top")!
    private let graphQLEndpoint = URL(string: "https://api.github.com/graphql")!
    private let batchSize = 24

    func fetchCountryOptions() async throws -> [CountryOption] {
        let url = committersBaseURL.appendingPathComponent("rank_only.json")
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw CountryLeaderboardError.invalidResponse
        }

        let payload = try JSONDecoder().decode([String: CommittersTopCountryPayload].self, from: data)
        return payload
            .filter { $0.key != "worldwide" }
            .map { slug, country in
                CountryOption(slug: slug, title: country.title, userCount: country.user.count)
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func fetchLeaderboard(
        countrySlug: String,
        range: ContributionRange,
        token: String,
        limit: Int = 256
    ) async throws -> CountryLeaderboardSnapshot {
        let country = try await fetchCountryPayload(slug: countrySlug)
        let usernames = Array(country.user.prefix(limit))
        let contributions = try await fetchContributionTotals(
            usernames: usernames,
            range: range,
            token: token
        )

        let entries = usernames.enumerated().map { index, username in
            CountryLeaderboardEntry(
                username: username,
                contributions: contributions[username.lowercased()] ?? 0,
                sourceRank: index + 1,
                countrySlug: countrySlug,
                countryTitle: country.title
            )
        }
        .sorted {
            if $0.contributions == $1.contributions {
                return $0.sourceRank < $1.sourceRank
            }
            return $0.contributions > $1.contributions
        }

        return CountryLeaderboardSnapshot(
            countrySlug: countrySlug,
            countryTitle: country.title,
            range: range,
            entries: entries,
            lastUpdated: Date()
        )
    }

    private func fetchCountryPayload(slug: String) async throws -> CommittersTopCountryPayload {
        let safeSlug = slug.filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
        guard safeSlug == slug, !safeSlug.isEmpty else {
            throw CountryLeaderboardError.invalidCountry(slug)
        }

        let url = committersBaseURL
            .appendingPathComponent("rank_only")
            .appendingPathComponent("\(safeSlug).json")
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw CountryLeaderboardError.invalidResponse
        }

        return try JSONDecoder().decode(CommittersTopCountryPayload.self, from: data)
    }

    private func fetchContributionTotals(
        usernames: [String],
        range: ContributionRange,
        token: String
    ) async throws -> [String: Int] {
        var totals: [String: Int] = [:]
        totals.reserveCapacity(usernames.count)

        for batch in usernames.chunked(into: batchSize) {
            try Task.checkCancellation()
            let batchTotals = try await fetchContributionTotalsBatch(
                usernames: batch,
                range: range,
                token: token
            )
            totals.merge(batchTotals) { current, _ in current }
        }

        return totals
    }

    private func fetchContributionTotalsBatch(
        usernames: [String],
        range: ContributionRange,
        token: String
    ) async throws -> [String: Int] {
        let safeUsernames = usernames.filter(Self.isSafeGitHubLogin)
        guard !safeUsernames.isEmpty else { return [:] }

        let requestBody = try buildGraphQLBody(usernames: safeUsernames, range: range)

        var request = URLRequest(url: graphQLEndpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestBody

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw CountryLeaderboardError.invalidResponse
        }

        guard http.statusCode == 200 else {
            throw CountryLeaderboardError.httpError(statusCode: http.statusCode)
        }

        return try parseContributionTotals(data: data, usernames: safeUsernames)
    }

    private func parseContributionTotals(data: Data, usernames: [String]) throws -> [String: Int] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CountryLeaderboardError.invalidResponse
        }

        if let errors = root["errors"] as? [[String: Any]], !errors.isEmpty, root["data"] == nil {
            let message = errors.compactMap { $0["message"] as? String }.joined(separator: ", ")
            throw CountryLeaderboardError.graphQL(message.isEmpty ? "Unknown GraphQL error" : message)
        }

        guard let data = root["data"] as? [String: Any] else {
            throw CountryLeaderboardError.invalidResponse
        }

        var totals: [String: Int] = [:]
        totals.reserveCapacity(usernames.count)

        for (index, username) in usernames.enumerated() {
            let alias = "u\(index)"
            guard
                let user = data[alias] as? [String: Any],
                let contributionsCollection = user["contributionsCollection"] as? [String: Any],
                let calendar = contributionsCollection["contributionCalendar"] as? [String: Any],
                let total = calendar["totalContributions"] as? Int
            else {
                totals[username.lowercased()] = 0
                continue
            }

            totals[username.lowercased()] = total
        }

        return totals
    }

    private func buildGraphQLBody(usernames: [String], range: ContributionRange) throws -> Data {
        let fields = usernames.enumerated().map { index, username in
            """
            u\(index): user(login: \"\(username)\") {
              contributionsCollection\(contributionCollectionArguments(for: range)) {
                contributionCalendar { totalContributions }
              }
            }
            """
        }
        .joined(separator: "\n")

        let query: String
        let variables: [String: Any]
        if let dateRange = Self.dateRange(for: range) {
            query = """
            query($from: DateTime!, $to: DateTime!) {
            \(fields)
            }
            """
            variables = ["from": dateRange.from, "to": dateRange.to]
        } else {
            query = """
            query {
            \(fields)
            }
            """
            variables = [:]
        }

        return try JSONSerialization.data(withJSONObject: ["query": query, "variables": variables])
    }

    private func contributionCollectionArguments(for range: ContributionRange) -> String {
        guard Self.dateRange(for: range) != nil else { return "" }
        return "(from: $from, to: $to)"
    }

    private static func isSafeGitHubLogin(_ login: String) -> Bool {
        let pattern = #"^[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?$"#
        return login.range(of: pattern, options: .regularExpression) != nil
    }

    private static func dateRange(for range: ContributionRange) -> (from: String, to: String)? {
        let calendar = Calendar(identifier: .gregorian)

        switch range {
        case .last12Months:
            return nil
        case .year(let year):
            var startComponents = DateComponents()
            startComponents.year = year
            startComponents.month = 1
            startComponents.day = 1
            startComponents.hour = 0
            startComponents.minute = 0
            startComponents.second = 0

            var endComponents = DateComponents()
            endComponents.year = year
            endComponents.month = 12
            endComponents.day = 31
            endComponents.hour = 23
            endComponents.minute = 59
            endComponents.second = 59

            guard
                let start = calendar.date(from: startComponents),
                let end = calendar.date(from: endComponents)
            else {
                return nil
            }

            return (isoString(from: start), isoString(from: end))
        }
    }

    private static func isoString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}

enum CountryLeaderboardError: LocalizedError {
    case invalidCountry(String)
    case invalidResponse
    case httpError(statusCode: Int)
    case graphQL(String)

    var errorDescription: String? {
        switch self {
        case .invalidCountry(let slug):
            return "Invalid country identifier '\(slug)'."
        case .invalidResponse:
            return "Invalid response while loading country rankings."
        case .httpError(let statusCode):
            return "Country ranking request returned HTTP \(statusCode)."
        case .graphQL(let message):
            return "GitHub API error while ranking country users: \(message)"
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var chunks: [[Element]] = []
        chunks.reserveCapacity((count / size) + 1)

        var index = startIndex
        while index < endIndex {
            let end = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            chunks.append(Array(self[index..<end]))
            index = end
        }

        return chunks
    }
}
