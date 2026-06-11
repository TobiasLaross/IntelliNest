//
//  MusicQueue.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-11.
//

import Foundation

/// A single entry in a Music Assistant player queue. `queueItemID` is the stable
/// id the queue-delete command targets (distinct from the track `uri`, since the
/// same track can sit in the queue more than once).
struct MusicQueueItem: Identifiable, Equatable {
    let queueItemID: String
    let uri: String?
    let title: String
    let artist: String?
    let imageURL: String?

    var id: String { queueItemID }
}

/// The state the Queue screen renders: the queue's id (needed for the delete
/// command), the track playing now, and the upcoming tracks.
struct MusicQueue: Equatable {
    let queueID: String?
    let currentItem: MusicQueueItem?
    let upcomingItems: [MusicQueueItem]

    static let empty = MusicQueue(queueID: nil, currentItem: nil, upcomingItems: [])
}

/// Decodes a Music Assistant `QueueItem`, as returned both by the Home Assistant
/// `music_assistant.get_queue` service (for the current item) and the Music
/// Assistant WebSocket `player_queues/items` command (for the upcoming list).
/// The display fields come from the nested `media_item` when present, falling
/// back to the queue item's own `name`.
struct MusicQueueItemDTO: Decodable {
    let queueItemID: String
    let name: String?
    let mediaItem: MediaItemDTO?
    let image: ImageDTO?

    private enum CodingKeys: String, CodingKey {
        case queueItemID = "queue_item_id"
        case name
        case mediaItem = "media_item"
        case image
    }

    struct MediaItemDTO: Decodable {
        let uri: String?
        let name: String?
        let artists: [ArtistDTO]?
        let image: ImageDTO?
        let metadata: MetadataDTO?

        struct MetadataDTO: Decodable {
            let images: [ImageDTO]?
        }
    }

    struct ArtistDTO: Decodable {
        let name: String?
    }

    /// A Music Assistant image reference. Only a remotely-reachable `path` (an
    /// absolute URL) is usable directly; local provider images would need the MA
    /// image proxy, so those are dropped to nil rather than shown broken.
    struct ImageDTO: Decodable {
        let path: String?

        var usableURL: String? {
            guard let path, path.hasPrefix("http") else {
                return nil
            }
            return path
        }
    }

    /// Maps the decoded DTO to a `MusicQueueItem`, or nil when it has no stable
    /// id to target for removal.
    var queueItem: MusicQueueItem? {
        guard queueItemID.isNotEmpty else {
            return nil
        }
        let title = mediaItem?.name ?? name ?? "Okänd låt"
        let imageURL = mediaItem?.image?.usableURL
            ?? mediaItem?.metadata?.images?.compactMap(\.usableURL).first
            ?? image?.usableURL
        return MusicQueueItem(queueItemID: queueItemID,
                              uri: mediaItem?.uri,
                              title: title,
                              artist: mediaItem?.artists?.first?.name,
                              imageURL: imageURL)
    }
}

/// The Music Assistant queue object as serialized by `get_queue` /
/// `player_queues`. Only the fields the Queue screen needs are decoded.
struct MusicQueueDTO: Decodable {
    let queueID: String?
    let currentItem: MusicQueueItemDTO?

    private enum CodingKeys: String, CodingKey {
        case queueID = "queue_id"
        case currentItem = "current_item"
    }
}

enum MusicGetQueueParser {
    /// Parses the `music_assistant.get_queue` `return_response` body into the
    /// queue id and current item. Home Assistant wraps service results under
    /// `service_response`, and the queue then sits either directly under it or
    /// keyed by the entity id (as `browse_media` does). Both shapes are handled,
    /// and a body in any unexpected shape yields an empty queue rather than
    /// throwing — the Queue screen falls back to session state when this is empty.
    static func parse(_ data: Data) -> (queueID: String?, currentItem: MusicQueueItem?) {
        let decoder = JSONDecoder()
        for candidate in candidateObjects(in: data) {
            guard let dto = try? decoder.decode(MusicQueueDTO.self, from: candidate), dto.queueID != nil else {
                continue
            }
            return (dto.queueID, dto.currentItem?.queueItem)
        }
        return (nil, nil)
    }

    /// Returns every JSON object worth trying to decode as a queue: the body
    /// itself, the contents of a `service_response` wrapper, and the first value
    /// of an entity-keyed dictionary at either level.
    private static func candidateObjects(in data: Data) -> [Data] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [data]
        }
        var objects: [[String: Any]] = [root]
        if let serviceResponse = root["service_response"] as? [String: Any] {
            objects.append(serviceResponse)
        }
        // Unwrap one level of entity-id keying (e.g. {"media_player.kitchen": {…}})
        // for each level above. Collect into a separate list so the unwrapped
        // entries are themselves considered (a doubly-keyed shape resolves too).
        var unwrapped: [[String: Any]] = []
        for object in objects where object["queue_id"] == nil {
            if let nested = object.values.first as? [String: Any] {
                unwrapped.append(nested)
            }
        }
        objects.append(contentsOf: unwrapped)
        return objects.compactMap { try? JSONSerialization.data(withJSONObject: $0) }
    }
}
