//
//  MusicViewModel+Playback.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-09.
//

import Foundation

/// Playback, playlist browsing, and the favourite/recently-played library
/// loaders, split out of `MusicViewModel` to keep that type focused on speaker
/// and group state.
extension MusicViewModel {
    // MARK: - Library playlists

    /// Loads the favourites (the Spotify account's playlists) and the
    /// recently-played list (Music Assistant) on reload. Failures are logged but
    /// left silent — these are a convenience shortcut, not core playback; a failed
    /// load retries next reload.
    func loadLibraryPlaylistsIfNeeded() async {
        await loadRecentlyPlayedIfNeeded()
        await loadSpotifyPlaylistsIfNeeded()
    }

    /// Loads the recently-played playlists from Music Assistant once.
    private func loadRecentlyPlayedIfNeeded() async {
        guard !hasLoadedLibrary, let recents = try? await restAPIService.getRecentlyPlayedPlaylists() else {
            return
        }
        hasLoadedLibrary = true
        recentlyPlayedPlaylists = recents
    }

    /// Loads the huset Spotify account's playlists into the favourites section
    /// once the user is logged in. Retries on each reload until it succeeds (so the
    /// list appears the first reload after a login), then latches. An empty result
    /// is treated as "not loaded yet" so a failed fetch doesn't latch on nothing.
    func loadSpotifyPlaylistsIfNeeded() async {
        guard spotify.isAuthorized, !hasLoadedSpotifyPlaylists else {
            return
        }
        await refreshSpotifyPlaylists()
    }

    /// Re-fetches the Spotify account's playlists, bypassing the load latch.
    /// Spotify is the source of truth for the library, so the favourites refresh
    /// each time the music view appears in case the playlists changed elsewhere
    /// (e.g. edited in the Spotify app or on another device). An empty result is
    /// kept off the list rather than clearing it, since `accountPlaylists` also
    /// returns empty on a failed/logged-out fetch.
    /// Re-fetches the huset account's library (`/me/playlists`, all pages) and splits
    /// it: playlists owned by a configured personal account become that person's
    /// section, everything else stays in Favoriter — so nothing shows twice. Spotify
    /// blocks reading another user's playlists for this dev-mode app (403), so the
    /// personal sections are sourced from the playlists the huset account follows,
    /// matched by `ownerID`. An account that owns none of the followed playlists is
    /// dropped (no empty header). When logged out the personal sections are cleared;
    /// favourites are left as-is, since an empty fetch shouldn't blank a loaded list.
    func refreshSpotifyPlaylists() async {
        guard spotify.isAuthorized else {
            personalPlaylistSections = []
            return
        }
        let playlists = await spotify.accountPlaylists()
        guard playlists.isNotEmpty else {
            return
        }
        let personalAccountIDs = Set(personalAccounts.map(\.userID))
        favoritePlaylists = playlists.filter { playlist in
            guard let ownerID = playlist.ownerID else {
                return true
            }
            return !personalAccountIDs.contains(ownerID)
        }
        // Show the viewer's own section first; the rest keep configured order. The
        // viewer's own is titled "Mina spellistor", everyone else's by their name.
        let viewer = currentUser()
        let orderedAccounts = personalAccounts.filter { $0.user == viewer }
            + personalAccounts.filter { $0.user != viewer }
        personalPlaylistSections = orderedAccounts.compactMap { account in
            let owned = playlists.filter { $0.ownerID == account.userID }
            guard owned.isNotEmpty else {
                return nil
            }
            let title = account.user == viewer ? "Mina spellistor" : account.user.playlistSectionTitle
            return PersonalPlaylistSection(account: account, title: title, playlists: owned)
        }
        hasLoadedSpotifyPlaylists = true
        editablePlaylistSpotifyIDs = await spotify.editablePlaylistIDs()
    }

    /// Re-fetches the recently-played list after a playlist launch so the new
    /// play bubbles to the top. Silent on failure.
    private func refreshRecentlyPlayed() async {
        if let recents = try? await restAPIService.getRecentlyPlayedPlaylists() {
            recentlyPlayedPlaylists = recents
        }
    }

    /// Opens a favourite/recents playlist for browsing in its own sheet on the
    /// main view, loading its tracks. The detail's play button starts playback;
    /// opening it never changes what's playing.
    func browseLibraryPlaylist(_ playlist: MusicSearchItem) async {
        browsingLibraryPlaylist = playlist
        await loadPlaylistTracks(playlist)
    }

    // MARK: - Playback

