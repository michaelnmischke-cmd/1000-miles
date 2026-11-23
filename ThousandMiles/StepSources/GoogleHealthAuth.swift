import CryptoKit
import Foundation
import Security

/// Signs in to Google (which now runs Fitbit accounts) and keeps the access token fresh.
/// Tokens are kept in the iPhone's Keychain and never leave the phone.
struct GoogleHealthTokens: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
}

enum GoogleHealthError: LocalizedError {
    case notConfigured
    case cancelled
    case accountNotLinked
    case signedOut
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Fitbit isn't set up in this build yet."
        case .cancelled: "Sign-in was cancelled."
        case .accountNotLinked: "Your Fitbit account isn't linked to Google yet. Open the Fitbit app, follow its steps to move to a Google account, then try again."
        case .signedOut: "Fitbit was disconnected. Connect it again in Settings."
        case .server(let message): message
        }
    }
}

enum GoogleHealthAuth {
    /// Everything needed to open Google's sign-in page and finish afterwards.
    struct Request {
        let url: URL
        let verifier: String
    }

    static func makeRequest() throws -> Request {
        guard GoogleHealthConfig.isConfigured else { throw GoogleHealthError.notConfigured }
        let verifier = randomURLSafeString(bytes: 32)
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded
        var parts = URLComponents(url: GoogleHealthConfig.authorizeURL, resolvingAgainstBaseURL: false)!
        parts.queryItems = [
            .init(name: "client_id", value: GoogleHealthConfig.clientID),
            .init(name: "redirect_uri", value: GoogleHealthConfig.redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: GoogleHealthConfig.scope),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "prompt", value: "consent"),
        ]
        return Request(url: parts.url!, verifier: verifier)
    }

    /// Turns the page Google sends back into tokens.
    static func finish(callback: URL, request: Request) async throws -> GoogleHealthTokens {
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let error = items.first(where: { $0.name == "error" })?.value {
            throw error == "access_denied" ? GoogleHealthError.cancelled : GoogleHealthError.server(error)
        }
        guard let code = items.first(where: { $0.name == "code" })?.value else {
            throw GoogleHealthError.server("Google didn't send back a sign-in code.")
        }
        let response = try await postToken([
            "client_id": GoogleHealthConfig.clientID,
            "redirect_uri": GoogleHealthConfig.redirectURI,
            "grant_type": "authorization_code",
            "code": code,
            "code_verifier": request.verifier,
        ])
        guard let refresh = response.refresh_token else {
            throw GoogleHealthError.server("Google didn't allow ongoing access. Try connecting again.")
        }
        let tokens = GoogleHealthTokens(
            accessToken: response.access_token,
            refreshToken: refresh,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expires_in ?? 3600))
        )
        try Keychain.save(tokens)
        return tokens
    }

    /// A working access token, refreshed if it's about to expire.
    static func validAccessToken() async throws -> String {
        guard var tokens = Keychain.load() else { throw GoogleHealthError.signedOut }
        if tokens.expiresAt > Date().addingTimeInterval(60) { return tokens.accessToken }
        let response: TokenResponse
        do {
            response = try await postToken([
                "client_id": GoogleHealthConfig.clientID,
                "grant_type": "refresh_token",
                "refresh_token": tokens.refreshToken,
            ])
        } catch GoogleHealthError.server(let message) where message.contains("invalid_grant") {
            // Access was revoked, or (while the Google project is in testing) it expired after 7 days.
            Keychain.delete()
            throw GoogleHealthError.signedOut
        }
        tokens.accessToken = response.access_token
        tokens.expiresAt = Date().addingTimeInterval(TimeInterval(response.expires_in ?? 3600))
        if let newRefresh = response.refresh_token { tokens.refreshToken = newRefresh }
        try Keychain.save(tokens)
        return tokens.accessToken
    }

    static var isSignedIn: Bool { Keychain.load() != nil }

    static func signOut() async {
        if let tokens = Keychain.load() {
            var request = URLRequest(url: GoogleHealthConfig.revokeURL)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = formBody(["token": tokens.refreshToken])
            _ = try? await URLSession.shared.data(for: request)
        }
        Keychain.delete()
    }

    // MARK: Helpers

    private struct TokenResponse: Decodable {
        let access_token: String
        let refresh_token: String?
        let expires_in: Int?
    }

    private static func postToken(_ fields: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: GoogleHealthConfig.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody(fields)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw GoogleHealthError.server("Google sign-in failed: \(String(decoding: data, as: UTF8.self))")
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private static func formBody(_ fields: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return fields
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)!
    }

    private static func randomURLSafeString(bytes count: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes).base64URLEncoded
    }

    /// Stores the tokens as one Keychain item, readable only on this iPhone after first unlock.
    private enum Keychain {
        private static let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "app.thousandmiles.googlehealth",
            kSecAttrAccount as String: "tokens",
        ]

        static func save(_ tokens: GoogleHealthTokens) throws {
            let data = try JSONEncoder().encode(tokens)
            SecItemDelete(query as CFDictionary)
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let status = SecItemAdd(item as CFDictionary, nil)
            guard status == errSecSuccess else {
                throw GoogleHealthError.server("Couldn't save the Fitbit sign-in (Keychain error \(status)).")
            }
        }

        static func load() -> GoogleHealthTokens? {
            var lookup = query
            lookup[kSecReturnData as String] = true
            lookup[kSecMatchLimit as String] = kSecMatchLimitOne
            var result: AnyObject?
            guard SecItemCopyMatching(lookup as CFDictionary, &result) == errSecSuccess,
                  let data = result as? Data else { return nil }
            return try? JSONDecoder().decode(GoogleHealthTokens.self, from: data)
        }

        static func delete() {
            SecItemDelete(query as CFDictionary)
        }
    }
}

extension Data {
    var base64URLEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
