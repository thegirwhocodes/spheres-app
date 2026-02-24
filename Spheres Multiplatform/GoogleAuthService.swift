//
//  GoogleAuthService.swift
//  Spheres - Smart Life Manager
//
//  Handles Google OAuth 2.0 with PKCE for Gmail API access.
//  Uses loopback HTTP server (Google's recommended flow for desktop apps).
//  Tokens stored securely in macOS Keychain.
//

import Foundation
import Network
import CryptoKit
import AppKit

// MARK: - Google Auth Errors

enum GoogleAuthError: Error, LocalizedError {
    case authCancelled
    case tokenExchangeFailed(String)
    case tokenRefreshFailed
    case noRefreshToken
    case networkError(String)
    case serverFailed

    var errorDescription: String? {
        switch self {
        case .authCancelled: return "Google sign-in was cancelled"
        case .tokenExchangeFailed(let detail): return "Token exchange failed: \(detail)"
        case .tokenRefreshFailed: return "Could not refresh Google access token"
        case .noRefreshToken: return "No refresh token available — please sign in again"
        case .networkError(let detail): return "Network error: \(detail)"
        case .serverFailed: return "Could not start local auth server"
        }
    }
}

// MARK: - Google Auth Service

@MainActor
class GoogleAuthService: ObservableObject {
    static let shared = GoogleAuthService()

    @Published var isSignedIn: Bool = false
    @Published var userEmail: String? = nil
    @Published var isAuthenticating: Bool = false

    let clientId = "331789486733-uj3em7nntdbi691f7geefvat7gtj5ee7.apps.googleusercontent.com"
    private let scope = "https://www.googleapis.com/auth/gmail.readonly"
    private let tokenURL = "https://oauth2.googleapis.com/token"
    private let authURL = "https://accounts.google.com/o/oauth2/v2/auth"

    // Keychain keys
    private let keychainAccessToken = "com.naomiivie.spheres.google.accessToken"
    private let keychainRefreshToken = "com.naomiivie.spheres.google.refreshToken"
    private let keychainTokenExpiry = "com.naomiivie.spheres.google.tokenExpiry"
    private let keychainUserEmail = "com.naomiivie.spheres.google.userEmail"

    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpiry: Date?

    private init() {
        loadTokensFromKeychain()
    }

    // MARK: - Public API

    /// Start the OAuth sign-in flow (opens system browser)
    func signIn() async throws {
        isAuthenticating = true
        defer { isAuthenticating = false }

        // Generate PKCE
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        // Start loopback server and get port + auth code
        let (port, authCode) = try await startLoopbackAndAuthorize(codeChallenge: codeChallenge)

        // Exchange code for tokens
        try await exchangeCodeForTokens(code: authCode, codeVerifier: codeVerifier, port: port)

        // Fetch user email
        await fetchUserEmail()

        isSignedIn = true
        print("DEBUG: Google sign-in complete for \(userEmail ?? "unknown")")
    }

    /// Sign out and clear all tokens
    func signOut() {
        accessToken = nil
        refreshToken = nil
        tokenExpiry = nil
        userEmail = nil
        isSignedIn = false

        deleteFromKeychain(key: keychainAccessToken)
        deleteFromKeychain(key: keychainRefreshToken)
        deleteFromKeychain(key: keychainTokenExpiry)
        deleteFromKeychain(key: keychainUserEmail)

        print("DEBUG: Google signed out")
    }

    /// Get a valid access token, refreshing if needed
    func getValidAccessToken() async throws -> String {
        // If token is still valid (with 5 min buffer), return it
        if let token = accessToken, let expiry = tokenExpiry, expiry > Date().addingTimeInterval(300) {
            return token
        }

        // Try to refresh
        guard let refresh = refreshToken else {
            isSignedIn = false
            throw GoogleAuthError.noRefreshToken
        }

        try await refreshAccessToken(refreshToken: refresh)

        guard let token = accessToken else {
            isSignedIn = false
            throw GoogleAuthError.tokenRefreshFailed
        }

        return token
    }

