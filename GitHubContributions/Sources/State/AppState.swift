// Sources/State/AppState.swift
// Observable app state that drives the entire UI.
// Uses `gh` CLI for auth, supports year selection for contributions.
// RELEVANT FILES: Sources/Services/GitHubAuth.swift, Sources/Services/GitHubService.swift

import SwiftUI

// MARK: - Auth Status

enum AuthStatus: Equatable {
    case checking
    case loggedIn
    case needsGH
    case needsLogin
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

    /// nil = last 12 months (default), or a specific year like 2026
    @Published var selectedYear: Int? = nil

    // MARK: - Private

    private let auth = GitHubAuth()
    private let service = GitHubService()
    private var token: String = ""
    private var refreshTask: Task<Void, Never>?

    // MARK: - Computed

    var isLoggedIn: Bool {
        authStatus == .loggedIn && !token.isEmpty
    }

    /// Available years for the picker: current year down to 4 years back.
    var availableYears: [Int] {
        let current = Foundation.Calendar.current.component(.year, from: Date())
        return Array((current - 4)...current).reversed()
    }

    /// Label for the contributions header.
    var contributionPeriodLabel: String {
        if let year = selectedYear {
            return "in \(year)"
        }
        return "in the last year"
    }

    // MARK: - Auth

    func checkAuth() {
        Task { await performAuthCheck() }
    }

    func logout() {
        refreshTask?.cancel()
        token = ""
        username = ""
        calendar = nil
        lastUpdated = nil
        errorMessage = nil
        authStatus = .needsLogin
    }

    // MARK: - Year Selection

    func selectYear(_ year: Int?) {
        selectedYear = year
        fetchContributions()
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
            case .ghNotInstalled: authStatus = .needsGH
            case .notAuthenticated: authStatus = .needsLogin
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
                username: username, token: token, year: selectedYear
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
