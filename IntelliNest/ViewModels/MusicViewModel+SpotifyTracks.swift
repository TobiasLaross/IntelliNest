//
//  MusicViewModel+SpotifyTracks.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-11.
//

import Foundation

/// Song-level Spotify actions: liking/unliking tracks and adding/removing them
/// from the account's editable playlists. Spotify is the source of truth for all
/// of these; Music Assistant only plays the result. A track is actionable only
/// when it resolves to a `spotify://track/<id>` uri — Music Assistant items from
/// other providers expose no Spotify id, so their controls are hidden.
extension MusicViewModel {
    // MARK: - Liked Songs

    /// Whether to show the song-favourite star for `uri`: logged in and the track
    /// resolves to a Spotify id (so tapping it can actually like the song).
    func canFavoriteSong(uri: String?) -> Bool {
        guard let uri else {
            return false
        }
        return isSpotifyAuthorized && spotifyTrackID(from: uri) != nil
    }

    /// Whether the track is currently in the user's Liked Songs (drives the star).
    func isSongSaved(uri: String) -> Bool {
        savedSongURIs.contains(uri)
    }

    /// Loads the live Liked-Songs state for the resolvable tracks among `uris`, so
    /// each star reflects reality when its view appears. Silent for non-Spotify
    /// tracks or while logged out.
    func loadSavedSongStates(uris: [String]) async {
        guard spotify.isAuthorized else {
            return
        }
        let resolvable = uris.filter { spotifyTrackID(from: $0) != nil }
        let trackIDs = resolvable.compactMap { spotifyTrackID(from: $0) }
        guard trackIDs.isNotEmpty else {
            return
        }
        let savedIDs = await spotify.savedSongIDs(trackIDs: trackIDs)
        for uri in resolvable {
            guard let trackID = spotifyTrackID(from: uri) else {
                continue
            }
            setSongSaved(savedIDs.contains(trackID), uri: uri)
        }
    }

    /// Toggles whether the track is in the user's Liked Songs. Logs in first when
    /// needed, flips the star optimistically, then reverts and banners on failure.
    func toggleSongSaved(uri: String) async {
        guard let trackID = spotifyTrackID(from: uri) else {
            return
        }
        guard await ensureSpotifyAuthorized() else {
            return
        }
        let wasSaved = isSongSaved(uri: uri)
        setSongSaved(!wasSaved, uri: uri)
        let success = wasSaved
            ? await spotify.removeSong(trackID: trackID)
            : await spotify.saveSong(trackID: trackID)
        if !success {
            setSongSaved(wasSaved, uri: uri)
            setErrorBannerText("Kunde inte uppdatera favorit", "Det gick inte att ändra favoritmarkeringen på Spotify")
        }
    }

    private func setSongSaved(_ saved: Bool, uri: String) {
        if saved {
            savedSongURIs.insert(uri)
        } else {
            savedSongURIs.remove(uri)
        }
    }

    // MARK: - Library row saved-state

    /// Changes whenever the library lists change, so the view can reload the
    /// row stars' saved-state without polling.
    var librarySavedStateSignature: String {
        (recentlyPlayedPlaylists.map(\.uri) + favoritePlaylists.map(\.uri)).joined(separator: "|")
    }

    /// Populates the saved-state for the library rows. Favourites are in the
    /// Spotify library by definition, so they are marked saved without a call;
    /// recently-played playlists are queried so their star reflects reality.
    func loadLibrarySavedStates() async {
        for playlist in favoritePlaylists {
            setSaved(true, for: playlist)
        }
        for playlist in recentlyPlayedPlaylists {
            await loadSavedState(for: playlist)
        }
    }

    // MARK: - Playlist membership

    /// The account playlists the user may add tracks to (owned or collaborative).
    var editableAccountPlaylists: [MusicSearchItem] {
        favoritePlaylists.filter { playlist in
            guard let id = spotifyPlaylistID(for: playlist) else {
                return false
            }
            return editablePlaylistSpotifyIDs.contains(id)
        }
    }

    /// Whether the "Lägg till i spellista" action should be offered for `uri`:
    /// logged in, the track resolves to a Spotify id, and there is at least one
    /// editable playlist to add it to.
    func canAddTrackToPlaylist(uri: String?) -> Bool {
        guard let uri else {
            return false
        }
        return isSpotifyAuthorized && spotifyTrackID(from: uri) != nil && editableAccountPlaylists.isNotEmpty
    }

    /// Whether the "Ta bort från spellistan" action should be offered: the
    /// playlist is one the user can edit on Spotify.
    func canEditPlaylist(_ playlist: MusicSearchItem) -> Bool {
        guard isSpotifyAuthorized, let id = spotifyPlaylistID(for: playlist) else {
            return false
        }
        return editablePlaylistSpotifyIDs.contains(id)
    }

    /// Adds the track to the chosen playlist via Spotify. Banners on failure and
    /// leaves the playlist unchanged. When the target is the playlist currently
    /// open, its track list is refreshed so the addition shows.
    func addTrack(uri: String, toPlaylist playlist: MusicSearchItem) async {
        guard let trackID = spotifyTrackID(from: uri), let playlistID = spotifyPlaylistID(for: playlist) else {
            return
        }
        guard await ensureSpotifyAuthorized() else {
            return
        }
        let success = await spotify.addTrack(playlistID: playlistID, trackID: trackID)
        guard success else {
            setErrorBannerText("Kunde inte lägga till i spellistan", "Det gick inte att lägga till låten på Spotify")
            return
        }
        if let openPlaylist = currentlyOpenPlaylist, spotifyPlaylistID(for: openPlaylist) == playlistID {
            await loadPlaylistTracks(openPlaylist)
        }
    }

    /// Removes the track from the playlist via Spotify. Optimistically drops it
    /// from the visible track list, reverting and bannering on failure.
    func removeTrack(_ track: MusicPlaylistTrack, fromPlaylist playlist: MusicSearchItem) async {
        guard let trackID = spotifyTrackID(from: track.uri), let playlistID = spotifyPlaylistID(for: playlist) else {
            return
        }
        guard await ensureSpotifyAuthorized() else {
            return
        }
        let previousTracks = playlistTracks
        playlistTracks.removeAll { $0.uri == track.uri }
        let success = await spotify.removeTrack(playlistID: playlistID, trackID: trackID)
        if !success {
            playlistTracks = previousTracks
            setErrorBannerText("Kunde inte ta bort låten", "Det gick inte att ta bort låten från spellistan")
        }
    }

    // MARK: - Helpers

    /// Logs in to Spotify when needed so a control tapped while logged out still
    /// completes after login. Returns whether the session is authorized. Banners
    /// and returns false when login fails or is cancelled.
    func ensureSpotifyAuthorized() async -> Bool {
        if spotify.isAuthorized {
            return true
        }
        do {
            try await spotify.authorize()
            isSpotifyAuthorized = true
            return true
        } catch {
            Log.error("Spotify authorization failed: \(error)")
            setErrorBannerText("Spotify-inloggning misslyckades", "Kunde inte logga in på Spotify")
            return false
        }
    }

    /// The playlist whose detail is currently on screen (the search drill-in or
    /// the main-view browse sheet), used to refresh after an add.
    private var currentlyOpenPlaylist: MusicSearchItem? {
        browsingLibraryPlaylist ?? openedPlaylist
    }

    func spotifyTrackID(from uri: String) -> String? {
        let prefix = "spotify://track/"
        guard uri.hasPrefix(prefix) else {
            return nil
        }
        let trackID = String(uri.dropFirst(prefix.count))
        return trackID.isNotEmpty ? trackID : nil
    }
}
