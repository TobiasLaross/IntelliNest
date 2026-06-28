//
//  MusicViewModel+Transport.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-28.
//

import Foundation

/// Transport (play/pause, skip, seek), volume, shuffle, and repeat controls for the
/// active speaker, split out of `MusicViewModel+Playback` to keep each file focused
/// and under the line-length limit.
extension MusicViewModel {
    func togglePlayPause() {
        guard let activeSpeaker, let targetID = playbackTargetID else {
            return
        }
        // Decide from the mirrored state the card actually shows (the hardware
        // twin's when it diverges), so the button does what its icon implies. The
        // command still routes to the Music Assistant group leader.
        let isPlaying = displayedActiveSpeaker?.isPlaying ?? activeSpeaker.isPlaying
        let action: Action = isPlaying ? .mediaPause : .mediaPlay
        if isPlaying {
            // Pausing: pin the scrubber to the live position. A pausing player can
            // briefly report no position (or 0) while it transitions, which would
            // snap the scrubber to 0; hold the frozen spot until HA reports it back.
            // Read the elapsed time before flipping the state, while it still extrapolates.
            let now = Date()
            let frozen = (displayedActiveSpeaker ?? activeSpeaker).currentElapsed(asOf: now) ?? 0
            speakers[activeSpeaker.entityId]?.mediaPosition = frozen
            speakers[activeSpeaker.entityId]?.mediaPositionUpdatedAt = now
            positionHold = PlaybackPositionHold(target: frozen, since: now)
        } else {
            // Resuming: drop any hold so the live position advances freely again.
            positionHold = nil
        }
        speakers[activeSpeaker.entityId]?.state = isPlaying ? "paused" : "playing"
        restAPIService.mediaTransport(entityID: targetID, action: action)
        // Confirm the new state/position quickly so the hold releases promptly.
        restAPIService.triggerRepeatReload(times: 3)
    }

    func nextTrack() {
        guard let targetID = playbackTargetID else {
            return
        }
        // A new track resets position, so a seek/pause hold no longer applies.
        positionHold = nil
        restAPIService.mediaTransport(entityID: targetID, action: .mediaNextTrack)
    }

    func previousTrack() {
        guard let targetID = playbackTargetID else {
            return
        }
        positionHold = nil
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
        let now = Date()
        let clamped = max(seconds, 0)
        speakers[activeSpeakerID]?.mediaPosition = clamped
        speakers[activeSpeakerID]?.mediaPositionUpdatedAt = now
        // Hold the new spot through the next reloads: HA keeps reporting the pre-seek
        // position for a cycle or two, which would otherwise snap the scrubber back.
        positionHold = PlaybackPositionHold(target: clamped, since: now)
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
        // Pull the confirmed position in quickly so the hold releases without waiting
        // for the full 5-second loop.
        restAPIService.triggerRepeatReload(times: 3)
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
