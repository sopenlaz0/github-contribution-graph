// Sources/State/AppState.swift
// Observable app state that drives the entire UI.
// Manages OAuth login, contribution fetching, and all published state.
// RELEVANT FILES: Sources/Services/GitHubAuth.swift, Sources/Services/GitHubService.swift

import SwiftUI

// MARK: - App State

@MainActor
final class AppState: ObservableObject {

    // MARK: - Persisted

    /// OAuth App Client ID. User enters this once during initial setup.
    @AppStorage("oauthClientId") var clientId: String = ""

    /// OAuth access token. Obtained from the Device Flow.
    @AppStorage("oauthToken") var token: String = ""

    /// GitHub username. Fetched automatically after login.
    @AppStorage("githubUsername") var username: String = ""

    // MARK: - Published State

    @Published var calendar: ContributionCalendar?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?

    /// The device code shown to the user during OAuth login.
    @Published var deviceUserCode: String?

    /// True while polling for OAuth authorization.
    @Published var isAuthorizing = false

    // MARK: - Private

    private let auth = GitHubAuth()
    private let service = GitHubService()
    private var authTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?

    // MARK: - Computed

    /// True when user has entered a Client ID.
    var hasClientId: Bool {
        !clientId.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// True when we have a valid token (user is logged in).
    var isLoggedIn: Bool {
        !token.isEmpty && !username.isEmpty
    }

    // MARK: - OAuth Login

    /// Starts the GitHub OAuth Device Flow.
    /// Opens the browser for the user to enter a code.
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

    /// Logs out by clearing all stored credentials and data.
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

    /// Fetches the contribution graph for the logged-in user.
    func fetchContributions() {
        refreshTask?.cancel()
        refreshTask = Task { await performFetch() }
    }

    // MARK: - Private: Login Flow

    private func performLogin() async {
        let trimmedClientId = clientId.trimmingCharacters(in: .whitespaces)
        guard !trimmedClientId.isEmpty else {
            errorMessage = "Please enter your OAuth App Client ID first."
            return
        }

        isAuthorizing = true
        errorMessage = nil
        deviceUserCode = nil

        do {
            // Step 1: Request device code
            let deviceCode = try await auth.requestDeviceCode(clientId: trimmedClientId)

            guard !Task.isCancelled else { return }

            // Step 2: Show the code to the user and open browser
            deviceUserCode = deviceCode.userCode

            if let url = URL(string: deviceCode.verificationUri) {
                NSWorkspace.shared.open(url)
            }

            // Step 3: Poll until user authorizes
            let accessToken = try await auth.pollForToken(
                clientId: trimmedClientId,
                deviceCode: deviceCode.deviceCode,
                interval: deviceCode.interval
            )

            guard !Task.isCancelled else { return }

            // Step 4: Fetch username with the new token
            let fetchedUsername = try await service.fetchUsername(token: accessToken)

            guard !Task.isCancelled else { return }

            // Step 5: Store credentials
            token = accessToken
            username = fetchedUsername
            isAuthorizing = false
            deviceUserCode = nil

            // Step 6: Load the contribution graph
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
                username: username,
                token: token
            )

            guard !Task.isCancelled else { return }

            calendar = result
            lastUpdated = Date()
        } catch {
            guard !Task.isCancelled else { return }

            // If we get a 401, the token is probably expired
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
