//
//  SpotifyApiService.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-11.
//

import Foundation

/// The Spotify playlist operations the music UI needs. Hidden behind a protocol
/// so `MusicViewModel` can be tested with a stub and so the feature degrades
/// cleanly when no Spotify client is configured.
@MainActor
protocol SpotifyPlaylistService {
    /// Whether the user has completed the Spotify login at least once.
    var isAuthorized: Bool { get }
    /// Runs the interactive Spotify login.
    func authorize() async throws
    /// The playlists in the signed-in account's library (owned + followed).
    func accountPlaylists() async -> [MusicSearchItem]
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
final class SpotifyApiService: SpotifyPlaylistService {
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

    func accountPlaylists() async -> [MusicSearchItem] {
        do {
            // 50 is the API's per-page max; plenty for a personal library and keeps
            // it to a single request (no pagination needed here).
            let request = try await authorizedRequest(path: "/me/playlists",
                                                      method: "GET",
                                                      queryItems: [URLQueryItem(name: "limit", value: "50")])
            let (data, response) = try await session.data(for: request)
            guard isSuccess(response) else {
                return []
            }
            return try JSONDecoder().decode(SpotifyPlaylistPage.self, from: data).playlists
        } catch {
            Log.error("Spotify accountPlaylists failed: \(error)")
            return []
        }
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

/// Decodes the `GET /me/playlists` page, mapping each Spotify playlist to the
/// app's `MusicSearchItem`. The Spotify `id` is rewritten into the `spotify://`
/// uri form Music Assistant expects for playback.
private struct SpotifyPlaylistPage: Decodable {
    let items: [SpotifyPlaylistItem]

    var playlists: [MusicSearchItem] {
        items.compactMap(\.searchItem)
    }
}

private struct SpotifyPlaylistItem: Decodable {
    let id: String?
    let name: String?
    let images: [SpotifyImage]?
    let owner: SpotifyOwner?

    var searchItem: MusicSearchItem? {
        guard let id, let name, name.isNotEmpty else {
            return nil
        }
        return MusicSearchItem(uri: "spotify://playlist/\(id)",
                               name: name,
                               mediaType: .playlist,
                               imageURL: images?.first?.url,
                               artist: owner?.displayName)
    }
}

private struct SpotifyImage: Decodable {
    let url: String?
}

private struct SpotifyOwner: Decodable {
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
    }
}

/// Stand-in used when no Spotify client is configured (SwiftUI previews, tests
/// that don't exercise Spotify). Reports unauthorized and no-ops every call, so
/// the star never appears and the favourites section stays empty.
@MainActor
struct DisabledSpotifyPlaylistService: SpotifyPlaylistService {
    var isAuthorized: Bool { false }
    func authorize() async throws {}
    func accountPlaylists() async -> [MusicSearchItem] { [] }
    func isPlaylistSaved(playlistID _: String) async -> Bool { false }
    func savePlaylist(playlistID _: String) async -> Bool { false }
    func removePlaylist(playlistID _: String) async -> Bool { false }
}
