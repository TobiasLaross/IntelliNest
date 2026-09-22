//
//  MusicViewModel+Grouping.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-18.
//

import Foundation

/// Speaker grouping and group-volume handling, split out of `MusicViewModel`
/// to keep that file under the file-length limit.
extension MusicViewModel {
    // MARK: - Group volume

    /// The speakers currently synced with the active speaker (leader plus any
    /// followers), in the fixed display order. When the active speaker is
    /// ungrouped this is just the active speaker on its own.
    var groupedSpeakers: [MediaPlayerEntity] {
        guard let activeSpeaker else {
            return []
        }
        let memberIDs = activeSpeaker.groupMembers
        guard memberIDs.count > 1 else {
            return [activeSpeaker]
        }
        return Self.speakerIDs.filter { memberIDs.contains($0) }.compactMap { speakers[$0] }
    }

    /// Whether the active speaker is synced with at least one other speaker, so
    /// the volume control should act on the whole group.
    var isGroupActive: Bool {
        groupedSpeakers.count > 1
    }

    /// The single value shown on the group-volume banner: the average volume
    /// across every grouped speaker.
    var groupVolume: Double {
        let grouped = groupedSpeakers
        guard grouped.isNotEmpty else {
            return 0
        }
        let total = grouped.reduce(0.0) { $0 + $1.volumeLevel }
        return total / Double(grouped.count)
    }

    /// Sets every grouped speaker to the same absolute volume. Individual
    /// speakers can still be rebalanced afterwards via their own sliders.
    func setGroupVolume(_ volume: Double) {
        for speaker in groupedSpeakers {
            setVolume(volume, for: speaker.entityId)
        }
    }

    // MARK: - Speaker picker

    /// The speaker picker's cards in display order: every synced Music Assistant
    /// group collapsed into one entry (leader first), and every other speaker on its
    /// own. A card sits where its first-listed speaker would, so the fixed room
    /// order still reads top to bottom. Membership comes from the first speaker of
    /// the group encountered, since its `group_members` names the whole group; a
    /// group whose other members are all unavailable degrades to a single card.
    var speakerPickerEntries: [SpeakerPickerEntry] {
        let available = availableSpeakers
        var placedIDs: Set<EntityId> = []
        var entries: [SpeakerPickerEntry] = []
        for speaker in available where !placedIDs.contains(speaker.entityId) {
            let memberIDs = speaker.groupMembers
            let isInGroup = memberIDs.count > 1 && memberIDs.contains(speaker.entityId)
            let members = isInGroup
                ? available.filter { memberIDs.contains($0.entityId) && !placedIDs.contains($0.entityId) }
                : [speaker]
            // Music Assistant lists the group leader first; fall back to the first
            // shown member when the leader itself isn't reachable.
            let leader = members.first { $0.entityId == memberIDs.first } ?? speaker
            placedIDs.formUnion(members.map(\.entityId))
            entries.append(SpeakerPickerEntry(leader: leader,
                                              followers: members.filter { $0.entityId != leader.entityId }))
        }
        return entries
    }

    /// Sets every speaker in a picker group to the same absolute volume, like
    /// `setGroupVolume` does for the active group.
    func setGroupVolume(_ volume: Double, for entry: SpeakerPickerEntry) {
        for speaker in entry.members {
            setVolume(volume, for: speaker.entityId)
        }
    }

    // MARK: - Grouping

    /// Whether `speakerID` is currently grouped with the active speaker.
    func isGrouped(_ speakerID: EntityId) -> Bool {
        guard let activeSpeaker, speakerID != activeSpeaker.entityId else {
            return false
        }
        return activeSpeaker.groupMembers.contains(speakerID)
    }

    /// Toggles `speakerID` into or out of the active speaker's group. The active
    /// speaker stays the group leader (the `join` sync source). Surfaces an error
    /// banner when Home Assistant rejects the group change, so a failed sync no
    /// longer looks like a silent no-op. Marks the speaker pending while the call
    /// and the confirming reload settle, so its row shows a spinner.
    func toggleGroupMember(_ speakerID: EntityId) async {
        guard let activeSpeakerID, speakerID != activeSpeakerID else {
            return
        }
        let speakerName = speakers[speakerID]?.friendlyName ?? speakerID.rawValue
        let wasGrouped = isGrouped(speakerID)
        pendingGroupingSpeakers.insert(speakerID)
        defer { pendingGroupingSpeakers.remove(speakerID) }
        if wasGrouped {
            let success = await restAPIService.unjoinSpeaker(memberID: speakerID)
            if success, await confirmGroupChange(speakerID, with: activeSpeakerID, shouldBeGrouped: false) {
                return
            }
            setErrorBannerText("Kunde inte dela upp högtalare", "Det gick inte att ta bort \(speakerName) från gruppen")
        } else {
            // A speaker already synced into a different group (e.g. Spa paired with
            // Matbord-ute) can't be moved by a plain join, so unjoin it from its
            // current group first. groupMembers > 1 means it is grouped with someone
            // other than the active leader, since the grouped-with-leader case is the
            // unjoin branch above.
            let isInOtherGroup = (speakers[speakerID]?.groupMembers.count ?? 0) > 1
            let success = await restAPIService.joinSpeakers(leaderID: activeSpeakerID,
                                                            memberIDs: [speakerID],
                                                            unjoinFirst: isInOtherGroup)
            if success, await confirmGroupChange(speakerID, with: activeSpeakerID, shouldBeGrouped: true) {
                return
            }
            // A leader playing a source Music Assistant doesn't own is the usual
            // reason a join lands nowhere, and it's the one the user can act on.
            if speakers[activeSpeakerID]?.isPlayingExternalSource == true {
                let leaderName = speakers[activeSpeakerID]?.friendlyName ?? activeSpeakerID.rawValue
                setErrorBannerText("Kunde inte gruppera högtalare",
                                   "\(leaderName) spelar från en annan app. Starta musiken härifrån för att spela på flera högtalare")
            } else {
                setErrorBannerText("Kunde inte gruppera högtalare", "Det gick inte att lägga till \(speakerName) i gruppen")
            }
        }
    }

