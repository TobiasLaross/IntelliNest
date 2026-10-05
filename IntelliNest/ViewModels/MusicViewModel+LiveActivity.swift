//
//  MusicViewModel+LiveActivity.swift
//  IntelliNest
//
//  Created by Tobias on 2026-10-05.
//

import Foundation

/// The now-playing Live Activity's view of the speakers.
extension MusicViewModel {
    /// The speaker the activity follows: the active speaker while it has audio, otherwise the first room playing.
    var liveActivitySpeakerID: EntityId? {
        if let activeSpeakerID, displayedSpeaker(activeSpeakerID)?.hasLiveAudio == true {
            return activeSpeakerID
        }
        return availableSpeakers.first { $0.isPlaying }?.entityId
    }

    /// What the activity should show, or nil when nothing is playing or paused on a track.
    func liveActivitySnapshot() -> MusicNowPlayingSnapshot? {
        guard let speakerID = liveActivitySpeakerID,
              let speaker = speakers[speakerID],
              let shown = displayedSpeaker(speakerID),
              shown.hasLiveAudio,
              let title = shown.mediaTitle, title.isNotEmpty,
              let transportTargetID = transportTargetID(for: speakerID) else {
            return nil
        }
        let memberIDs = liveActivityGroupMemberIDs(for: speakerID)
        let volumes = memberIDs.compactMap { speakers[$0]?.volumeLevel }
        let groupVolume = volumes.isEmpty ? speaker.volumeLevel : volumes.reduce(0, +) / Double(volumes.count)
        let leaderName = speakers[speaker.playbackTargetID]?.friendlyName ?? speaker.friendlyName
        let roomName = memberIDs.count > 1 ? "\(leaderName) +\(memberIDs.count - 1)" : leaderName
        let state = MusicActivityAttributes.ContentState(title: title,
                                                         artist: shown.mediaArtist,
                                                         roomName: roomName,
                                                         isPlaying: shown.isPlaying,
                                                         position: shown.mediaPosition,
                                                         positionDate: shown.mediaPositionUpdatedAt,
                                                         duration: shown.mediaDuration,
                                                         groupVolume: groupVolume,
                                                         transportTargetID: transportTargetID.rawValue,
                                                         volumeSpeakerIDs: memberIDs.map(\.rawValue))
        return MusicNowPlayingSnapshot(state: state, artworkPath: shown.entityPicture)
    }

    /// The speakers a volume step on the activity moves together: the same group the app's volume slider controls.
    private func liveActivityGroupMemberIDs(for speakerID: EntityId) -> [EntityId] {
        if speakerID == activeSpeakerID {
            return groupedSpeakers.map(\.entityId)
        }
        guard let speaker = speakers[speakerID],
              speaker.groupMembers.count > 1,
              speaker.groupMembers.contains(speakerID) else {
            return [speakerID]
        }
        return Self.speakerIDs.filter { speaker.groupMembers.contains($0) }
    }
}
