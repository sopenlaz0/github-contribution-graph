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

    /// Runtime Client ID. Used when the hardcoded default is the placeholder.
    /// Stored once, persists across launches.
    @AppStorage("oauthClientId") var storedClientId: String = ""

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

    /// The effective Client ID: use the hardcoded one if it's real, otherwise the stored one.
    var effectiveClientId: String {
        if kGitHubClientIdDefault != "YOUR_CLIENT_ID_HERE" {
            return kGitHubClientIdDefault
        }
        return storedClientId.trimmingCharacters(in: .whitespaces)
    }

    /// True when the user still needs to provide a Client ID.
    var needsClientId: Bool {
        effectiveClientId.isEmpty
    }

    // MARK: - Login

    /// Starts the GitHub OAuth Device Flow.
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
        let clientId = effectiveClientId
        guard !clientId.isEmpty else {
            errorMessage = "Enter your Client ID to continue."
            return
        }

        isAuthorizing = true
        errorMessage = nil
        deviceUserCode = nil

        do {
            let deviceCode = try await auth.requestDeviceCode(clientId: clientId)
            guard !Task.isCancelled else { return }

            deviceUserCode = deviceCode.userCode
            if let url = URL(string: deviceCode.verificationUri) {
                NSWorkspace.shared.open(url)
            }

            let accessToken = try await auth.pollForToken(
                clientId: clientId,
                deviceCode: deviceCode.deviceCode,
                interval: deviceCode.interval
            )
            guard !Task.isCancelled else { return }

            let fetchedUsername = try await service.fetchUsername(token: accessToken)
            guard !Task.isCancelled else { return }

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
