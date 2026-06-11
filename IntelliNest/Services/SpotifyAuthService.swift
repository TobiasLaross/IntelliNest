//
//  SpotifyAuthService.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-11.
//

import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

/// Supplies a valid Spotify access token to the API layer, running the one-time
/// PKCE login and refreshing the access token when it expires. The favourite/save
/// service depends on this protocol so it never touches the web-auth session
/// directly — and so tests can inject a token without a browser round-trip.
@MainActor
protocol SpotifyTokenProviding {
    /// Whether a refresh token is stored, i.e. the user has logged in before.
    var isAuthorized: Bool { get }
    /// Runs the interactive PKCE login. Throws if the user cancels or it fails.
    func authorize() async throws
    /// Returns a non-expired access token, refreshing it first when needed.
    func validAccessToken() async throws -> String
}

enum SpotifyAuthError: Error {
    case missingClientID
    case notAuthorized
    case invalidCallback
    case tokenRequestFailed
}

/// Spotify Authorization Code + PKCE auth. Stores the token set in the Keychain
/// and refreshes the short-lived access token transparently. No client secret is
/// used or stored — PKCE is the recommended flow for a public mobile client.
@MainActor
final class SpotifyAuthService: NSObject, SpotifyTokenProviding {
    private let session: URLSession
    private let clientID = GlobalConstants.secretSpotifyClientID

    /// Must exactly match a Redirect URI registered in the Spotify app dashboard.
    private let redirectURI = "intellinest://spotify-callback"
    private let callbackScheme = "intellinest"
    /// `playlist-read-private` to read follow state, the two `modify` scopes to
    /// add/remove a playlist from the user's library.
    private let scopes = "playlist-read-private playlist-modify-public playlist-modify-private"
    private let authorizeEndpoint = "https://accounts.spotify.com/authorize"
    private let tokenEndpoint = "https://accounts.spotify.com/api/token"

    private var webAuthSession: ASWebAuthenticationSession?

    init(session: URLSession = .shared) {
        self.session = session
    }

    var isAuthorized: Bool {
        loadTokens()?.refreshToken.isNotEmpty == true
    }

    func validAccessToken() async throws -> String {
        guard let tokens = loadTokens() else {
            throw SpotifyAuthError.notAuthorized
        }
        // Refresh a minute early so an in-flight request never races the expiry.
        if tokens.expiry.addingTimeInterval(-60) > Date() {
            return tokens.accessToken
        }
        return try await refreshTokens(refreshToken: tokens.refreshToken).accessToken
    }

    // MARK: - Interactive login

    func authorize() async throws {
        guard clientID.isNotEmpty else {
            throw SpotifyAuthError.missingClientID
        }
        let verifier = Self.makeRandomURLSafeString()
        let state = Self.makeRandomURLSafeString()
        let challenge = Self.codeChallenge(for: verifier)

        var components = URLComponents(string: authorizeEndpoint)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "state", value: state)
        ]
        guard let authURL = components?.url else {
            throw SpotifyAuthError.invalidCallback
        }

        let callbackURL = try await presentWebAuth(url: authURL)
        guard let code = authorizationCode(from: callbackURL, expectedState: state) else {
            throw SpotifyAuthError.invalidCallback
        }
        try await exchangeCode(code, verifier: verifier)
    }

    private func presentWebAuth(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let webAuth = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callbackURL, error in
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: error ?? SpotifyAuthError.invalidCallback)
                }
            }
            webAuth.presentationContextProvider = self
            // Use a fresh (cookieless) session so login never silently binds to
            // whatever Spotify account Safari happens to be signed into. The house
            // account ("huset") differs from personal logins, so the account must
            // be a deliberate choice at sign-in. Re-auth is rare — only when the
            // stored refresh token is gone — since day-to-day calls use that token.
            webAuth.prefersEphemeralWebBrowserSession = true
            webAuthSession = webAuth
            if !webAuth.start() {
                continuation.resume(throwing: SpotifyAuthError.invalidCallback)
            }
        }
    }

    private func authorizationCode(from callbackURL: URL, expectedState: String) -> String? {
        let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems
        guard items?.first(where: { $0.name == "state" })?.value == expectedState else {
            Log.error("Spotify auth state mismatch")
            return nil
        }
        return items?.first { $0.name == "code" }?.value
    }

    // MARK: - Token exchange & refresh

    private func exchangeCode(_ code: String, verifier: String) async throws {
        let tokens = try await requestTokens(form: [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "client_id": clientID,
            "code_verifier": verifier
        ], fallbackRefreshToken: nil)
        store(tokens)
    }

    private func refreshTokens(refreshToken: String) async throws -> SpotifyStoredTokens {
        // Spotify may omit a new refresh token on refresh; keep the existing one.
        let tokens = try await requestTokens(form: [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientID
        ], fallbackRefreshToken: refreshToken)
        store(tokens)
        return tokens
    }

    private func requestTokens(form: [String: String], fallbackRefreshToken: String?) async throws -> SpotifyStoredTokens {
        guard let url = URL(string: tokenEndpoint) else {
            throw SpotifyAuthError.tokenRequestFailed
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formBody(form)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            Log.error("Spotify token request failed: \(body)")
            throw SpotifyAuthError.tokenRequestFailed
        }
        let decoded = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
        guard let refreshToken = decoded.refreshToken ?? fallbackRefreshToken else {
            throw SpotifyAuthError.tokenRequestFailed
        }
        return SpotifyStoredTokens(accessToken: decoded.accessToken,
                                   refreshToken: refreshToken,
                                   expiry: Date().addingTimeInterval(TimeInterval(decoded.expiresIn)))
    }

    // MARK: - PKCE helpers

    /// A high-entropy URL-safe string used for both the PKCE verifier and the
    /// CSRF `state` value.
    private static func makeRandomURLSafeString() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URLEncode(Data(bytes))
    }

    private static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return base64URLEncode(Data(digest))
    }

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func formBody(_ form: [String: String]) -> Data {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=")
        let encoded = form.map { key, value in
            let safeValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(key)=\(safeValue)"
        }
        return Data(encoded.joined(separator: "&").utf8)
    }

    // MARK: - Keychain storage

    private func store(_ tokens: SpotifyStoredTokens) {
        guard let data = try? JSONEncoder().encode(tokens) else {
            Log.error("Failed to encode Spotify tokens")
            return
        }
        let account = StorageKeys.spotifyTokens.rawValue
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: account]
        var status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }
        if status != errSecSuccess {
            Log.error("Failed to store Spotify tokens in keychain: \(status)")
        }
    }

    private func loadTokens() -> SpotifyStoredTokens? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: StorageKeys.spotifyTokens.rawValue,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecReturnData as String: kCFBooleanTrue!]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(SpotifyStoredTokens.self, from: data)
    }
}

extension SpotifyAuthService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scene = UIApplication.shared.connectedScenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
            return scene?.keyWindow ?? ASPresentationAnchor()
        }
    }
}

/// The token set persisted in the Keychain between launches.
private struct SpotifyStoredTokens: Codable {
    let accessToken: String
    let refreshToken: String
    let expiry: Date
}

/// Decodes the `accounts.spotify.com/api/token` response.
private struct SpotifyTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}
