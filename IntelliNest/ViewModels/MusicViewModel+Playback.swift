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
        let spotifyFavorites = playlists.filter { playlist in
            guard let ownerID = playlist.ownerID else {
                return true
            }
            return !personalAccountIDs.contains(ownerID)
        }
        // MA is the favourite store, so surface any starred playlist the Spotify
        // library doesn't carry yet — MA's 2-way follow sync can lag a fresh star,
        // and without this the playlist shows only in recently-played until the
        // follow propagates and the next `/me/playlists` fetch picks it up. Matched
        // by name since MA favourites are `library://` items while the listing is
        // `spotify://`; deduping against the whole library (not just the favourites)
        // keeps a personal-account favourite in its own section, not Favoriter.
        let spotifyLibraryNames = Set(playlists.map { normalizedName($0.name) })
        let starredOnlyInMA = maFavorites.filter { !spotifyLibraryNames.contains(normalizedName($0.name)) }
        favoritePlaylists = spotifyFavorites + starredOnlyInMA
        // Show the viewer's own section first; the rest keep configured order.
        // Every section is titled by its owner's name (e.g. "Tobias spellistor").
        let viewer = currentUser()
        let orderedAccounts = personalAccounts.filter { $0.user == viewer }
            + personalAccounts.filter { $0.user != viewer }
        personalPlaylistSections = orderedAccounts.compactMap { account in
            let owned = playlists.filter { $0.ownerID == account.userID }
            guard owned.isNotEmpty else {
                return nil
            }
            return PersonalPlaylistSection(account: account, title: account.user.playlistSectionTitle, playlists: owned)
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
            // A "replace" wipes the server queue, so the manual "I kö" tracking from
            // the previous context no longer applies — clear it so leftover ids can't
            // mislabel the new playlist's tracks.
            if enqueue == "replace" {
                clearManualQueueTracking()
            }
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

    // MARK: - Transport & volume

    func togglePlayPause() {
        guard let activeSpeaker, let targetID = playbackTargetID else {
            return
        }
        // Decide from the mirrored state the card actually shows (the hardware
        // twin's when it diverges), so the button does what its icon implies. The
        // command still routes to the Music Assistant group leader.
        let isPlaying = displayedActiveSpeaker?.isPlaying ?? activeSpeaker.isPlaying
        let action: Action = isPlaying ? .mediaPause : .mediaPlay
        speakers[activeSpeaker.entityId]?.state = isPlaying ? "paused" : "playing"
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

    /// Seeks the current track to `seconds`. Optimistically anchors the active
    /// speaker's position to the new spot (so the scrubber and lyrics jump at once)
    /// and routes the command to the group leader; the follow-up reload reconciles
    /// with the real position.
    func seek(to seconds: Double) {
        guard let activeSpeakerID else {
            return
        }
        let clamped = max(seconds, 0)
        speakers[activeSpeakerID]?.mediaPosition = clamped
        speakers[activeSpeakerID]?.mediaPositionUpdatedAt = Date()
        Task {
            // Group membership can change between reloads; refresh before resolving
            // the leader so the seek isn't routed to a stale leader (or a follower
            // that rejects it), matching `startPlayback`.
            await refreshActiveSpeaker(activeSpeakerID)
            guard let targetID = playbackTargetID else {
                return
            }
            restAPIService.seek(entityID: targetID, positionSeconds: clamped)
        }
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
