// Sources/Services/GitHubAuth.swift
// Uses the `gh` CLI to authenticate — piggybacks on existing `gh auth login`.
// Zero config: if `gh` is already logged in, we just grab the token.
// RELEVANT FILES: Sources/State/AppState.swift, Sources/Services/GitHubService.swift

import Foundation

// MARK: - GitHub Auth (via `gh` CLI)

/// Grabs the auth token from the `gh` CLI that's already installed on the user's machine.
/// No OAuth apps, no Client IDs, no tokens to paste. Just `gh auth token`.
final class GitHubAuth {

    /// Returns the OAuth token from the user's `gh` CLI session.
    func getToken() async throws -> String {
        let output = try await runGH(["auth", "token"])
        guard !output.isEmpty else {
            throw AuthError.notAuthenticated
        }
        return output
    }

    /// Checks whether `gh` is installed and reachable.
    func isInstalled() -> Bool {
        findGHPath() != nil
    }

    /// Returns a human-readable auth status string.
    func getAuthStatus() async -> String? {
        try? await runGH(["auth", "status"])
    }

    // MARK: - Process Execution

    private func runGH(_ args: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = self.execute(args)
                continuation.resume(with: result)
            }
        }
    }

    private func execute(_ args: [String]) -> Result<String, AuthError> {
        guard let ghPath = findGHPath() else {
            return .failure(.ghNotInstalled)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ghPath)
        process.arguments = args

        // Ensure gh can find its config and dependencies
        var env = ProcessInfo.processInfo.environment
        let extraPaths = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        env["PATH"] = extraPaths + ":" + (env["PATH"] ?? "")
        process.environment = env

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return .failure(.ghNotInstalled)
        }

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if process.terminationStatus == 0 {
            return .success(output)
        } else {
            return .failure(.notAuthenticated)
        }
    }

    // MARK: - Find `gh` Binary

    /// Checks common install locations for the `gh` binary.
    private func findGHPath() -> String? {
        let candidates = [
            "/opt/homebrew/bin/gh",
            "/usr/local/bin/gh",
            "/usr/bin/gh",
            "/run/current-system/sw/bin/gh",
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Last resort: check user's home .nix-profile
        let homeNix = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".nix-profile/bin/gh").path
        if FileManager.default.isExecutableFile(atPath: homeNix) {
            return homeNix
        }

        return nil
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case ghNotInstalled
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .ghNotInstalled:
            return "GitHub CLI (gh) is not installed."
        case .notAuthenticated:
            return "Not logged in. Run `gh auth login` in your terminal."
        }
    }
}
