// Sources/State/AppState.swift
// Observable app state that drives the entire UI.
// Uses `gh` CLI for auth, then fetches contributions via the GitHub API.
// RELEVANT FILES: Sources/Services/GitHubAuth.swift, Sources/Services/GitHubService.swift

import SwiftUI

// MARK: - Auth Status

enum AuthStatus: Equatable {
    case checking
    case loggedIn
    case needsGH          // `gh` CLI not installed
    case needsLogin       // `gh` installed but not authenticated
    case error(String)
}

// MARK: - App State

@MainActor
final class AppState: ObservableObject {

    // MARK: - Published State

    @Published var authStatus: AuthStatus = .checking
    @Published var username: String = ""
    @Published var calendar: ContributionCalendar?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?

    // MARK: - Private

    private let auth = GitHubAuth()
    private let service = GitHubService()
    private var token: String = ""
    private var refreshTask: Task<Void, Never>?

    // MARK: - Computed

    var isLoggedIn: Bool {
        authStatus == .loggedIn && !token.isEmpty
    }

    // MARK: - Auth

    /// Attempts to grab the token from `gh auth token`.
    /// If `gh` is installed and logged in, we're good to go.
    func checkAuth() {
        Task { await performAuthCheck() }
    }

    /// Clears local state (doesn't affect `gh` auth).
    func logout() {
        refreshTask?.cancel()
        token = ""
        username = ""
        calendar = nil
        lastUpdated = nil
        errorMessage = nil
        authStatus = .needsLogin
    }

    // MARK: - Fetch Contributions

    func fetchContributions() {
        refreshTask?.cancel()
        refreshTask = Task { await performFetch() }
    }

    // MARK: - Private: Auth Check

    private func performAuthCheck() async {
        authStatus = .checking

        guard auth.isInstalled() else {
            authStatus = .needsGH
            return
        }

        do {
            let fetchedToken = try await auth.getToken()
            token = fetchedToken

            let fetchedUsername = try await service.fetchUsername(token: fetchedToken)
            username = fetchedUsername
            authStatus = .loggedIn

            fetchContributions()
        } catch let error as AuthError {
            switch error {
            case .ghNotInstalled:
                authStatus = .needsGH
            case .notAuthenticated:
                authStatus = .needsLogin
            }
        } catch {
            authStatus = .error(error.localizedDescription)
        }
    }

    // MARK: - Private: Fetch

    private func performFetch() async {
        guard isLoggedIn else { return }

        isLoading = true
        errorMessage = nil

        do {
            let result = try await service.fetchContributions(
                username: username, token: token
            )
            guard !Task.isCancelled else { return }

            calendar = result
            lastUpdated = Date()
        } catch {
            guard !Task.isCancelled else { return }

            if let ghError = error as? GitHubError, case .httpError(401) = ghError {
                errorMessage = "Token expired. Click Refresh to re-authenticate."
                token = ""
                authStatus = .needsLogin
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }
}
