//
//  MusicViewModel+NativeGrouping.swift
//  IntelliNest
//
//  Created by Tobias on 2026-09-27.
//

import Foundation

/// Grouping while the active speaker plays a native Sonos source (AirPlay,
/// Spotify Connect, TV). Music Assistant doesn't own that stream, so it can't sync
/// another speaker to it; Sonos's own grouping can, by joining the hardware twins.
/// Only the four Sonos rooms have twins, so only they can join such a group.
extension MusicViewModel {
    /// Whether the active speaker's own Sonos twin is driving a source Music
    /// Assistant doesn't own. Grouping then goes through Sonos instead of MA.
    var isActiveOnNativeSource: Bool {
        guard let activeSpeakerID else {
            return false
        }
        return hardwareTwins[activeSpeakerID]?.hasMirrorableNowPlaying == true
    }

    /// "Primär" picks which MA group member the card controls. A Sonos group
    /// playing a native source has no MA leader to pick, so the chip is hidden.
    var showsPrimary: Bool {
        !isActiveOnNativeSource
    }

    /// The Sonos group the active speaker's twin belongs to, as Music Assistant
    /// speaker ids (coordinator first). Nil when the active speaker isn't playing a
    /// native source, so callers fall back to the MA group.
    var nativeGroupMemberIDs: [EntityId]? {
        guard isActiveOnNativeSource, let activeSpeakerID, let twin = hardwareTwins[activeSpeakerID] else {
            return nil
        }
        let memberIDs = twin.groupMembers.compactMap { twinID in
            Self.hardwareTwinIDs.first { $0.value == twinID }?.key
        }
        return memberIDs.isEmpty ? [activeSpeakerID] : memberIDs
    }

    /// Joins `speakerID` into, or removes it from, the active speaker's Sonos group.
    /// A non-Sonos speaker can't follow a native source, so it gets a banner saying
    /// so instead of a join that would silently land nowhere.
    func toggleNativeGroupMember(_ speakerID: EntityId) async {
        guard let activeSpeakerID,
              let activeTwinID = Self.hardwareTwinIDs[activeSpeakerID] else {
            return
        }
        let speakerName = speakers[speakerID]?.friendlyName ?? speakerID.rawValue
        guard let memberTwinID = Self.hardwareTwinIDs[speakerID] else {
            let leaderName = speakers[activeSpeakerID]?.friendlyName ?? activeSpeakerID.rawValue
            setErrorBannerText("Kunde inte gruppera högtalare",
                               "\(leaderName) spelar från en annan app. Bara Sonos-högtalare kan läggas till")
            return
        }
        let wasGrouped = isGrouped(speakerID)
        pendingGroupingSpeakers.insert(speakerID)
        defer { pendingGroupingSpeakers.remove(speakerID) }
        if wasGrouped {
            let success = await restAPIService.unjoinSpeaker(memberID: memberTwinID)
            if success, await confirmNativeGroupChange(speakerID, shouldBeGrouped: false) {
                return
            }
            setErrorBannerText("Kunde inte dela upp högtalare", "Det gick inte att ta bort \(speakerName) från gruppen")
        } else {
            // Sonos only accepts a join on the group coordinator, which the twin
            // lists first; a lone twin is its own coordinator.
            let coordinatorID = hardwareTwins[activeSpeakerID]?.groupMembers.first ?? activeTwinID
            let success = await restAPIService.joinSpeakers(leaderID: coordinatorID, memberIDs: [memberTwinID])
            if success, await confirmNativeGroupChange(speakerID, shouldBeGrouped: true) {
                return
            }
            setErrorBannerText("Kunde inte gruppera högtalare", "Det gick inte att lägga till \(speakerName) i gruppen")
        }
    }

    /// Takes the active speaker out of its Sonos group. The native stream stays
    /// with the Sonos coordinator, so the selection is left alone: if the active
    /// speaker was the coordinator it keeps playing and the others fall silent.
    func leaveNativeGroup(_ speakerID: EntityId) async {
        guard let twinID = Self.hardwareTwinIDs[speakerID] else {
            return
        }
        let speakerName = speakers[speakerID]?.friendlyName ?? speakerID.rawValue
        pendingGroupingSpeakers.insert(speakerID)
        defer { pendingGroupingSpeakers.remove(speakerID) }
        guard await restAPIService.unjoinSpeaker(memberID: twinID) else {
            setErrorBannerText("Kunde inte dela upp högtalare", "Det gick inte att ta bort \(speakerName) från gruppen")
            return
        }
        await reloadHardwareTwins()
    }

    /// Reloads the twins until `speakerID`'s membership in the active Sonos group
    /// matches the request. Like `confirmGroupChange`, HA answers 200 before the
    /// Sonos topology has updated, so one reload can't tell "not yet" from "refused".
    private func confirmNativeGroupChange(_ speakerID: EntityId, shouldBeGrouped: Bool, attempts: Int = 3) async -> Bool {
        for attempt in 1 ... attempts {
            await reloadHardwareTwins()
            if isGrouped(speakerID) == shouldBeGrouped {
                return true
            }
            if attempt < attempts {
                await waitBeforeGroupRecheck()
            }
        }
        return false
    }
}
