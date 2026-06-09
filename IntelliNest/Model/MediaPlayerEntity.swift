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

    var isActive: Bool {
        state == "playing"
    }

    var isPlaying: Bool {
        state == "playing"
    }

    var isUnavailable: Bool {
        state == "unavailable"
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
            lhs.volumeLevel == rhs.volumeLevel &&
            lhs.mediaTitle == rhs.mediaTitle &&
            lhs.mediaArtist == rhs.mediaArtist &&
            lhs.mediaContentID == rhs.mediaContentID &&
            lhs.groupMembers == rhs.groupMembers &&
            lhs.shuffle == rhs.shuffle &&
            lhs.repeatMode == rhs.repeatMode
    }
}
