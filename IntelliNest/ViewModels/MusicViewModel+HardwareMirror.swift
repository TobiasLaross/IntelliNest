//
//  MusicViewModel+HardwareMirror.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-18.
//

import Foundation

/// Mirroring the controllable Music Assistant speakers against their native Sonos
/// hardware entities, split out of `MusicViewModel` to keep that file under the
/// file-length limit. The MA queue entity freezes on its last track when playback
/// starts outside the app's queue; the hardware twin always reflects what's
/// actually audible, so the now-playing display reads the twin. Control still
/// routes through Music Assistant.
extension MusicViewModel {
    /// The active speaker as it should be shown: the MA entity mirroring its
    /// hardware twin. Drives the now-playing card's track, art, and play/pause
    /// state so they stay honest when playback was started outside the app.
    var displayedActiveSpeaker: MediaPlayerEntity? {
        guard let activeSpeakerID else {
            return nil
        }
        return displayedSpeaker(activeSpeakerID)
    }

    /// A speaker mirrored against its live hardware twin (when one applies).
    /// Returns the MA entity unchanged for an AirPlay room playing on its own, or
    /// when no twin is driving audio.
    func displayedSpeaker(_ speakerID: EntityId) -> MediaPlayerEntity? {
        guard let speaker = speakers[speakerID] else {
            return nil
        }
        return speaker.mirroring(liveTwin(for: speaker))
    }

    /// The hardware twin that reflects what this speaker is actually playing: its
    /// own twin first, then — when it has none playing — a grouped member's twin.
    /// The fallback covers an AirPlay leader synced with a Sonos: the leader has no
    /// twin of its own, but the group's audio is real on the Sonos member, so its
    /// twin is the source of truth. Group members are listed by Music Assistant id,
    /// which is exactly how `hardwareTwins` is keyed.
    private func liveTwin(for speaker: MediaPlayerEntity) -> MediaPlayerEntity? {
        if let own = hardwareTwins[speaker.entityId], own.hasMirrorableNowPlaying {
            return own
        }
        for memberID in speaker.groupMembers where memberID != speaker.entityId {
            if let memberTwin = hardwareTwins[memberID], memberTwin.hasMirrorableNowPlaying {
                return memberTwin
            }
        }
        return nil
    }

    /// Re-fetches the native Sonos entities that back the four Sonos rooms, keyed
    /// by the Music Assistant speaker they belong to. A failed fetch keeps the
    /// last-known twin (matching `reloadSpeakers`) so a transient blip doesn't flip
    /// the room back to the stale MA now-playing; the next loop corrects it.
    func reloadHardwareTwins() async {
        let service = restAPIService
        await withTaskGroup(of: (EntityId, MediaPlayerEntity)?.self) { group in
            for (speakerID, twinID) in Self.hardwareTwinIDs {
                group.addTask {
                    do {
                        let twin = try await service.reload(entityId: twinID, entityType: MediaPlayerEntity.self)
                        return (speakerID, twin)
                    } catch {
                        Log.error("Failed to reload hardware twin: \(twinID): \(error)")
                        return nil
                    }
                }
            }

            for await result in group {
                if let (speakerID, twin) = result {
                    self.hardwareTwins[speakerID] = twin
                }
            }
        }
    }

    /// Clears the "Spelas från <spellista>" breadcrumb once the active speaker's
    /// hardware twin reports a different track than the Music Assistant queue. That
    /// happens when playback was taken over from outside the app — the in-app
    /// playlist the breadcrumb points at is no longer what's playing, so jumping to
    /// it would mislead.
    func dropSourcePlaylistIfDiverged() {
        guard nowPlayingSourcePlaylist != nil,
              let activeSpeakerID,
              let speaker = speakers[activeSpeakerID],
              let twin = liveTwin(for: speaker),
              !twin.isSameTrack(as: speaker) else {
            return
        }
        nowPlayingSourcePlaylist = nil
    }
}
