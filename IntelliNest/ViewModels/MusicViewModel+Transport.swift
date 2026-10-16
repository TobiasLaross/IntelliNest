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
    /// How many times a play/pause is sent before giving up, and how many
    /// one-second rechecks each send gets to show up in Home Assistant.
    static let playbackAttempts = 3
    static let playbackRechecks = 3

    func togglePlayPause() {
        guard let activeSpeaker, let targetID = transportTargetID,
              !pendingPlaybackSpeakers.contains(activeSpeaker.entityId) else {
            return
        }
        // Decide from the mirrored state the card actually shows (the hardware
        // twin's when it diverges), so the button does what its icon implies.
        let isPlaying = displayedActiveSpeaker?.isPlaying ?? activeSpeaker.isPlaying
        applyOptimisticPlayback(pausing: isPlaying)
        sendConfirmedPlayback(speakerID: activeSpeaker.entityId, targetID: targetID, pausing: isPlaying)
    }

    /// Sends play/pause and keeps the speaker pending until Home Assistant reports
    /// the new state. Music Assistant can take several seconds to start a group
    /// from idle, and sometimes drops the first `media_play` altogether, so the
    /// command is re-sent when the state hasn't moved after a few rechecks.
    func sendConfirmedPlayback(speakerID: EntityId, targetID: EntityId, pausing: Bool) {
        pendingPlaybackSpeakers.insert(speakerID)
        let action: Action = pausing ? .mediaPause : .mediaPlay
        pendingPlaybackTasks[speakerID] = Task {
            var landed = false
            attempts: for _ in 1 ... Self.playbackAttempts {
                // Sent from its own task so a force pause's cancel can't abort the POST
                // mid-flight, which the service would then retry on the external URL.
                let send = Task {
                    _ = await restAPIService.setState(for: targetID, in: .mediaPlayer, using: action, reloadTimes: 0)
                }
                playbackSendTasks[speakerID] = send
                await send.value
                for _ in 1 ... Self.playbackRechecks {
                    await waitBeforePlaybackRecheck()
                    // A force pause took over; it owns the speaker's state now, so
                    // neither re-send nor clear a newer request's spinner.
                    if Task.isCancelled {
                        return
                    }
                    let hasLanded = await hasPlaybackLanded(on: targetID, playing: !pausing)
                    if Task.isCancelled {
                        return
                    }
                    if hasLanded {
                        landed = true
                        break attempts
                    }
                }
            }
            pendingPlaybackSpeakers.remove(speakerID)
            await reloadSpeakers()
            if !landed {
                setErrorBannerText(pausing ? "Kunde inte pausa" : "Kunde inte spela", "Högtalaren svarade inte")
            }
        }
    }

    private func hasPlaybackLanded(on targetID: EntityId, playing: Bool) async -> Bool {
        let fresh = try? await restAPIService.reload(entityId: targetID, entityType: MediaPlayerEntity.self)
        return fresh?.isPlaying == playing
    }

    /// Applies the optimistic play/pause and position to a freshly reloaded
    /// speaker, so neither flips back before Home Assistant has caught up.
    func reconcileOptimisticState(speakerID: EntityId, fresh: MediaPlayerEntity) -> MediaPlayerEntity {
        var entity = reconcilePositionHold(speakerID: speakerID, fresh: fresh)
        if pendingPlaybackSpeakers.contains(speakerID), let requestedState = speakers[speakerID]?.state {
            entity.state = requestedState
        }
        return entity
    }

    /// Pauses regardless of what the card shows, for when Music Assistant and the
    /// Sonos disagree about whether anything is playing. The pause goes to every
    /// entity that could own the stream — the MA leader and the Sonos twins behind
    /// it — since there's no telling which one is right.
    func forcePause() {
        guard let activeSpeakerID, activeSpeaker != nil else {
            return
        }
        // Stop a play/pause still being retried, or it would undo this pause.
        pendingPlaybackTasks[activeSpeakerID]?.cancel()
        pendingPlaybackSpeakers.remove(activeSpeakerID)
        let candidateIDs = [playbackTargetID, transportTargetID].compactMap { $0 }
        let twinIDs = candidateIDs.compactMap { Self.hardwareTwinIDs[$0] }
        var targetIDs: [EntityId] = []
        for entityID in candidateIDs + twinIDs where !targetIDs.contains(entityID) {
            targetIDs.append(entityID)
        }
        applyOptimisticPlayback(pausing: true)
        // A play still in flight could reach Home Assistant after this pause and
        // restart the music, so the pause waits it out.
        guard let inFlightSend = playbackSendTasks[activeSpeakerID] else {
            restAPIService.mediaTransport(entityIDs: targetIDs, action: .mediaPause)
            return
        }
        pendingPlaybackTasks[activeSpeakerID] = Task {
            await inFlightSend.value
            restAPIService.mediaTransport(entityIDs: targetIDs, action: .mediaPause)
        }
    }

    /// Flips the active speaker's state at once so the button doesn't wait a reload
    /// cycle. Pausing pins the scrubber to the live position: a pausing player can
    /// briefly report no position (or 0) while it transitions, which would snap the
    /// scrubber to 0, so the frozen spot is held until HA reports it back.
    private func applyOptimisticPlayback(pausing: Bool) {
        guard let activeSpeaker else {
            return
        }
        if pausing {
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
        speakers[activeSpeaker.entityId]?.state = pausing ? "paused" : "playing"
    }

    func nextTrack() {
        guard let targetID = transportTargetID else {
            return
        }
        // A new track resets position, so a seek/pause hold no longer applies.
        positionHold = nil
        restAPIService.mediaTransport(entityID: targetID, action: .mediaNextTrack)
    }

    func previousTrack() {
        guard let targetID = transportTargetID else {
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
        let hold = PlaybackPositionHold(target: clamped, since: now)
        positionHold = hold
        pendingSeekTask = Task {
            // Group membership can change between reloads; refresh before resolving
            // the leader so the seek isn't routed to a stale leader (or a follower
            // that rejects it), matching `startPlayback`.
            await refreshActiveSpeaker(activeSpeakerID)
            // If the user switched speakers or seeked again during the await, this
            // seek is stale — bail rather than route it to whatever is now active.
            // Resolve the leader from the speaker that initiated the seek, not the
            // current `playbackTargetID` (which reads whatever is active now).
            guard self.activeSpeakerID == activeSpeakerID, positionHold == hold else {
                return
            }
            let targetID = speakers[activeSpeakerID]?.playbackTargetID ?? activeSpeakerID
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
