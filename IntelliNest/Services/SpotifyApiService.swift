//
//  SpotifyApiService.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-11.
//

import Foundation

/// The playlist favourite operations the music UI needs from Spotify. Hidden
/// behind a protocol so `MusicViewModel` can be tested with a stub and so the
/// feature degrades cleanly when no Spotify client is configured.
@MainActor
protocol SpotifyPlaylistFavoriting {
    /// Whether the user has completed the Spotify login at least once.
    var isAuthorized: Bool { get }
    /// Runs the interactive Spotify login.
    func authorize() async throws
    /// Whether the playlist is currently in the user's Spotify library.
    func isPlaylistSaved(playlistID: String) async -> Bool
    /// Adds the playlist to the user's Spotify library. Returns success.
    func savePlaylist(playlistID: String) async -> Bool
    /// Removes the playlist from the user's Spotify library. Returns success.
    func removePlaylist(playlistID: String) async -> Bool
}

/// Talks to the Spotify Web API to save/unsave (follow/unfollow) playlists in the
/// signed-in user's library and to read the current saved state. Bearer tokens
/// come from an injected `SpotifyTokenProviding`.
@MainActor
final class SpotifyApiService: SpotifyPlaylistFavoriting {
    private let tokenProvider: SpotifyTokenProviding
    private let session: URLSession
    private let baseURL = "https://api.spotify.com/v1"
    /// `/me` never changes within a session, so cache it after the first lookup.
    private var cachedUserID: String?

    init(tokenProvider: SpotifyTokenProviding, session: URLSession = .shared) {
        self.tokenProvider = tokenProvider
        self.session = session
    }

    var isAuthorized: Bool {
        tokenProvider.isAuthorized
    }

    func authorize() async throws {
        try await tokenProvider.authorize()
    }

    func isPlaylistSaved(playlistID: String) async -> Bool {
        do {
            let userID = try await currentUserID()
            let request = try await authorizedRequest(path: "/playlists/\(playlistID)/followers/contains",
                                                      method: "GET",
                                                      queryItems: [URLQueryItem(name: "ids", value: userID)])
            let (data, response) = try await session.data(for: request)
            guard isSuccess(response) else {
                return false
            }
            return (try? JSONDecoder().decode([Bool].self, from: data))?.first ?? false
        } catch {
            Log.error("Spotify isPlaylistSaved failed: \(error)")
            return false
        }
    }

    func savePlaylist(playlistID: String) async -> Bool {
        // public:false adds it to the library without surfacing it on the profile.
        await followRequest(playlistID: playlistID, method: "PUT", body: Data(#"{"public":false}"#.utf8))
    }

    func removePlaylist(playlistID: String) async -> Bool {
        await followRequest(playlistID: playlistID, method: "DELETE", body: nil)
    }

    private func followRequest(playlistID: String, method: String, body: Data?) async -> Bool {
        do {
            var request = try await authorizedRequest(path: "/playlists/\(playlistID)/followers", method: method)
            if let body {
                request.httpBody = body
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            let (_, response) = try await session.data(for: request)
            return isSuccess(response)
        } catch {
            Log.error("Spotify follow request (\(method)) failed: \(error)")
            return false
        }
    }

    private func currentUserID() async throws -> String {
        if let cachedUserID {
            return cachedUserID
        }
        let request = try await authorizedRequest(path: "/me", method: "GET")
        let (data, response) = try await session.data(for: request)
        guard isSuccess(response) else {
            throw EntityError.httpRequestFailure
        }
        let userID = try JSONDecoder().decode(SpotifyUser.self, from: data).id
        cachedUserID = userID
        return userID
    }

    private func authorizedRequest(path: String, method: String, queryItems: [URLQueryItem] = []) async throws -> URLRequest {
        let token = try await tokenProvider.validAccessToken()
        var components = URLComponents(string: baseURL + path)
        if queryItems.isNotEmpty {
            components?.queryItems = queryItems
        }
        guard let url = components?.url else {
            throw EntityError.badRequest
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func isSuccess(_ response: URLResponse) -> Bool {
        (response as? HTTPURLResponse).map { (200 ... 299).contains($0.statusCode) } ?? false
    }
}

private struct SpotifyUser: Decodable {
    let id: String
}

/// Stand-in used when no Spotify client is configured (SwiftUI previews, tests
/// that don't exercise favouriting). Reports unauthorized and no-ops every call,
/// so the star simply never appears.
@MainActor
struct DisabledSpotifyFavoriting: SpotifyPlaylistFavoriting {
    var isAuthorized: Bool { false }
    func authorize() async throws {}
    func isPlaylistSaved(playlistID _: String) async -> Bool { false }
    func savePlaylist(playlistID _: String) async -> Bool { false }
    func removePlaylist(playlistID _: String) async -> Bool { false }
}
