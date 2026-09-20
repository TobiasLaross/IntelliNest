//
//  SpotifyApiService.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-11.
//

import Foundation

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
        await fetchAllLibraryPlaylistItems().compactMap(\.searchItem)
    }

    /// Reads `/users/<id>/playlists`, which lists that person's public playlists
    /// without needing their login. The huset token is enough, so a playlist Tobias
    /// or Sarah made but huset never followed still reaches the music view. A
    /// refusal (Spotify has historically 403'd this for a development-mode app)
    /// logs and returns empty, leaving the library-derived sections untouched.
    func publicPlaylists(ofUser userID: String) async -> [MusicSearchItem] {
        await fetchAllPlaylistItems(path: "/users/\(userID)/playlists", label: "publicPlaylists(\(userID))")
            .compactMap(\.searchItem)
    }

    private func fetchAllLibraryPlaylistItems() async -> [SpotifyPlaylistItem] {
        await fetchAllPlaylistItems(path: "/me/playlists", label: "accountPlaylists")
    }

    /// Fetches every page of a playlist listing endpoint. Spotify caps a page at 50,
    /// so we walk the `offset` until a short page ends it — the huset library plus
    /// the followed personal-account playlists easily exceeds 50, and a single page
    /// would silently truncate them. `maxPages` guards against an unbounded loop. A
    /// page fetch that fails stops paging and returns what we have.
    private func fetchAllPlaylistItems(path: String, label: String) async -> [SpotifyPlaylistItem] {
        let pageSize = 50
        let maxPages = 10
        var items: [SpotifyPlaylistItem] = []
        for page in 0 ..< maxPages {
            do {
                let request = try await authorizedRequest(
                    path: path,
                    method: "GET",
                    queryItems: [URLQueryItem(name: "limit", value: "\(pageSize)"),
                                 URLQueryItem(name: "offset", value: "\(page * pageSize)")]
                )
                let (data, response) = try await session.data(for: request)
                guard isSuccess(response) else {
                    Log.error("Spotify \(label) failed: \(httpFailureDescription(response, data))")
                    break
                }
                let decoded = try JSONDecoder().decode(SpotifyPlaylistPage.self, from: data)
                items.append(contentsOf: decoded.items.compactMap { $0 })
                if decoded.items.count < pageSize {
                    break
                }
            } catch {
                Log.error("Spotify \(label) failed: \(error)")
                break
            }
        }
        return items
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
        guard let userID = try? await currentUserID() else {
            return []
        }
        return await Set(fetchAllLibraryPlaylistItems().compactMap { $0.editableID(currentUserID: userID) })
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

    /// A compact "HTTP <code>: <body>" description for a failed response, used to
    /// surface *why* a request was rejected. The body is Spotify's JSON error
    /// envelope (e.g. `{"error":{"status":403,"message":"…"}}`); it's truncated so
    /// a forwarded log line stays short. Callers swallow non-2xx responses and
    /// return empty, so without this the failure would be invisible.
    private func httpFailureDescription(_ response: URLResponse, _ data: Data) -> String {
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        let body = bodySnippet(data)
        return body.isEmpty ? "HTTP \(status)" : "HTTP \(status): \(body)"
    }

    /// The leading slice of a response body, for diagnostic log lines.
    private func bodySnippet(_ data: Data) -> String {
        let text = String(bytes: data.prefix(300), encoding: .utf8) ?? ""
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
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
                               artist: owner?.displayName,
                               ownerID: owner?.id)
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
