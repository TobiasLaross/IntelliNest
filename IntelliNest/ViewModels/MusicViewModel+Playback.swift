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
    func refreshSpotifyPlaylists() async {
        guard spotify.isAuthorized else {
            return
        }
        let playlists = await spotify.accountPlaylists()
        guard playlists.isNotEmpty else {
            return
        }
        favoritePlaylists = playlists
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
            await refreshSpotifyPlaylists()
        } catch {
            Log.error("Spotify login failed: \(error)")
            setErrorBannerText("Spotify-inloggning misslyckades", "Kunde inte logga in på Spotify")
        }
    }

    // MARK: - Spotify favourite

    /// Whether to show the favourite star for this playlist. Only true when logged
    /// in (so the star never appears unless tapping it actually saves) and the
    /// playlist resolves to a Spotify id — directly or via the account match.
    /// Built-ins, non-account playlists, and the logged-out state get no star.
    func isSpotifyPlaylist(_ playlist: MusicSearchItem) -> Bool {
        isSpotifyAuthorized && spotifyPlaylistID(for: playlist) != nil
    }

    /// Whether the playlist is currently marked saved (drives the filled star).
    func isSaved(_ playlist: MusicSearchItem) -> Bool {
        savedPlaylistURIs.contains(playlist.uri)
    }

    /// Resolves the Spotify playlist id for a playlist. A `spotify://playlist/<id>`
    /// uri gives it directly. Music Assistant library items instead use opaque
    /// `library://playlist/<n>` uris with no Spotify id, so they're matched by name
    /// against the logged-in account's playlists (Spotify is the source of truth,
    /// and an MA Spotify-library playlist is by definition one of those). Returns
    /// nil for non-Spotify playlists (MA built-ins, or anything not in the account).
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

    /// Reads the live Spotify saved-state when the playlist detail appears, so the
    /// star reflects reality. Skipped (and silent) for non-Spotify playlists or
    /// when the user hasn't logged in yet — the star only loads after first login.
    func loadSavedState(for playlist: MusicSearchItem) async {
        guard let playlistID = spotifyPlaylistID(for: playlist), spotify.isAuthorized else {
            return
        }
        await setSaved(spotify.isPlaylistSaved(playlistID: playlistID), for: playlist)
    }

    /// Toggles whether the playlist is in the user's Spotify library. Triggers the
    /// one-time Spotify login when needed, flips the star optimistically, then
    /// reverts and shows a banner if the request fails.
    func toggleSpotifySaved(_ playlist: MusicSearchItem) async {
        guard let playlistID = spotifyPlaylistID(for: playlist) else {
            return
        }
        if !spotify.isAuthorized {
            do {
                try await spotify.authorize()
                isSpotifyAuthorized = true
            } catch {
                Log.error("Spotify authorization failed: \(error)")
                setErrorBannerText("Spotify-inloggning misslyckades", "Kunde inte logga in på Spotify")
                return
            }
        }

        let wasSaved = isSaved(playlist)
        setSaved(!wasSaved, for: playlist)
        let success = wasSaved
            ? await spotify.removePlaylist(playlistID: playlistID)
            : await spotify.savePlaylist(playlistID: playlistID)
        if success {
            // The account's playlist set just changed — refresh the favourites
            // section so it reflects the save/remove.
            await refreshSpotifyPlaylists()
        } else {
            setSaved(wasSaved, for: playlist)
            setErrorBannerText("Kunde inte uppdatera favorit", "Det gick inte att ändra favoritmarkeringen på Spotify")
        }
    }

    func setSaved(_ saved: Bool, for playlist: MusicSearchItem) {
        if saved {
            savedPlaylistURIs.insert(playlist.uri)
        } else {
            savedPlaylistURIs.remove(playlist.uri)
        }
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