    /// Playback and queue commands must go to the active speaker's group leader;
    /// a synced follower rejects them. Returns the active speaker itself when it
    /// is ungrouped. Volume stays per-speaker, so it is not redirected here.
    private var playbackTargetID: EntityId? {
        guard let activeSpeaker else {
            return activeSpeakerID
        }
        return activeSpeaker.playbackTargetID
    }

    /// Re-fetches the active speaker's state so playback routing reads its
    /// current group membership rather than a value up to one reload cycle
    /// stale. A failed fetch leaves the existing state in place.
    private func refreshActiveSpeaker(_ speakerID: EntityId) async {
        if let fresh = try? await restAPIService.reload(entityId: speakerID, entityType: MediaPlayerEntity.self) {
            speakers[speakerID] = fresh
        }
    }

    func play(item: MusicSearchItem) async {
        if await startPlayback(uri: item.uri, mediaType: item.mediaType, title: item.name, artist: item.artist) {
            // A single search result isn't played from a playlist, so the
            // now-playing card has no playlist to jump to.
            nowPlayingSourcePlaylist = nil
            closeSearchResults()
        }
    }

    /// Starts (or enqueues) playback of a media item on the active speaker's
    /// group leader. Returns whether the request succeeded so callers can chain
    /// follow-up actions and avoid showing a false playing state.
    @discardableResult
    private func startPlayback(uri: String,
                               mediaType: MusicMediaType,
                               title: String?,
                               artist: String?,
                               enqueue: String = "replace") async -> Bool {
        guard let activeSpeakerID else {
            setErrorBannerText("Ingen högtalare vald", "Välj en högtalare innan du spelar musik")
            return false
        }
        // Group membership can change between the 5-second reloads (e.g. the
        // speaker was just ungrouped). Refresh the active speaker before routing
        // so playback isn't sent to a stale group leader it's no longer synced
        // with — which would start the music on the wrong speaker.
        await refreshActiveSpeaker(activeSpeakerID)
        guard let targetID = playbackTargetID else {
            setErrorBannerText("Ingen högtalare vald", "Välj en högtalare innan du spelar musik")
            return false
        }

        let success = await restAPIService.playMedia(on: targetID, mediaID: uri, mediaType: mediaType, enqueue: enqueue)
        if success {
            // Optimistically reflect what we just started; a reload confirms it.
            speakers[activeSpeakerID]?.state = "playing"
            speakers[activeSpeakerID]?.mediaTitle = title
            speakers[activeSpeakerID]?.mediaArtist = artist
            restAPIService.triggerRepeatReload(times: 3)
        } else {
            setErrorBannerText("Kunde inte spela", "Det gick inte att starta uppspelningen")
        }
        return success
    }

    // MARK: - Playlists

    /// Opens a playlist for browsing in the search-results sheet instead of
    /// playing it: records the opened playlist (which drills the sheet into the
    /// detail view) and loads its tracks. Browsing never changes playback.
    func openPlaylist(_ playlist: MusicSearchItem) async {
        openedPlaylist = playlist
        await loadPlaylistTracks(playlist)
    }

    /// Loads a playlist's tracks into `playlistTracks`, toggling the loading
    /// flag. Shared by the search-sheet drill-in and the main-view browse sheet.
    func loadPlaylistTracks(_ playlist: MusicSearchItem) async {
        playlistTracks = []
        isLoadingPlaylist = true
        let browseSpeaker = activeSpeakerID ?? availableSpeakers.first?.entityId
        if let browseSpeaker {
            do {
                playlistTracks = try await restAPIService.browsePlaylistTracks(playlistURI: playlist.uri, on: browseSpeaker)
            } catch {
                Log.error("Failed to browse playlist: \(error)")
                setErrorBannerText("Kunde inte öppna spellistan", "Det gick inte att hämta låtarna")
            }
        }
        isLoadingPlaylist = false
    }

    /// Plays the whole playlist from the start on the active speaker.
    func playPlaylist(_ playlist: MusicSearchItem) async {
        if await startPlayback(uri: playlist.uri, mediaType: .playlist, title: playlist.name, artist: nil) {
            nowPlayingSourcePlaylist = playlist
            closeSearchResults()
            await refreshRecentlyPlayed()
        }
    }

