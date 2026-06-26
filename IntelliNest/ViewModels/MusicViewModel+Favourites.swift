//
//  MusicViewModel+Favourites.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-13.
//

import Foundation

/// Music Assistant favourite (star) handling for playlists, split out of
/// `MusicViewModel+Playback` to keep that file under the file-length limit.
extension MusicViewModel {
    // MARK: - Favourites (Music Assistant)

    /// Whether to show the favourite star: any playlist can be favourited in MA
    /// (and MA's Spotify 2-way sync mirrors it to the follow). Spotify writes are
    /// blocked for this dev-mode app, so the star goes through MA, not Spotify.
    func canFavoritePlaylist(_ playlist: MusicSearchItem) -> Bool {
        playlist.mediaType == .playlist
    }

    /// Whether the playlist is currently favourited in Music Assistant. MA
    /// favourites are `library://` items while the listing is `spotify://`, so
    /// they are matched by normalized name.
    func isSaved(_ playlist: MusicSearchItem) -> Bool {
        maFavoriteNames.contains(normalizedName(playlist.name))
    }

    var maFavoriteNames: Set<String> {
        Set(maFavorites.map { normalizedName($0.name) })
    }

    /// Resolves the Spotify playlist id for a playlist (used by the add-to-playlist
    /// feature). A `spotify://playlist/<id>` uri gives it directly; a `library://`
    /// item is matched by name against the account's playlists.
    func spotifyPlaylistID(for playlist: MusicSearchItem) -> String? {
        if let id = directSpotifyPlaylistID(from: playlist.uri) {
            return id
        }
        let name = normalizedName(playlist.name)
        let match = favoritePlaylists.first { normalizedName($0.name) == name }
        return match.flatMap { directSpotifyPlaylistID(from: $0.uri) }
    }

    private func directSpotifyPlaylistID(from uri: String) -> String? {
        let prefix = "spotify://playlist/"
        guard uri.hasPrefix(prefix) else {
            return nil
        }
        let id = String(uri.dropFirst(prefix.count))
        return id.isNotEmpty ? id : nil
    }

    /// Lowercased, trimmed playlist name used to match across sources: MA
    /// favourites are `library://` items while the Spotify listing is `spotify://`,
    /// so they can only be reconciled by name. Internal so the playlist loader can
    /// dedupe the favourites union against the Spotify library.
    func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// The Music Assistant library id from a `library://playlist/<id>` uri, needed
    /// to unfavourite over the socket.
    private func libraryPlaylistID(from uri: String) -> String? {
        let prefix = "library://playlist/"
        guard uri.hasPrefix(prefix) else {
            return nil
        }
        let id = String(uri.dropFirst(prefix.count))
        return id.isNotEmpty ? id : nil
    }

    /// Ensures the MA favourites are loaded so the star reflects reality when a
    /// playlist detail opens straight from a search result.
    func loadSavedState(for _: MusicSearchItem) async {
        if maFavorites.isEmpty {
            await refreshFavorites()
        }
    }

    /// Toggles the playlist's Music Assistant favourite. MA's Spotify 2-way sync
    /// then follows/unfollows it on Spotify, and the next listing reload reflects
    /// it. Flips the star optimistically; reverts and banners on failure.
    func toggleFavorite(_ playlist: MusicSearchItem) async {
        let wasSaved = isSaved(playlist)
        // Capture the unfavourite target's library id before the optimistic flip
        // removes it from `maFavorites`.
        let removalID = wasSaved ? maLibraryID(matching: playlist) : nil
        setFavoriteOptimistically(!wasSaved, playlist: playlist)
        let success: Bool = if wasSaved {
            if let removalID {
                await queueSocket.removeFavorite(mediaType: "playlist", libraryItemID: removalID)
            } else {
                false
            }
        } else {
            await queueSocket.addFavorite(uri: playlist.uri)
        }
        if success {
            await refreshFavorites()
        } else {
            setFavoriteOptimistically(wasSaved, playlist: playlist)
            setErrorBannerText("Kunde inte uppdatera favorit", "Det gick inte att ändra favoritmarkeringen")
        }
    }

    /// The MA library id for the favourite matching `playlist` by name, or nil if
    /// no matching favourite is loaded.
    private func maLibraryID(matching playlist: MusicSearchItem) -> String? {
        let name = normalizedName(playlist.name)
        guard let item = maFavorites.first(where: { normalizedName($0.name) == name }) else {
            return nil
        }
        return libraryPlaylistID(from: item.uri)
    }

    /// Optimistically flips the favourite-name membership so the star updates
    /// before the socket round-trip completes.
    private func setFavoriteOptimistically(_ favorite: Bool, playlist: MusicSearchItem) {
        let name = normalizedName(playlist.name)
        if favorite {
            if !maFavorites.contains(where: { normalizedName($0.name) == name }) {
                maFavorites.append(playlist)
            }
        } else {
            maFavorites.removeAll { normalizedName($0.name) == name }
        }
    }

    /// Re-fetches the MA favourites (drives the star state and the unfavourite id
    /// lookup), then the Spotify listing so the per-owner sections reflect any
    /// follow change the 2-way sync propagated, then stars any Spotify-library
    /// playlist that isn't already an MA favourite.
    func refreshFavorites() async {
        var maFavoritesLoaded = false
        if let favorites = try? await restAPIService.getFavoritePlaylists() {
            maFavorites = favorites
            maFavoritesLoaded = true
        }
        await refreshSpotifyPlaylists()
        // Only sync once both sides are actually loaded — otherwise an empty MA
        // fetch would make every Spotify playlist look unfavourited and re-add it.
        if maFavoritesLoaded {
            await syncSpotifyLibraryToMAFavorites()
        }
    }

    /// Auto-favourites in Music Assistant every playlist in the huset Spotify
    /// library that isn't already an MA favourite, so a playlist saved on Spotify
    /// shows a filled star without a manual tap. MA's own 2-way sync is meant to
    /// keep these aligned but doesn't always; this closes the gap. One-way and
    /// additive — it never removes a favourite, so a deliberate unstar isn't undone
    /// — and runs once per session so it can't fight a manual toggle. Best-effort:
    /// per-item failures are ignored.
    func syncSpotifyLibraryToMAFavorites() async {
        guard spotify.isAuthorized, !hasSyncedSpotifyFavorites else {
            return
        }
        let libraryPlaylists = favoritePlaylists + personalPlaylistSections.flatMap(\.playlists)
        guard libraryPlaylists.isNotEmpty else {
            // Spotify side not loaded yet — leave the latch open so a later refresh
            // retries once the library is available.
            return
        }
        hasSyncedSpotifyFavorites = true
        let alreadyFavorited = maFavoriteNames
        let toFavorite = libraryPlaylists.filter { !alreadyFavorited.contains(normalizedName($0.name)) }
        guard toFavorite.isNotEmpty else {
            return
        }
        var didAddAny = false
        for playlist in toFavorite {
            let added = await queueSocket.addFavorite(uri: playlist.uri)
            didAddAny = didAddAny || added
        }
        // Reload the favourites so the freshly-starred playlists fill their stars.
        if didAddAny, let favorites = try? await restAPIService.getFavoritePlaylists() {
            maFavorites = favorites
        }
    }
}
