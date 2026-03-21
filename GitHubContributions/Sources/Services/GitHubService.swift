// Sources/Services/GitHubService.swift
// Handles communication with the GitHub API (both GraphQL and REST).
// Fetches contributions and authenticated user info.
// RELEVANT FILES: Sources/Models/ContributionModels.swift, Sources/Services/GitHubAuth.swift

import Foundation

// MARK: - GitHub Service

/// Fetches data from GitHub's APIs using an OAuth access token.
final class GitHubService {

    private let graphQLEndpoint = URL(string: "https://api.github.com/graphql")!
    private let restEndpoint = URL(string: "https://api.github.com")!

    // MARK: - Fetch Authenticated User

    /// Fetches the username of the authenticated user from the REST API.
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

    /// Fetches the contribution calendar for a given username using the GraphQL API.
    func fetchContributions(username: String, token: String) async throws -> ContributionCalendar {
        let query = buildQuery(username: username)
        let body: [String: Any] = ["query": query]

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

        return calendar
    }

    // MARK: - Private

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

// MARK: - REST API Models

/// Minimal user info from the GitHub REST API `/user` endpoint.
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
