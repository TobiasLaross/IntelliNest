//
//  SpotifyPlaylistService.swift
//  IntelliNest
//
//  Created by Tobias on 2026-09-20.
//

import Foundation

/// A known personal Spotify account whose public playlists are surfaced in the
/// music view as its own titled section. Baked into the app (no in-app management);
/// add another account by appending to `SpotifyPersonalAccount.configured`.
struct SpotifyPersonalAccount: Identifiable, Equatable {
    /// The Spotify user id that owns these playlists in the huset library.
    let userID: String
    /// The app user this account belongs to — drives the section title (the
    /// owner's name, e.g. "Tobias spellistor") and ordering (the viewer's own
    /// section is shown first).
    let user: User

    var id: String { userID }

    /// The configured personal accounts. The viewer's own is surfaced first at
    /// render time; this is just the known set.
    static let configured: [SpotifyPersonalAccount] = [
        SpotifyPersonalAccount(userID: "tobiasc91", user: .tobias),
        SpotifyPersonalAccount(userID: "mbostroem", user: .sarah)
    ]

    /// A read-only login per configured account whose build carries a refresh
    /// token, keyed by Spotify user id. An account without one is left out and
    /// falls back to its public profile.
    @MainActor
    static func configuredTokenProviders() -> [String: SpotifyTokenProviding] {
        var providers: [String: SpotifyTokenProviding] = [:]
        for account in configured {
            let provider = SpotifyRefreshTokenProvider(refreshToken: GlobalConstants.spotifyRefreshToken(for: account.user))
            if provider.isAuthorized {
                providers[account.userID] = provider
            }
        }
        return providers
    }
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
    /// The playlists in the signed-in account's library (owned + followed), across
    /// all pages. Each item carries its `ownerID` so the library can be split into
    /// per-person sections.
    func accountPlaylists() async -> [MusicSearchItem]
    /// `userID`'s playlists, read independently of the signed-in huset library so a
    /// personal playlist huset doesn't follow is still findable. With that person's
    /// own read-only login this is their whole library — private and followed
    /// playlists included; without one it is only the public ones on their profile.
    /// Returns empty when Spotify refuses the read, so callers fall back to the
    /// library-derived listing instead of showing an error.
    func personalPlaylists(ofUser userID: String) async -> [MusicSearchItem]
    /// The Spotify ids of the playlists the user can edit (owned or collaborative).
    /// Used to gate the add-to-playlist picker and the remove-from-playlist action.
    func editablePlaylistIDs() async -> Set<String>
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

/// Stand-in used when no Spotify client is configured (SwiftUI previews, tests
/// that don't exercise Spotify). Reports unauthorized and no-ops every call, so
/// the star never appears and the favourites section stays empty.
@MainActor
struct DisabledSpotifyPlaylistService: SpotifyPlaylistService {
    var isAuthorized: Bool { false }
    func authorize() async throws {}
    func accountPlaylists() async -> [MusicSearchItem] { [] }
    func personalPlaylists(ofUser _: String) async -> [MusicSearchItem] { [] }
    func editablePlaylistIDs() async -> Set<String> { [] }
    func isPlaylistSaved(playlistID _: String) async -> Bool { false }
    func savePlaylist(playlistID _: String) async -> Bool { false }
    func removePlaylist(playlistID _: String) async -> Bool { false }
    func savedSongIDs(trackIDs _: [String]) async -> Set<String> { [] }
    func saveSong(trackID _: String) async -> Bool { false }
    func removeSong(trackID _: String) async -> Bool { false }
    func addTrack(playlistID _: String, trackID _: String) async -> Bool { false }
    func removeTrack(playlistID _: String, trackID _: String) async -> Bool { false }
}
