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
    ///
    /// The two transports disagree on the shape: the `player_queues/items` socket
    /// sends an object (`{"path": "https://…"}`), while `get_queue` serializes a
    /// `media_item.image` as a bare URL string. Decode both, otherwise a
    /// string-shaped image throws and takes the whole `get_queue` decode with it —
    /// which left `queue_id` nil and the "Näst på tur" list silently empty.
    struct ImageDTO: Decodable {
        let path: String?

        init(from decoder: Decoder) throws {
            if let single = try? decoder.singleValueContainer(), let url = try? single.decode(String.self) {
                path = url
                return
            }
            let container = try decoder.container(keyedBy: CodingKeys.self)
            path = try container.decodeIfPresent(String.self, forKey: .path)
        }

        private enum CodingKeys: String, CodingKey {
            case path
        }

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
    let nextItem: MusicQueueItemDTO?

    private enum CodingKeys: String, CodingKey {
        case queueID = "queue_id"
        case currentItem = "current_item"
        case nextItem = "next_item"
    }
}

/// What `get_queue` yields for the Queue screen: the queue id (needed to target
/// the WebSocket delete command), the current item ("Spelas nu"), and the
/// immediate next item. `next_item` works over REST, so it backs "Näst på tur"
/// away from home when the LAN-only socket can't supply the full list.
struct MusicQueueState {
    let queueID: String?
    let currentItem: MusicQueueItem?
    let nextItem: MusicQueueItem?

    static let empty = MusicQueueState(queueID: nil, currentItem: nil, nextItem: nil)
}

enum MusicGetQueueParser {
    /// Parses the `music_assistant.get_queue` `return_response` body. Home Assistant
    /// wraps service results under `service_response`, and the queue then sits
    /// either directly under it or keyed by the entity id (as `browse_media` does).
    /// Both shapes are handled, and a body in any unexpected shape yields an empty
    /// state rather than throwing — the Queue screen falls back to session state.
    static func parse(_ data: Data) -> MusicQueueState {
        let decoder = JSONDecoder()
        for candidate in candidateObjects(in: data) {
            guard let dto = try? decoder.decode(MusicQueueDTO.self, from: candidate), dto.queueID != nil else {
                continue
            }
            return MusicQueueState(queueID: dto.queueID,
                                   currentItem: dto.currentItem?.queueItem,
                                   nextItem: dto.nextItem?.queueItem)
        }
        return .empty
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
