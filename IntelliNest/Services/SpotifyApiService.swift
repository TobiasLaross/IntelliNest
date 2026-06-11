//
//  SpotifyApiService.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-11.
//

import Foundation

/// A known personal Spotify account whose public playlists are surfaced in the
/// music view as its own titled section. Baked into the app (no in-app management);
/// add another account by appending to `SpotifyPersonalAccount.configured`.
struct SpotifyPersonalAccount: Identifiable, Equatable {
    /// The Spotify user id (the `/users/{id}` path component).
    let userID: String
    /// The Swedish section title shown above this account's playlists.
    let title: String

    var id: String { userID }

    /// The ordered list of personal accounts. Sections render in this order.
    /// Only Tobias is configured now; Sarah is appended here once her id is known.
    static let configured: [SpotifyPersonalAccount] = [
        SpotifyPersonalAccount(userID: "tobiasc91", title: "Mina spellistor")
    ]
}

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
    /// The Spotify ids of the playlists the user can edit (owned or collaborative).
    /// Used to gate the add-to-playlist picker and the remove-from-playlist action.
    func editablePlaylistIDs() async -> Set<String>
    /// The public playlists on another Spotify user's profile (created + followed).
    /// Reuses the signed-in account's token; only public playlists are visible.
    func userPlaylists(userID: String) async -> [MusicSearchItem]
    /// Whether the playlist is currently in the user's Spotify library.
    func isPlaylistSaved(playlistID: String) async -> Bool
    /// Adds the playlist to the user's Spotify library. Returns success.
    func savePlaylist(playlistID: String) async -> Bool
    /// Removes the playlist from the user's Spotify library. Returns success.
    func removePlaylist(playlistID: String) async -> Bool
    /// The subset of `trackIDs` that are in the user's Liked Songs.
    func savedSongIDs(trackIDs: [String]) async -> Set<String>
    /// Adds the track to the user's Liked Songs. Returns success.
    func saveSong(trackID: String) async -> Bool
    /// Removes the track from the user's Liked Songs. Returns success.
    func removeSong(trackID: String) async -> Bool
    /// Adds the track to the given playlist. Returns success.
    func addTrack(playlistID: String, trackID: String) async -> Bool
    /// Removes every occurrence of the track from the given playlist. Returns success.
    func removeTrack(playlistID: String, trackID: String) async -> Bool
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

    func userPlaylists(userID: String) async -> [MusicSearchItem] {
        do {
            // 50 is the API's per-page max. Matching accountPlaylists' single-page
            // limit keeps this to one request; a personal profile rarely exceeds it
            // and pagination is out of scope (see design.md).
            let request = try await authorizedRequest(path: "/users/\(userID)/playlists",
                                                      method: "GET",
                                                      queryItems: [URLQueryItem(name: "limit", value: "50")])
            let (data, response) = try await session.data(for: request)
            guard isSuccess(response) else {
                return []
            }
            return try JSONDecoder().decode(SpotifyPlaylistPage.self, from: data).playlists
        } catch {
            Log.error("Spotify userPlaylists(\(userID)) failed: \(error)")
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

    func editablePlaylistIDs() async -> Set<String> {
        do {
            let userID = try await currentUserID()
            let request = try await authorizedRequest(path: "/me/playlists",
                                                      method: "GET",
                                                      queryItems: [URLQueryItem(name: "limit", value: "50")])
            let (data, response) = try await session.data(for: request)
            guard isSuccess(response) else {
                return []
            }
            let page = try JSONDecoder().decode(SpotifyPlaylistPage.self, from: data)
            return page.editableIDs(currentUserID: userID)
        } catch {
            Log.error("Spotify editablePlaylistIDs failed: \(error)")
            return []
        }
    }

    // MARK: - Liked Songs

    func savedSongIDs(trackIDs: [String]) async -> Set<String> {
        guard trackIDs.isNotEmpty else {
            return []
        }
        do {
            // `/me/tracks/contains` takes up to 50 ids and returns a bool array in
            // the same order; zip it back to the saved subset.
            let request = try await authorizedRequest(path: "/me/tracks/contains",
                                                      method: "GET",
                                                      queryItems: [URLQueryItem(name: "ids", value: trackIDs.joined(separator: ","))])
            let (data, response) = try await session.data(for: request)
            guard isSuccess(response) else {
                return []
            }
            let flags = try JSONDecoder().decode([Bool].self, from: data)
            let saved = zip(trackIDs, flags).compactMap { trackID, isSaved in isSaved ? trackID : nil }
            return Set(saved)
        } catch {
            Log.error("Spotify savedSongIDs failed: \(error)")
            return []
        }
    }

    func saveSong(trackID: String) async -> Bool {
        await libraryTracksRequest(method: "PUT", trackID: trackID)
    }

    func removeSong(trackID: String) async -> Bool {
        await libraryTracksRequest(method: "DELETE", trackID: trackID)
    }

    private func libraryTracksRequest(method: String, trackID: String) async -> Bool {
        do {
            var request = try await authorizedRequest(path: "/me/tracks", method: method)
            request.httpBody = try JSONSerialization.data(withJSONObject: ["ids": [trackID]])
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let (_, response) = try await session.data(for: request)
            return isSuccess(response)
        } catch {
            Log.error("Spotify library tracks request (\(method)) failed: \(error)")
            return false
        }
    }

    // MARK: - Playlist tracks

    func addTrack(playlistID: String, trackID: String) async -> Bool {
        await playlistTracksRequest(method: "POST",
                                    playlistID: playlistID,
                                    body: ["uris": [Self.trackURI(trackID)]])
    }

    func removeTrack(playlistID: String, trackID: String) async -> Bool {
        await playlistTracksRequest(method: "DELETE",
                                    playlistID: playlistID,
                                    body: ["tracks": [["uri": Self.trackURI(trackID)]]])
    }

    private func playlistTracksRequest(method: String, playlistID: String, body: [String: Any]) async -> Bool {
        do {
            var request = try await authorizedRequest(path: "/playlists/\(playlistID)/tracks", method: method)
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let (_, response) = try await session.data(for: request)
            return isSuccess(response)
        } catch {
            Log.error("Spotify playlist tracks request (\(method)) failed: \(error)")
            return false
        }
    }

    /// Spotify's track endpoints want the `spotify:track:<id>` URI form, not the
    /// `spotify://track/<id>` form Music Assistant uses.
    private static func trackURI(_ trackID: String) -> String {
        "spotify:track:\(trackID)"
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
    // Spotify occasionally returns `null` entries in a playlist page's `items`
    // array (e.g. an unavailable playlist on a large public profile). Decoding the
    // element as optional lets a `null` map to nil instead of throwing and losing
    // the whole page — which would otherwise leave a populated profile empty.
    let items: [SpotifyPlaylistItem?]

    var playlists: [MusicSearchItem] {
        items.compactMap { $0?.searchItem }
    }

    /// The ids of playlists the signed-in user may edit: ones they own, plus any
    /// collaborative playlist regardless of owner.
    func editableIDs(currentUserID: String) -> Set<String> {
        Set(items.compactMap { $0?.editableID(currentUserID: currentUserID) })
    }
}

private struct SpotifyPlaylistItem: Decodable {
    let id: String?
    let name: String?
    let images: [SpotifyImage]?
    let owner: SpotifyOwner?
    let collaborative: Bool?

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

    func editableID(currentUserID: String) -> String? {
        guard let id else {
            return nil
        }
        let owned = owner?.id == currentUserID
        return owned || collaborative == true ? id : nil
    }
}

private struct SpotifyImage: Decodable {
    let url: String?
}

private struct SpotifyOwner: Decodable {
    let id: String?
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case id
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
    func editablePlaylistIDs() async -> Set<String> { [] }
    func userPlaylists(userID _: String) async -> [MusicSearchItem] { [] }
    func isPlaylistSaved(playlistID _: String) async -> Bool { false }
    func savePlaylist(playlistID _: String) async -> Bool { false }
    func removePlaylist(playlistID _: String) async -> Bool { false }
    func savedSongIDs(trackIDs _: [String]) async -> Set<String> { [] }
    func saveSong(trackID _: String) async -> Bool { false }
    func removeSong(trackID _: String) async -> Bool { false }
    func addTrack(playlistID _: String, trackID _: String) async -> Bool { false }
    func removeTrack(playlistID _: String, trackID _: String) async -> Bool { false }
}
