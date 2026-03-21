// Sources/State/AppState.swift
// Observable app state that drives the entire UI.
// Manages fetching, caching, and surfacing contribution data.
// RELEVANT FILES: Sources/Services/GitHubService.swift, Sources/Models/ContributionModels.swift

import SwiftUI

// MARK: - App State

@MainActor
final class AppState: ObservableObject {

    // MARK: - Persisted Settings

    /// GitHub username to fetch contributions for.
    @AppStorage("githubUsername") var username: String = ""

    /// GitHub Personal Access Token. Stored in UserDefaults for simplicity.
    /// TODO: Use Keychain for production-grade security.
    @AppStorage("githubToken") var token: String = ""

    // MARK: - Published State

    @Published var calendar: ContributionCalendar?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?

    // MARK: - Private

    private let service = GitHubService()
    private var refreshTask: Task<Void, Never>?

    // MARK: - Computed

    /// True when the user has configured both username and token.
    var isConfigured: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
        !token.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Actions

    /// Fetches contributions from GitHub. Debounces rapid calls.
    func fetchContributions() {
        refreshTask?.cancel()
        refreshTask = Task {
            await performFetch()
        }
    }

    private func performFetch() async {
        guard isConfigured else {
            errorMessage = "Please configure your GitHub username and token in Settings."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let result = try await service.fetchContributions(
                username: username.trimmingCharacters(in: .whitespaces),
                token: token.trimmingCharacters(in: .whitespaces)
            )

            guard !Task.isCancelled else { return }

            calendar = result
            lastUpdated = Date()
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
