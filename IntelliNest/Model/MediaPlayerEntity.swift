//
//  MediaPlayerEntity.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-09.
//

import Foundation

enum MediaRepeatMode: String, Decodable {
    case off
    case all
    case one
}

/// A Music Assistant `media_player.*` entity. Decodes the playback attributes
/// the music controller needs: now-playing metadata, volume, shuffle/repeat,
/// and the current group members.
struct MediaPlayerEntity: EntityProtocol, Decodable {
    var entityId: EntityId
    var state: String
    var nextUpdate = Date().addingTimeInterval(-1)

    var friendlyName: String
    var volumeLevel: Double
    var mediaTitle: String?
    var mediaArtist: String?
    var mediaAlbumName: String?
    var mediaContentID: String?
    var entityPicture: String?
    var groupMembers: [EntityId]
    var shuffle: Bool
    var repeatMode: MediaRepeatMode
    /// Playback position in seconds at the moment Home Assistant last reported it
    /// (`media_position`). It is *not* live — it only advances in the payload when
    /// HA re-reports it (on play/pause/seek/track change), so the live elapsed time
    /// must be extrapolated from `mediaPositionUpdatedAt`. See `currentElapsed(asOf:)`.
    var mediaPosition: Double?
    /// Track length in seconds (`media_duration`). Nil for sources with no known
    /// length (e.g. a live stream), which hides the scrubber.
    var mediaDuration: Double?
    /// When `mediaPosition` was sampled (`media_position_updated_at`), the anchor
    /// for extrapolating the live position while playing.
    var mediaPositionUpdatedAt: Date?

    var isActive: Bool {
        state == "playing"
    }

    var isPlaying: Bool {
        state == "playing"
    }

    /// Whether the speaker is actually driving audio (playing or paused on a
    /// track), as opposed to idle or unavailable. Used to decide when a hardware
    /// twin's now-playing should override the Music Assistant queue entity's.
    var hasLiveAudio: Bool {
        state == "playing" || state == "paused"
    }

    /// Whether this entity is only rendering Music Assistant's own universal flow
    /// stream rather than a source it has real metadata for. A Sonos playing the
    /// MA flow reports the generic "Music Assistant" title with no artist and a
    /// `…/flow/…` stream as its content id, while the MA queue entity holds the
    /// real track — so in that case the twin must not override the MA now-playing.
    var isRenderingMusicAssistantFlow: Bool {
        mediaContentID?.contains("/flow/") == true
    }

    /// Whether this hardware twin carries a now-playing worth mirroring onto its
    /// Music Assistant entity: it's driving audio for a source it actually has
    /// metadata for (native AirPlay, Spotify Connect, TV), not merely rendering
    /// the MA flow stream the MA queue entity already describes.
    var hasMirrorableNowPlaying: Bool {
        hasLiveAudio && !isRenderingMusicAssistantFlow
    }

    /// Whether this entity and another are confidently on the same track, compared
    /// by title and artist. The Music Assistant entity and its native Sonos twin
    /// share no comparable content id (MA exposes a Spotify URI, the Sonos a stream
    /// URL), so the track identity is matched on the human-readable metadata.
    /// A missing title can't confirm identity, so it counts as *not* the same track
    /// — otherwise two metadata-less entities would match and a stale MA URI would
    /// be wrongly preserved.
    func isSameTrack(as other: MediaPlayerEntity) -> Bool {
        guard let title = mediaTitle, title.isNotEmpty else {
            return false
        }
        return title == other.mediaTitle && mediaArtist == other.mediaArtist
    }

    /// Returns a copy of this Music Assistant entity with its now-playing display
    /// (state, track metadata, album art) replaced by the hardware twin's whenever
    /// the twin is driving audio. Keeps every control-relevant field — id, group
    /// members, volume, shuffle, repeat — from the MA entity, since playback
    /// commands still route through Music Assistant. When the twin is playing a
    /// track the MA queue doesn't know about, the MA content id (a Spotify URI) no
    /// longer matches what's audible, so it's cleared to keep the favourite star
    /// and playlist-jump from acting on the wrong track.
    func mirroring(_ twin: MediaPlayerEntity?) -> MediaPlayerEntity {
        guard let twin, twin.hasLiveAudio else {
            return self
        }
        var mirrored = self
        mirrored.state = twin.state
        mirrored.mediaTitle = twin.mediaTitle
        mirrored.mediaArtist = twin.mediaArtist
        mirrored.mediaAlbumName = twin.mediaAlbumName
        mirrored.entityPicture = twin.entityPicture
        // The twin drives the audio here, so its position is the real one; the MA
        // queue entity's frozen position would mis-place the scrubber and lyrics.
        mirrored.mediaPosition = twin.mediaPosition
        mirrored.mediaDuration = twin.mediaDuration
        mirrored.mediaPositionUpdatedAt = twin.mediaPositionUpdatedAt
        if !twin.isSameTrack(as: self) {
            mirrored.mediaContentID = nil
        }
        return mirrored
    }

    /// The speaker that playback and queue commands must target. When this
    /// speaker is synced into a group, Music Assistant only accepts transport
    /// and play commands on the group leader (the first group member); a
    /// follower rejects them. Falls back to this speaker when it is ungrouped.
    ///
    /// A well-formed Music Assistant group always lists this speaker among its
    /// members. If `group_members` doesn't include it (a stale or malformed
    /// list), play on this speaker rather than redirecting to a leader it isn't
    /// actually grouped with — otherwise the music starts on the wrong speaker.
    var playbackTargetID: EntityId {
        guard groupMembers.contains(entityId), let leader = groupMembers.first else {
            return entityId
        }
        return leader
    }

