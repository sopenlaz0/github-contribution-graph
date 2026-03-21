// Sources/Services/GitHubAuth.swift
// GitHub OAuth Device Flow implementation for desktop login.
// User clicks "Login", enters a code in their browser, and we get a token.
// RELEVANT FILES: Sources/State/AppState.swift, Sources/Services/GitHubService.swift

import Foundation

// MARK: - Configuration

/// Your GitHub OAuth App's Client ID.
/// Replace this with your own before building:
///   1. Go to github.com/settings/developers
///   2. Create a new OAuth App (any name/URL)
///   3. Enable "Device Flow"
///   4. Paste the Client ID here
let kGitHubClientId = "YOUR_CLIENT_ID_HERE"

// MARK: - GitHub Auth Service

/// Handles the GitHub OAuth Device Flow — same flow that `gh` CLI uses.
///
/// 1. Request a device code from GitHub
/// 2. Show the user a one-time code and open the browser
/// 3. Poll until the user authorizes
/// 4. Return the access token
final class GitHubAuth {

    // MARK: - Device Code Request

    /// Kicks off the Device Flow. Returns a code the user enters in their browser.
    func requestDeviceCode() async throws -> DeviceCodeResponse {
        let url = URL(string: "https://github.com/login/device/code")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "client_id=\(kGitHubClientId)&scope=read:user"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AuthError.deviceCodeRequestFailed
        }

        return try JSONDecoder().decode(DeviceCodeResponse.self, from: data)
    }

    // MARK: - Poll for Token

    /// Polls GitHub until the user authorizes (or the code expires).
    func pollForToken(deviceCode: String, interval: Int) async throws -> String {
        let url = URL(string: "https://github.com/login/oauth/access_token")!
        var pollInterval = max(interval, 5)

        while true {
            try await Task.sleep(nanoseconds: UInt64(pollInterval) * 1_000_000_000)
            try Task.checkCancellation()

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

            let body = "client_id=\(kGitHubClientId)&device_code=\(deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code"
            request.httpBody = body.data(using: .utf8)

            let (data, _) = try await URLSession.shared.data(for: request)
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

            if let accessToken = tokenResponse.accessToken {
                return accessToken
            }

            switch tokenResponse.error {
            case "authorization_pending":
                continue
            case "slow_down":
                pollInterval += 5
                continue
            case "expired_token":
                throw AuthError.codeExpired
            case "access_denied":
                throw AuthError.accessDenied
            default:
                throw AuthError.unknown(tokenResponse.error ?? "Unknown error")
            }
        }
    }
}

// MARK: - Response Models

struct DeviceCodeResponse: Codable {
    let deviceCode: String
    let userCode: String
    let verificationUri: String
    let expiresIn: Int
    let interval: Int

    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationUri = "verification_uri"
        case expiresIn = "expires_in"
        case interval
    }
}

struct TokenResponse: Codable {
    let accessToken: String?
    let tokenType: String?
    let scope: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
        case error
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case deviceCodeRequestFailed
    case codeExpired
    case accessDenied
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .deviceCodeRequestFailed:
            return "Failed to start login. Make sure the Client ID is configured."
        case .codeExpired:
            return "The login code expired. Please try again."
        case .accessDenied:
            return "Access was denied. Please try again."
        case .unknown(let msg):
            return "Login error: \(msg)"
        }
    }
}