    /// Plays the whole playlist with shuffle turned on. Starts playback first,
    /// then enables shuffle on the group leader so the freshly-loaded queue is
    /// shuffled rather than the previous one.
    func playPlaylistShuffled(_ playlist: MusicSearchItem) async {
        guard await startPlayback(uri: playlist.uri, mediaType: .playlist, title: playlist.name, artist: nil) else {
            return
        }
        nowPlayingSourcePlaylist = playlist
        if let activeSpeaker, let targetID = playbackTargetID {
            speakers[activeSpeaker.entityId]?.shuffle = true
            restAPIService.setShuffle(entityID: targetID, shuffle: true)
        }
        closeSearchResults()
        await refreshRecentlyPlayed()
    }

    /// Plays the chosen track now, then queues the rest of the playlist after it,
    /// so the tapped song is followed by the playlist.
    func playTrackInPlaylist(_ track: MusicPlaylistTrack, from playlist: MusicSearchItem) async {
        guard await startPlayback(uri: track.uri, mediaType: .track, title: track.title, artist: nil) else {
            return
        }
        nowPlayingSourcePlaylist = playlist
        if let targetID = playbackTargetID {
            await restAPIService.playMedia(on: targetID, mediaID: playlist.uri, mediaType: .playlist, enqueue: "add")
        }
        closeSearchResults()
        await refreshRecentlyPlayed()
    }

    /// Opens the playlist the current track is playing from, reusing the main
    /// view's browse sheet. No-op when the source playlist is unknown.
    func openNowPlayingPlaylist() async {
        guard let playlist = nowPlayingSourcePlaylist else {
            return
        }
        await browseLibraryPlaylist(playlist)
    }

    /// Dismisses any playlist presentation: the search-results sheet, its
    /// drill-in, and the main-view browse sheet.
    func closeSearchResults() {
        isShowingSearchResults = false
        openedPlaylist = nil
        browsingLibraryPlaylist = nil
    }

    // MARK: - Spotify login

    /// Runs the Spotify login from the login prompt. On success, marks the session
    /// authorized (hides the warning triangle) and loads the account's playlists
    /// into the favourites section.
    func connectSpotify() async {
        do {
            try await spotify.authorize()
            isSpotifyAuthorized = true
            await refreshFavorites()
        } catch {
            Log.error("Spotify login failed: \(error)")
            setErrorBannerText("Spotify-inloggning misslyckades", "Kunde inte logga in på Spotify")
        }
    }

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

    private func normalizedName(_ name: String) -> String {
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
    /// follow change the 2-way sync propagated.
    func refreshFavorites() async {
        if let favorites = try? await restAPIService.getFavoritePlaylists() {
            maFavorites = favorites
        }
        await refreshSpotifyPlaylists()
    }

    // MARK: - Transport & volume

    func togglePlayPause() {
        guard let activeSpeaker, let targetID = playbackTargetID else {
            return
        }
        let action: Action = activeSpeaker.isPlaying ? .mediaPause : .mediaPlay
        speakers[activeSpeaker.entityId]?.state = activeSpeaker.isPlaying ? "paused" : "playing"
        restAPIService.mediaTransport(entityID: targetID, action: action)
    }

    func nextTrack() {
        guard let targetID = playbackTargetID else {
            return
        }
        restAPIService.mediaTransport(entityID: targetID, action: .mediaNextTrack)
    }

    func previousTrack() {
        guard let targetID = playbackTargetID else {
            return
        }
        restAPIService.mediaTransport(entityID: targetID, action: .mediaPreviousTrack)
    }

    func setVolume(_ volume: Double) {
        guard let activeSpeakerID else {
            return
        }
        setVolume(volume, for: activeSpeakerID)
    }

    /// Sets the volume of a specific speaker. Volume is always per-speaker (never
    /// redirected to a group leader), so any speaker in the list can be adjusted
    /// in place.
    func setVolume(_ volume: Double, for speakerID: EntityId) {
        speakers[speakerID]?.volumeLevel = volume
        restAPIService.setVolume(entityID: speakerID, volume: volume)
    }

    func toggleShuffle() {
        guard let activeSpeaker, let targetID = playbackTargetID else {
            return
        }
        let newValue = !activeSpeaker.shuffle
        speakers[activeSpeaker.entityId]?.shuffle = newValue
        restAPIService.setShuffle(entityID: targetID, shuffle: newValue)
    }

    func toggleRepeat() {
        guard let activeSpeaker, let targetID = playbackTargetID else {
            return
        }
        // Cycle off → all → one → off, matching the Sonos-style three-state control.
        let newMode: MediaRepeatMode = switch activeSpeaker.repeatMode {
        case .off: .all
        case .all: .one
        case .one: .off
        }
        speakers[activeSpeaker.entityId]?.repeatMode = newMode
        restAPIService.setRepeat(entityID: targetID, repeatMode: newMode)
    }
}