    var isUnavailable: Bool {
        state == "unavailable"
    }

    /// The live playback position in seconds as of `now`. While playing, the
    /// last-reported `mediaPosition` is extrapolated forward from its sample time
    /// (`mediaPositionUpdatedAt`) and clamped to the track length; while paused (or
    /// with no sample time) the reported position is returned as-is. Nil when the
    /// source reports no position at all. `now` is passed in so the computation is
    /// deterministic and testable.
    func currentElapsed(asOf now: Date) -> TimeInterval? {
        guard let mediaPosition else {
            return nil
        }
        guard isPlaying, let mediaPositionUpdatedAt else {
            return max(mediaPosition, 0)
        }
        // Never extrapolate backward: if the device clock lags Home Assistant the
        // delta is negative, which would make the scrubber and lyrics jump back.
        let elapsed = max(mediaPosition, mediaPosition + now.timeIntervalSince(mediaPositionUpdatedAt))
        if let mediaDuration {
            return min(max(elapsed, 0), mediaDuration)
        }
        return max(elapsed, 0)
    }

    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case state
        case attributes
    }

    private enum AttributesCodingKeys: String, CodingKey {
        case friendlyName = "friendly_name"
        case volumeLevel = "volume_level"
        case mediaTitle = "media_title"
        case mediaArtist = "media_artist"
        case mediaAlbumName = "media_album_name"
        case mediaContentID = "media_content_id"
        case entityPicture = "entity_picture"
        case groupMembers = "group_members"
        case shuffle
        case repeatMode = "repeat"
        case mediaPosition = "media_position"
        case mediaDuration = "media_duration"
        case mediaPositionUpdatedAt = "media_position_updated_at"
    }

    init(entityId: EntityId, state: String = "Loading", friendlyName: String = "") {
        self.entityId = entityId
        self.state = state
        self.friendlyName = friendlyName
        volumeLevel = 0
        groupMembers = []
        shuffle = false
        repeatMode = .off
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        entityId = try container.decode(EntityId.self, forKey: .entityId)
        state = try container.decode(String.self, forKey: .state)

        if let attributes = try? container.nestedContainer(keyedBy: AttributesCodingKeys.self, forKey: .attributes) {
            friendlyName = try attributes.decodeIfPresent(String.self, forKey: .friendlyName) ?? ""
            volumeLevel = try attributes.decodeIfPresent(Double.self, forKey: .volumeLevel) ?? 0
            mediaTitle = try attributes.decodeIfPresent(String.self, forKey: .mediaTitle)
            mediaArtist = try attributes.decodeIfPresent(String.self, forKey: .mediaArtist)
            mediaAlbumName = try attributes.decodeIfPresent(String.self, forKey: .mediaAlbumName)
            mediaContentID = try attributes.decodeIfPresent(String.self, forKey: .mediaContentID)
            entityPicture = try attributes.decodeIfPresent(String.self, forKey: .entityPicture)
            let memberStrings = try attributes.decodeIfPresent([String].self, forKey: .groupMembers) ?? []
            groupMembers = memberStrings.compactMap { EntityId(rawValue: $0) }
            shuffle = try attributes.decodeIfPresent(Bool.self, forKey: .shuffle) ?? false
            repeatMode = try attributes.decodeIfPresent(MediaRepeatMode.self, forKey: .repeatMode) ?? .off
            mediaPosition = try attributes.decodeIfPresent(Double.self, forKey: .mediaPosition)
            mediaDuration = try attributes.decodeIfPresent(Double.self, forKey: .mediaDuration)
            if let updatedAtString = try attributes.decodeIfPresent(String.self, forKey: .mediaPositionUpdatedAt) {
                mediaPositionUpdatedAt = Entity.utcDateFormatter.date(from: updatedAtString)
            }
        } else {
            friendlyName = ""
            volumeLevel = 0
            groupMembers = []
            shuffle = false
            repeatMode = .off
        }
    }

    mutating func setNextUpdateTime() {
        nextUpdate = Date().addingTimeInterval(0.5)
    }

    static func == (lhs: MediaPlayerEntity, rhs: MediaPlayerEntity) -> Bool {
        lhs.entityId == rhs.entityId &&
            lhs.state == rhs.state &&
            lhs.friendlyName == rhs.friendlyName &&
            lhs.volumeLevel == rhs.volumeLevel &&
            lhs.mediaTitle == rhs.mediaTitle &&
            lhs.mediaArtist == rhs.mediaArtist &&
            lhs.mediaAlbumName == rhs.mediaAlbumName &&
            lhs.mediaContentID == rhs.mediaContentID &&
            lhs.entityPicture == rhs.entityPicture &&
            lhs.groupMembers == rhs.groupMembers &&
            lhs.shuffle == rhs.shuffle &&
            lhs.repeatMode == rhs.repeatMode &&
            lhs.mediaPosition == rhs.mediaPosition &&
            lhs.mediaDuration == rhs.mediaDuration &&
            lhs.mediaPositionUpdatedAt == rhs.mediaPositionUpdatedAt
    }
}