    /// Reloads the speakers until `speakerID`'s membership in `leaderID`'s group
    /// matches what the change asked for, and reports whether it ever did. Home
    /// Assistant returns 200 from `join`/`unjoin` before the membership is live, so a
    /// single reload can't tell "not applied yet" from a group Music Assistant quietly
    /// refused to build. Membership is read against the leader the request was sent to
    /// rather than `isGrouped`, since the user can select a different speaker while
    /// these reloads are in flight.
    private func confirmGroupChange(_ speakerID: EntityId,
                                    with leaderID: EntityId,
                                    shouldBeGrouped: Bool,
                                    attempts: Int = 3) async -> Bool {
        for attempt in 1 ... attempts {
            await reloadSpeakers()
            let isMember = speakers[leaderID]?.groupMembers.contains(speakerID) == true
            if isMember == shouldBeGrouped {
                return true
            }
            if attempt < attempts {
                await waitBeforeGroupRecheck()
            }
        }
        return false
    }

    /// Promotes a grouped speaker to primary — the one shown and controlled as the
    /// group's main speaker. Playback still routes through the live Music Assistant
    /// group leader (`playbackTargetID`), so switching the primary never interrupts
    /// what's playing. No-op for a speaker that isn't grouped with the active one.
    func makePrimary(_ speakerID: EntityId) {
        guard speakerID != activeSpeakerID, isGrouped(speakerID) else {
            return
        }
        selectSpeaker(speakerID)
    }

    /// Removes the active (primary) speaker from its group and promotes the next
    /// grouped speaker to active, so playback control follows the speakers that
    /// keep playing. Music Assistant re-elects the real group leader on its own;
    /// the new `activeSpeakerID` only needs to be a remaining member, since
    /// playback commands are routed through the live group leader. No-op when the
    /// active speaker isn't grouped with anyone.
    func removeActiveSpeakerFromGroup() async {
        guard let activeSpeakerID, let activeSpeaker else {
            return
        }
        let remaining = Self.speakerIDs.filter { activeSpeaker.groupMembers.contains($0) && $0 != activeSpeakerID }
        guard let newActiveID = remaining.first else {
            return
        }
        pendingGroupingSpeakers.insert(activeSpeakerID)
        defer { pendingGroupingSpeakers.remove(activeSpeakerID) }
        let speakerName = activeSpeaker.friendlyName
        let success = await restAPIService.unjoinSpeaker(memberID: activeSpeakerID)
        if success {
            await reloadSpeakers()
            // Route through selectSpeaker so the promoted speaker is also persisted
            // as the last-used one, like any other manual selection.
            selectSpeaker(newActiveID)
        } else {
            setErrorBannerText("Kunde inte dela upp högtalare", "Det gick inte att ta bort \(speakerName) från gruppen")
        }
    }
}

/// One card in the speaker picker: a lone speaker, or a synced group shown as a
/// single card with its members nested inside.
struct SpeakerPickerEntry: Identifiable {
    /// The group leader, or the lone speaker. Picking the card selects it.
    let leader: MediaPlayerEntity
    /// The other synced speakers, in display order. Empty for a lone speaker.
    let followers: [MediaPlayerEntity]

    var id: EntityId { leader.entityId }

    /// Every speaker on the card, leader first.
    var members: [MediaPlayerEntity] { [leader] + followers }

    var isGroup: Bool { followers.isNotEmpty }

    /// The card header, e.g. "Lekrummet + Köket".
    var title: String {
        members.map(\.friendlyName).joined(separator: " + ")
    }

    /// The average member volume, shown on the group slider.
    var averageVolume: Double {
        members.reduce(0.0) { $0 + $1.volumeLevel } / Double(members.count)
    }

    func contains(_ speakerID: EntityId?) -> Bool {
        members.contains { $0.entityId == speakerID }
    }
}