    // MARK: - PKCE

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64URLEncodedString()
    }

    // MARK: - Loopback Server + Browser Auth

    private func startLoopbackAndAuthorize(codeChallenge: String) async throws -> (UInt16, String) {
        // Find available port and start server
        let listener = try NWListener(using: .tcp, on: .any)
        listener.parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: .ipv4(.loopback), port: .any)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(UInt16, String), Error>) in
            var hasResumed = false

            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard let port = listener.port?.rawValue else {
                        if !hasResumed { hasResumed = true; continuation.resume(throwing: GoogleAuthError.serverFailed) }
                        return
                    }

                    // Build auth URL and open browser
                    let state = UUID().uuidString
                    let redirectURI = "http://127.0.0.1:\(port)"
                    var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
                    components.queryItems = [
                        URLQueryItem(name: "client_id", value: self.clientId),
                        URLQueryItem(name: "redirect_uri", value: redirectURI),
                        URLQueryItem(name: "response_type", value: "code"),
                        URLQueryItem(name: "scope", value: self.scope),
                        URLQueryItem(name: "code_challenge", value: codeChallenge),
                        URLQueryItem(name: "code_challenge_method", value: "S256"),
                        URLQueryItem(name: "state", value: state),
                        URLQueryItem(name: "access_type", value: "offline"),
                        URLQueryItem(name: "prompt", value: "consent"),
                    ]

                    DispatchQueue.main.async {
                        if let url = components.url {
                            NSWorkspace.shared.open(url)
                        }
                    }

                case .failed(let error):
                    if !hasResumed { hasResumed = true; continuation.resume(throwing: GoogleAuthError.networkError(error.localizedDescription)) }

                default:
                    break
                }
            }

            listener.newConnectionHandler = { connection in
                connection.start(queue: .global(qos: .userInitiated))

                connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, _ in
                    guard let data = data, let request = String(data: data, encoding: .utf8) else {
                        connection.cancel()
                        return
                    }

                    // Parse the GET request for the auth code
                    // Request looks like: GET /?code=AUTH_CODE&state=... HTTP/1.1
                    if let code = self.extractAuthCode(from: request) {
                        // Send success page to browser
                        let html = """
                        HTTP/1.1 200 OK\r
                        Content-Type: text/html\r
                        Connection: close\r
                        \r
                        <html><body style="background:#1a1a2e;color:#fff;font-family:system-ui;display:flex;align-items:center;justify-content:center;height:100vh;margin:0">
                        <div style="text-align:center"><h1>✓ Connected to Spheres</h1><p style="color:#888">You can close this tab.</p></div>
                        </body></html>
                        """
                        connection.send(content: html.data(using: .utf8), completion: .contentProcessed { _ in
                            connection.cancel()
                        })

                        // Stop listener and return the code
                        listener.cancel()
                        let port = listener.port?.rawValue ?? 0
                        if !hasResumed {
                            hasResumed = true
                            continuation.resume(returning: (port, code))
                        }
                    } else {
                        // Send error page
                        let html = """
                        HTTP/1.1 400 Bad Request\r
                        Content-Type: text/html\r
                        Connection: close\r
                        \r
                        <html><body style="background:#1a1a2e;color:#fff;font-family:system-ui;display:flex;align-items:center;justify-content:center;height:100vh;margin:0">
                        <div style="text-align:center"><h1>Authentication Failed</h1><p style="color:#888">Please try again from Spheres.</p></div>
                        </body></html>
                        """
                        connection.send(content: html.data(using: .utf8), completion: .contentProcessed { _ in
                            connection.cancel()
                        })

                        listener.cancel()
                        if !hasResumed {
                            hasResumed = true
                            continuation.resume(throwing: GoogleAuthError.authCancelled)
                        }
                    }
                }
            }

            listener.start(queue: .global(qos: .userInitiated))

            // Timeout after 2 minutes
            DispatchQueue.global().asyncAfter(deadline: .now() + 120) {
                listener.cancel()
                if !hasResumed {
                    hasResumed = true
                    continuation.resume(throwing: GoogleAuthError.authCancelled)
                }
            }
        }
    }

    private func extractAuthCode(from request: String) -> String? {
        // Parse "GET /?code=XXXX&state=YYYY HTTP/1.1"
        guard let urlLine = request.components(separatedBy: "\r\n").first,
              let pathPart = urlLine.components(separatedBy: " ").dropFirst().first,
              let components = URLComponents(string: "http://localhost\(pathPart)"),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            return nil
        }
        return code
    }

    // MARK: - Token Exchange

    private func exchangeCodeForTokens(code: String, codeVerifier: String, port: UInt16) async throws {
        let redirectURI = "http://127.0.0.1:\(port)"

        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "code": code,
            "client_id": clientId,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code",
            "code_verifier": codeVerifier
        ]
        request.httpBody = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("DEBUG: Google token exchange failed: \(errorBody)")
            throw GoogleAuthError.tokenExchangeFailed(errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newAccessToken = json["access_token"] as? String,
              let expiresIn = json["expires_in"] as? Int else {
            throw GoogleAuthError.tokenExchangeFailed("Invalid response format")
        }

        accessToken = newAccessToken
        tokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn))

        if let newRefreshToken = json["refresh_token"] as? String {
            refreshToken = newRefreshToken
        }

        saveTokensToKeychain()
    }

    // MARK: - Token Refresh

    private func refreshAccessToken(refreshToken: String) async throws {
        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id": clientId,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        request.httpBody = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("DEBUG: Google token refresh failed")
            isSignedIn = false
            throw GoogleAuthError.tokenRefreshFailed
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newAccessToken = json["access_token"] as? String,
              let expiresIn = json["expires_in"] as? Int else {
            throw GoogleAuthError.tokenRefreshFailed
        }

        accessToken = newAccessToken
        tokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn))

        // Refresh token may also be returned
        if let newRefresh = json["refresh_token"] as? String {
            self.refreshToken = newRefresh
        }

        saveTokensToKeychain()
        print("DEBUG: Google access token refreshed, expires in \(expiresIn)s")
    }

    // MARK: - Fetch User Email

    private func fetchUserEmail() async {
        guard let token = accessToken else { return }

        var request = URLRequest(url: URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/profile")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let email = json["emailAddress"] as? String {
                userEmail = email
                saveToKeychain(key: keychainUserEmail, value: email)
            }
        } catch {
            print("DEBUG: Could not fetch Google user email: \(error)")
        }
    }

    // MARK: - Keychain Helpers

    private func saveTokensToKeychain() {
        if let token = accessToken {
            saveToKeychain(key: keychainAccessToken, value: token)
        }
        if let refresh = refreshToken {
            saveToKeychain(key: keychainRefreshToken, value: refresh)
        }
        if let expiry = tokenExpiry {
            saveToKeychain(key: keychainTokenExpiry, value: String(expiry.timeIntervalSince1970))
        }
    }

    private func loadTokensFromKeychain() {
        accessToken = loadFromKeychain(key: keychainAccessToken)
        refreshToken = loadFromKeychain(key: keychainRefreshToken)
        userEmail = loadFromKeychain(key: keychainUserEmail)

        if let expiryString = loadFromKeychain(key: keychainTokenExpiry),
           let interval = Double(expiryString) {
            tokenExpiry = Date(timeIntervalSince1970: interval)
        }

        // Check if we have valid tokens
        isSignedIn = refreshToken != nil
    }

    private func saveToKeychain(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.naomiivie.spheres.google",
        ]

        // Delete existing
        SecItemDelete(query as CFDictionary)

        // Add new
        var addQuery = query
        addQuery[kSecValueData as String] = data
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func loadFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.naomiivie.spheres.google",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.naomiivie.spheres.google",
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Base64URL Encoding

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
