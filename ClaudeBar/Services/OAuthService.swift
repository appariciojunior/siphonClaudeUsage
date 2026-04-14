import Foundation
import CryptoKit
import AppKit

// Exact OAuth PKCE flow from github.com/jeremy-prt/claude-usage-mini
struct OAuthService {
    static let clientID    = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    static let redirectURI = "https://platform.claude.com/oauth/code/callback"
    static let authURL     = "https://claude.ai/oauth/authorize"
    static let tokenURL    = "https://platform.claude.com/v1/oauth/token"
    static let scopes      = ["user:profile", "user:inference"]

    // Builds the auth URL and returns everything needed — does NOT open the browser.
    // Caller is responsible for opening the URL after state updates settle.
    static func prepareFlow() -> (url: URL, verifier: String, state: String) {
        let verifier  = generateCodeVerifier()
        let challenge = generateCodeChallenge(from: verifier)
        let state     = generateCodeVerifier()

        var comps = URLComponents(url: URL(string: authURL)!, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "code",                  value: "true"),
            URLQueryItem(name: "client_id",             value: clientID),
            URLQueryItem(name: "response_type",         value: "code"),
            URLQueryItem(name: "redirect_uri",          value: redirectURI),
            URLQueryItem(name: "scope",                 value: scopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge",        value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state",                 value: state),
        ]
        return (comps.url!, verifier, state)
    }

    // rawCode may be the bare code, or "code#state", or the full redirect URL
    static func exchange(rawCode: String, verifier: String, state: String) async throws -> StoredCredentials {
        let parts = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "#", maxSplits: 1)
        var code  = String(parts[0])

        // If the user pasted the full redirect URL, extract the code param
        if let comps = URLComponents(string: code),
           let codeParam = comps.queryItems?.first(where: { $0.name == "code" })?.value {
            code = codeParam
        }

        let body: [String: String] = [
            "grant_type":    "authorization_code",
            "code":          code,
            "state":         state,
            "client_id":     clientID,
            "redirect_uri":  redirectURI,
            "code_verifier": verifier,
        ]
        return try await postToken(body: body)
    }

    static func refresh(using token: String) async throws -> StoredCredentials {
        let body: [String: String] = [
            "grant_type":    "refresh_token",
            "refresh_token": token,
            "client_id":     clientID,
        ]
        return try await postToken(body: body)
    }

    // MARK: - Private

    private static func postToken(body: [String: String]) async throws -> StoredCredentials {
        var req = URLRequest(url: URL(string: tokenURL)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw OAuthError.tokenExchange(msg)
        }

        guard let json   = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = json["access_token"] as? String else {
            throw OAuthError.tokenExchange("Missing access_token in response")
        }

        let refresh   = json["refresh_token"] as? String
        let expiresIn = json["expires_in"]    as? Int ?? 3600
        return StoredCredentials(
            accessToken:  access,
            refreshToken: refresh,
            expiresAt:    Date().addingTimeInterval(TimeInterval(expiresIn))
        )
    }

    private static func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncoded()
    }

    private static func generateCodeChallenge(from verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64URLEncoded()
    }
}

private extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

enum OAuthError: LocalizedError {
    case tokenExchange(String)
    var errorDescription: String? {
        if case .tokenExchange(let msg) = self { return "Auth failed: \(msg)" }
        return nil
    }
}
