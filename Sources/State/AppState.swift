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
    private var authTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?

    // MARK: - Computed

    var isLoggedIn: Bool {
        authStatus == .loggedIn && !token.isEmpty
    }

    var availableYears: [Int] {
        let current = Foundation.Calendar.current.component(.year, from: Date())
        return Array((current - 4)...current).reversed()
    }

    var contributionPeriodLabel: String {
        if let year = selectedYear {
            return "in \(year)"
        }
        return "in the last year"
    }

    /// Today's date as "yyyy-MM-dd" for matching against contribution days.
    private static let todayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()

    var todayDateString: String {
        Self.todayFormatter.string(from: Date())
    }

    /// Today's contribution count, extracted from the loaded calendar.
    var todayContributions: Int? {
        guard let cal = calendar else { return nil }
        let today = todayDateString
        for week in cal.weeks {
            if let day = week.contributionDays.first(where: { $0.date == today }) {
                return day.contributionCount
            }
        }
        return nil
    }

    // MARK: - Auth

    func checkAuth() {
        authTask?.cancel()
        authTask = Task { await performAuthCheck() }
    }

    func logout() {
        authTask?.cancel()
        refreshTask?.cancel()
        token = ""
        username = ""
        calendar = nil
        lastUpdated = nil
        errorMessage = nil
        selectedYear = nil
        isLoading = false
        authStatus = .needsLogin
    }

    // MARK: - Year Selection

    func selectYear(_ year: Int?) {
        selectedYear = year
        fetchContributions(resetCalendar: true)
    }

    func refreshContributions() {
        fetchContributions(resetCalendar: true)
    }

    // MARK: - Fetch Contributions

    func fetchContributions(resetCalendar: Bool = false) {
        if resetCalendar {
            calendar = nil
            errorMessage = nil
        }
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
            guard !Task.isCancelled else { return }
            token = fetchedToken

            let fetchedUsername = try await service.fetchUsername(token: fetchedToken)
            guard !Task.isCancelled else { return }
            username = fetchedUsername
            authStatus = .loggedIn

            fetchContributions()
        } catch let error as AuthError {
            guard !Task.isCancelled else { return }
            switch error {
            case .ghNotInstalled: authStatus = .needsGH
            case .notAuthenticated: authStatus = .needsLogin
            }
        } catch {
            guard !Task.isCancelled else { return }
            authStatus = .error(error.localizedDescription)
        }
    }

    // MARK: - Private: Fetch

    private func performFetch() async {
        guard isLoggedIn else { return }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

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
    }
}
