// Sources/State/AppState.swift
// Observable app state that drives the entire UI.
// Manages OAuth login, contribution fetching, and all published state.
// RELEVANT FILES: Sources/Services/GitHubAuth.swift, Sources/Services/GitHubService.swift

import SwiftUI

// MARK: - App State

@MainActor
final class AppState: ObservableObject {

    // MARK: - Persisted

    /// OAuth access token from the Device Flow.
    @AppStorage("oauthToken") var token: String = ""

    /// GitHub username, fetched automatically after login.
    @AppStorage("githubUsername") var username: String = ""

    // MARK: - Published State

    @Published var calendar: ContributionCalendar?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?

    /// The one-time code shown to the user during login.
    @Published var deviceUserCode: String?

    /// True while waiting for the user to authorize in the browser.
    @Published var isAuthorizing = false

    // MARK: - Private

    private let auth = GitHubAuth()
    private let service = GitHubService()
    private var authTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?

    // MARK: - Computed

    var isLoggedIn: Bool {
        !token.isEmpty && !username.isEmpty
    }

    // MARK: - Login

    /// Starts the GitHub OAuth Device Flow.
    /// Opens the browser, shows a code, and polls until authorized.
    func login() {
        authTask?.cancel()
        authTask = Task { await performLogin() }
    }

    /// Cancels an in-progress login attempt.
    func cancelLogin() {
        authTask?.cancel()
        isAuthorizing = false
        deviceUserCode = nil
        errorMessage = nil
    }

    /// Clears all stored credentials and data.
    func logout() {
        authTask?.cancel()
        refreshTask?.cancel()
        token = ""
        username = ""
        calendar = nil
        lastUpdated = nil
        deviceUserCode = nil
        isAuthorizing = false
        errorMessage = nil
    }

    // MARK: - Fetch Contributions

    func fetchContributions() {
        refreshTask?.cancel()
        refreshTask = Task { await performFetch() }
    }

    // MARK: - Private: Login

    private func performLogin() async {
        isAuthorizing = true
        errorMessage = nil
        deviceUserCode = nil

        do {
            // 1. Request a device code
            let deviceCode = try await auth.requestDeviceCode()
            guard !Task.isCancelled else { return }

            // 2. Show the code and open the browser
            deviceUserCode = deviceCode.userCode
            if let url = URL(string: deviceCode.verificationUri) {
                NSWorkspace.shared.open(url)
            }

            // 3. Poll until the user authorizes
            let accessToken = try await auth.pollForToken(
                deviceCode: deviceCode.deviceCode,
                interval: deviceCode.interval
            )
            guard !Task.isCancelled else { return }

            // 4. Get the username
            let fetchedUsername = try await service.fetchUsername(token: accessToken)
            guard !Task.isCancelled else { return }

            // 5. Done — store and load
            token = accessToken
            username = fetchedUsername
            isAuthorizing = false
            deviceUserCode = nil
            fetchContributions()

        } catch is CancellationError {
            isAuthorizing = false
            deviceUserCode = nil
        } catch {
            isAuthorizing = false
            deviceUserCode = nil
            errorMessage = error.localizedDescription
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
                errorMessage = "Session expired. Please log in again."
                logout()
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }
}
