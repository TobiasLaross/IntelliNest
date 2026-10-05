//
//  MusicViewModel+Rooms.swift
//  IntelliNest
//
//  Created by Tobias on 2026-10-05.
//

import Foundation

/// Several rooms playing different things at once: which rooms the mini player
/// pages between, what each room is playing from, and play/pause for a room that
/// isn't the one being controlled. Playback commands always target the active
/// speaker, so picking a room only moves control — the other rooms keep playing.
extension MusicViewModel {
    /// How many playlists the start screen's shortcut grid shows.
    static let shortcutCount = 6

    /// The playlist the controlled room is playing from, when it was started from a
    /// playlist in the app this session. Drives the player's "Spelas från" jump and
    /// leads "Senast spelade". Nil when the source is unknown (started elsewhere, a
    /// single track, or after relaunch). Setting it records it against the active
    /// room's group leader, which is what `sourcePlaylist(for:)` reads first;
    /// clearing it clears the whole group so no member keeps a stale source.
    /// Other rooms are left alone.
    var nowPlayingSourcePlaylist: MusicSearchItem? {
        get { sourcePlaylist(for: activeSpeakerID) }
        set {
            guard let activeSpeakerID, let speaker = speakers[activeSpeakerID] else {
                return
            }
            var sources = sourcePlaylistsBySpeaker
            if let newValue {
                sources[speaker.playbackTargetID] = newValue
            } else {
                for memberID in [speaker.playbackTargetID, activeSpeakerID] + speaker.groupMembers {
                    sources[memberID] = nil
                }
            }
            // One assignment, so "Senast spelade" is rebuilt once.
            sourcePlaylistsBySpeaker = sources
        }
    }

    /// What a room is playing from. A grouped room plays its leader's stream, so the
    /// leader's source wins over one the room kept from before it joined; the room's
    /// own entry and then any other member's cover a source recorded while a
    /// follower was the one being controlled.
    func sourcePlaylist(for speakerID: EntityId?) -> MusicSearchItem? {
        guard let speakerID, let speaker = speakers[speakerID] else {
            return nil
        }
        let candidates = [speaker.playbackTargetID, speakerID] + speaker.groupMembers
        return candidates.lazy.compactMap { self.sourcePlaylistsBySpeaker[$0] }.first
    }

    /// The rooms the mini player pages between, in display order: every room (or
    /// group) with something playing, plus the one being controlled even when it is
    /// quiet, so the bar never loses the room the user picked.
    var miniPlayerRooms: [SpeakerPickerEntry] {
        speakerPickerEntries.filter { entry in
            entry.contains(activeSpeakerID) || entry.members.contains(where: \.isPlaying)
        }
    }

    /// The room being controlled, as the player's room pill names it: the
    /// controlled speaker first, then the rest of its group ("Köket + Gästrummet").
    var controlledRoomTitle: String {
        guard let activeSpeaker else {
            return "Välj rum"
        }
        let others = groupedSpeakers.filter { $0.entityId != activeSpeaker.entityId }
        return ([activeSpeaker] + others).map(\.friendlyName).joined(separator: " + ")
    }

    /// The speaker to show and command for a room card: the controlled speaker when
    /// it is in that room, otherwise the room's group leader.
    func controlledSpeakerID(in entry: SpeakerPickerEntry) -> EntityId {
        if let activeSpeakerID, entry.contains(activeSpeakerID) {
            return activeSpeakerID
        }
        return entry.leader.entityId
    }

    /// Moves control to a room without touching what any room is playing. No-op for
    /// the room already in control, so a grouped follower stays selected.
    func selectRoom(_ entry: SpeakerPickerEntry) {
        guard !entry.contains(activeSpeakerID) else {
            return
        }
        selectSpeaker(entry.leader.entityId)
    }

    /// Play/pause for any room, so a room card can pause the kitchen while the
    /// bedroom is the one being controlled. The controlled room goes through
    /// `togglePlayPause()`, which also holds the scrubber position.
    func togglePlayPause(for speakerID: EntityId) {
        guard speakerID != activeSpeakerID else {
            togglePlayPause()
            return
        }
        guard let shown = displayedSpeaker(speakerID), let targetID = transportTargetID(for: speakerID) else {
            return
        }
        let isPlaying = shown.isPlaying
        speakers[speakerID]?.state = isPlaying ? "paused" : "playing"
        restAPIService.mediaTransport(entityID: targetID, action: isPlaying ? .mediaPause : .mediaPlay)
        restAPIService.triggerRepeatReload(times: 3)
    }

    /// The shortcut grid at the top of the start screen: the most recently played
    /// playlists, which is what people reach for again.
    var shortcutPlaylists: [MusicSearchItem] {
        Array(recentlyPlayedPlaylists.prefix(Self.shortcutCount))
    }

    /// The full "Senast spelade" section, opened from the shortcut grid's "Visa alla".
    var recentlyPlayedSection: MusicLibrarySection? {
        allLibrarySections.first { $0.id == Self.recentlyPlayedSectionID }
    }

    /// The library cards under the shortcut grid. "Senast spelade" is left out
    /// because the grid already shows it.
    var homeLibrarySections: [MusicLibrarySection] {
        allLibrarySections.filter { $0.id != Self.recentlyPlayedSectionID }
    }
}

extension MediaPlayerEntity {
    /// One line saying what a room is doing, for its card in the room sheet:
    /// the track while playing, "Pausad" with the track while paused, and "Annan
    /// app" when the sound comes from AirPlay, Spotify Connect or the TV, which the
    /// app can see but not control through Music Assistant.
    var roomStatusText: String {
        let track = [mediaTitle, mediaArtist].compactMap { $0?.isNotEmpty == true ? $0 : nil }.joined(separator: " · ")
        if isPlayingExternalSource {
            return track.isEmpty ? "Annan app" : "Annan app · \(track)"
        }
        if isPlaying {
            return track.isEmpty ? "Spelar" : track
        }
        if state == "paused" {
            return track.isEmpty ? "Pausad" : "Pausad · \(track)"
        }
        return "Tyst"
    }
}
