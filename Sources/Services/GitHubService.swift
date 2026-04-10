// Sources/Services/GitHubService.swift
// Handles communication with the GitHub API (both GraphQL and REST).
// Fetches contributions (with optional year filtering) and user info.
// RELEVANT FILES: Sources/Models/ContributionModels.swift, Sources/Services/GitHubAuth.swift

import Foundation

// MARK: - GitHub Service

final class GitHubService {

    private let graphQLEndpoint = URL(string: "https://api.github.com/graphql")!
    private let restEndpoint = URL(string: "https://api.github.com")!

    // MARK: - Fetch Authenticated User

    func fetchUsername(token: String) async throws -> String {
        let url = restEndpoint.appendingPathComponent("user")

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw GitHubError.invalidResponse
        }

        let user = try JSONDecoder().decode(GitHubUserInfo.self, from: data)
        return user.login
    }

    // MARK: - Fetch Contributions

    /// Fetches the contribution calendar for the selected range.
    func fetchContributions(
        username: String,
        token: String,
        range: ContributionRange = .last12Months
    ) async throws -> ContributionCalendar {
        let (query, variables) = buildQuery(username: username, range: range)
        let body: [String: Any] = ["query": query, "variables": variables]

        var request = URLRequest(url: graphQLEndpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }

        guard http.statusCode == 200 else {
            throw GitHubError.httpError(statusCode: http.statusCode)
        }

        let graphQLResponse = try JSONDecoder().decode(GraphQLResponse.self, from: data)

        if let errors = graphQLResponse.errors, !errors.isEmpty {
            throw GitHubError.graphQL(errors.map(\.message).joined(separator: ", "))
        }

        guard let calendar = graphQLResponse.data?.user?.contributionsCollection.contributionCalendar else {
            throw GitHubError.userNotFound(username)
        }

        if let bounds = range.dateBounds() {
            return calendar.clipped(to: bounds)
        }

        return calendar
    }

    func fetchTodayContributionCount(username: String, token: String) async throws -> Int {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        guard let endOfDay = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay) else {
            return 0
        }

        let query = """
        query($login: String!, $from: DateTime!, $to: DateTime!) {
          user(login: $login) {
            contributionsCollection(from: $from, to: $to) {
              contributionCalendar {
                totalContributions
              }
            }
          }
        }
        """

        let variables: [String: Any] = [
            "login": username,
            "from": isoString(from: startOfDay),
            "to": isoString(from: endOfDay)
        ]

        let body: [String: Any] = ["query": query, "variables": variables]

        var request = URLRequest(url: graphQLEndpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }

        guard http.statusCode == 200 else {
            throw GitHubError.httpError(statusCode: http.statusCode)
        }

        let graphQLResponse = try JSONDecoder().decode(GraphQLResponse.self, from: data)

        if let errors = graphQLResponse.errors, !errors.isEmpty {
            throw GitHubError.graphQL(errors.map(\.message).joined(separator: ", "))
        }

        guard let totalContributions = graphQLResponse.data?.user?.contributionsCollection.contributionCalendar.totalContributions else {
            throw GitHubError.userNotFound(username)
        }

        return totalContributions
    }

    // MARK: - Private

    /// Uses GraphQL variables to avoid injection via username.
    private func buildQuery(username: String, range: ContributionRange) -> (String, [String: Any]) {
        var variables: [String: Any] = ["login": username]

        let query: String
        if let boundedRange = dateRange(for: range) {
            variables["from"] = boundedRange.from
            variables["to"] = boundedRange.to
            query = """
            query($login: String!, $from: DateTime!, $to: DateTime!) {
              user(login: $login) {
                contributionsCollection(from: $from, to: $to) {
                  contributionCalendar {
                    totalContributions
                    weeks { contributionDays { contributionCount date color } }
                  }
                }
              }
            }
            """
        } else {
            query = """
            query($login: String!) {
              user(login: $login) {
                contributionsCollection {
                  contributionCalendar {
                    totalContributions
                    weeks { contributionDays { contributionCount date color } }
                  }
                }
              }
            }
            """
        }

        return (query, variables)
    }

    private func dateRange(for range: ContributionRange) -> (from: String, to: String)? {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()

        switch range {
        case .last12Months:
            return nil
        case .thisMonth:
            let components = calendar.dateComponents([.year, .month], from: now)
            guard let startOfMonth = calendar.date(from: components) else { return nil }
            return (isoString(from: startOfMonth), isoString(from: now))
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

    private func isoString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}

// MARK: - REST API Models

struct GitHubUserInfo: Codable {
    let login: String
}

// MARK: - Errors

enum GitHubError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)
    case graphQL(String)
    case userNotFound(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from GitHub."
        case .httpError(let code):
            return "GitHub returned HTTP \(code)."
        case .graphQL(let message):
            return "GitHub API error: \(message)"
        case .userNotFound(let username):
            return "User '\(username)' not found."
        }
    }
}
