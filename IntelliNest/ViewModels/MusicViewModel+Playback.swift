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

    /// Loads the favourite and recently-played playlists on the first reload
    /// after the view appears. Failures are logged but left silent — these are a
    /// convenience shortcut, not core playback; a failed load retries next reload.
    func loadLibraryPlaylistsIfNeeded() async {
        guard !hasLoadedLibrary else {
            return
        }
        let favorites = try? await restAPIService.getFavoritePlaylists()
        let recents = try? await restAPIService.getRecentlyPlayedPlaylists()
        guard favorites != nil || recents != nil else {
            return
        }
        hasLoadedLibrary = true
        if let favorites {
            favoritePlaylists = favorites
        }
        if let recents {
            recentlyPlayedPlaylists = recents
        }
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

    func play(item: MusicSearchItem) async {
        if await startPlayback(uri: item.uri, mediaType: item.mediaType, title: item.name, artist: item.artist) {
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
        guard let activeSpeakerID, let targetID = playbackTargetID else {
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
    private func loadPlaylistTracks(_ playlist: MusicSearchItem) async {
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
            closeSearchResults()
            await refreshRecentlyPlayed()
        }
    }

    /// Plays the chosen track now, then queues the rest of the playlist after it,
    /// so the tapped song is followed by the playlist.
    func playTrackInPlaylist(_ track: MusicPlaylistTrack, from playlist: MusicSearchItem) async {
        guard await startPlayback(uri: track.uri, mediaType: .track, title: track.title, artist: nil) else {
            return
        }
        if let targetID = playbackTargetID {
            await restAPIService.playMedia(on: targetID, mediaID: playlist.uri, mediaType: .playlist, enqueue: "add")
        }
        closeSearchResults()
        await refreshRecentlyPlayed()
    }

    /// Dismisses any playlist presentation: the search-results sheet, its
    /// drill-in, and the main-view browse sheet.
    func closeSearchResults() {
        isShowingSearchResults = false
        openedPlaylist = nil
        browsingLibraryPlaylist = nil
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
