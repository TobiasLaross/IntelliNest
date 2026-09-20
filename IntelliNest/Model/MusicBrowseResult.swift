//
//  MusicBrowseResult.swift
//  IntelliNest
//
//  Created by Tobias on 2026-09-20.
//

import Foundation

/// A single track inside a playlist, decoded from a `browse_media` response.
///
/// `id` carries the track's position in the playlist, not just its uri: a playlist
/// may legitimately hold the same song twice, and two rows sharing a SwiftUI
/// identity inside a `List` let a swipe act on the wrong one.
struct MusicPlaylistTrack: Identifiable, Equatable {
    let id: String
    let uri: String
    let title: String
    let imageURL: String?

    init(id: String? = nil, uri: String, title: String, imageURL: String?) {
        self.id = id ?? uri
        self.uri = uri
        self.title = title
        self.imageURL = imageURL
    }
}

/// One child of a browsed node: a playlist's track, or an artist's album or top
/// track. `media_content_type` is what tells an artist's albums apart from its
/// tracks; the playlist browse ignores it because every child there is a track.
private struct MusicBrowseChild: Decodable {
    let title: String?
    let mediaContentID: String?
    let mediaContentType: String?
    let thumbnail: String?

    private enum CodingKeys: String, CodingKey {
        case title
        case mediaContentID = "media_content_id"
        case mediaContentType = "media_content_type"
        case thumbnail
    }
}

/// The children of a `media_player.browse_media` response. The browsed node is
/// nested under a single dynamic entity-id key, so the children can only be
/// reached by taking whatever key came back. Shared by the playlist and
/// artist/album browses, which differ only in how they map the children.
private enum MusicBrowseNode {
    private struct Node: Decodable {
        let children: [MusicBrowseChild]?
    }

    private struct DynamicKey: CodingKey {
        var stringValue: String
        var intValue: Int?
        init?(stringValue: String) {
            self.stringValue = stringValue
            intValue = nil
        }

        init?(intValue: Int) {
            self.intValue = intValue
            stringValue = String(intValue)
        }
    }

    static func children(from decoder: Decoder) throws -> [MusicBrowseChild] {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        guard let entityKey = container.allKeys.first else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Expected a browsed media node keyed by entity id."
            ))
        }
        return try container.decode(Node.self, forKey: entityKey).children ?? []
    }
}

/// Decodes a `media_player.browse_media` response for a playlist: every child is
/// one of the playlist's tracks.
struct MusicPlaylistBrowseResponse: Decodable {
    let tracks: [MusicPlaylistTrack]

    init(from decoder: Decoder) throws {
        tracks = try MusicBrowseNode.children(from: decoder).enumerated().compactMap { index, child in
            guard let uri = child.mediaContentID, let title = child.title else {
                return nil
            }
            return MusicPlaylistTrack(id: "\(uri)#\(index)", uri: uri, title: title, imageURL: child.thumbnail)
        }
    }
}

/// Decodes a `media_player.browse_media` response for an artist or an album. An
/// artist's children are its albums and top tracks, an album's are its tracks;
/// each keeps its own media type so the browse list can play a track directly and
/// drill into an album. A child whose type Music Assistant reports as something
/// the app has no media type for (a radio stream, say) is dropped rather than
/// guessed at, since the wrong type would be sent straight to `play_media`.
struct MusicArtistBrowseResponse: Decodable {
    let items: [MusicSearchItem]

    init(from decoder: Decoder) throws {
        items = try MusicBrowseNode.children(from: decoder).compactMap { child in
            guard let uri = child.mediaContentID,
                  let title = child.title,
                  let rawType = child.mediaContentType,
                  let mediaType = MusicMediaType(rawValue: rawType) else {
                return nil
            }
            return MusicSearchItem(uri: uri,
                                   name: title,
                                   mediaType: mediaType,
                                   imageURL: child.thumbnail,
                                   artist: nil)
        }
    }
}
