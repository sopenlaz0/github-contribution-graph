// Sources/Services/GitHubService.swift
// Handles communication with the GitHub GraphQL API.
// Fetches the contribution calendar for a given GitHub user.
// RELEVANT FILES: Sources/Models/ContributionModels.swift, Sources/State/AppState.swift

import Foundation

// MARK: - GitHub Service

/// Fetches contribution data from GitHub's GraphQL API.
final class GitHubService {

    private let endpoint = URL(string: "https://api.github.com/graphql")!

    /// Fetches the contribution calendar for the given GitHub username.
    /// Requires a Personal Access Token with `read:user` scope.
    func fetchContributions(username: String, token: String) async throws -> ContributionCalendar {
        let query = buildQuery(username: username)
        let body: [String: Any] = ["query": query]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw GitHubError.httpError(statusCode: httpResponse.statusCode)
        }

        let graphQLResponse = try JSONDecoder().decode(GraphQLResponse.self, from: data)

        if let errors = graphQLResponse.errors, !errors.isEmpty {
            throw GitHubError.graphQL(errors.map(\.message).joined(separator: ", "))
        }

        guard let calendar = graphQLResponse.data?.user?.contributionsCollection.contributionCalendar else {
            throw GitHubError.userNotFound(username)
        }

        return calendar
    }

    /// Builds the GraphQL query string.
    private func buildQuery(username: String) -> String {
        """
        query {
          user(login: "\(username)") {
            contributionsCollection {
              contributionCalendar {
                totalContributions
                weeks {
                  contributionDays {
                    contributionCount
                    date
                    color
                  }
                }
              }
            }
          }
        }
        """
    }
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
