//
//  MusicSearchResult.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-09.
//

import Foundation

/// The four media types Music Assistant search returns, in display order.
enum MusicMediaType: String, CaseIterable, Decodable {
    case track
    case album
    case artist
    case playlist

    /// Swedish section heading for grouped search results.
    var swedishTitle: String {
        switch self {
        case .track:
            "Låtar"
        case .album:
            "Album"
        case .artist:
            "Artister"
        case .playlist:
            "Spellistor"
        }
    }
}

/// A single Music Assistant search result item. `uri` is the playable media id
/// (e.g. `spotify://track/3SjXx3rbNGk8nCho8YEoz5`).
struct MusicSearchItem: Identifiable, Equatable, Hashable {
    let uri: String
    let name: String
    let mediaType: MusicMediaType
    let imageURL: String?
    let artist: String?

    var id: String { uri }
}

/// Results for one media type, used to render grouped sections.
struct MusicSearchSection: Identifiable, Equatable {
    let mediaType: MusicMediaType
    let items: [MusicSearchItem]

    var id: String { mediaType.rawValue }
}

/// Decodes the `music_assistant.search` `return_response` body. The response
/// is a JSON object whose top-level keys are pluralised media types
/// (`tracks`, `albums`, `artists`, `playlists`), each an array of items. Each
/// item carries a `uri`, `name`, optional `image`, and `artists` metadata.
struct MusicSearchResponse: Decodable {
    let sections: [MusicSearchSection]

    private struct RawItem: Decodable {
        let uri: String?
        let name: String?
        let image: String?
        let artists: [RawArtist]?

        private enum CodingKeys: String, CodingKey {
            case uri
            case name
            case image
            case mediaImage = "media_image"
            case artists
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            uri = try container.decodeIfPresent(String.self, forKey: .uri)
            name = try container.decodeIfPresent(String.self, forKey: .name)
            image = try container.decodeIfPresent(String.self, forKey: .image)
                ?? container.decodeIfPresent(String.self, forKey: .mediaImage)
            artists = try container.decodeIfPresent([RawArtist].self, forKey: .artists)
        }
    }

    private struct RawArtist: Decodable {
        let name: String?
    }

    private enum CodingKeys: String, CodingKey {
        case tracks
        case albums
        case artists
        case playlists
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawByType: [(MusicMediaType, CodingKeys)] = [
            (.track, .tracks),
            (.album, .albums),
            (.artist, .artists),
            (.playlist, .playlists)
        ]

        var builtSections: [MusicSearchSection] = []
        for (mediaType, key) in rawByType {
            let rawItems = try container.decodeIfPresent([RawItem].self, forKey: key) ?? []
            let items: [MusicSearchItem] = rawItems.compactMap { rawItem in
                guard let uri = rawItem.uri, let name = rawItem.name else {
                    return nil
                }
                return MusicSearchItem(uri: uri,
                                       name: name,
                                       mediaType: mediaType,
                                       imageURL: rawItem.image,
                                       artist: rawItem.artists?.first?.name)
            }
            if items.isNotEmpty {
                builtSections.append(MusicSearchSection(mediaType: mediaType, items: items))
            }
        }
        sections = builtSections
    }
}

/// A single track inside a playlist, decoded from a `browse_media` response.
struct MusicPlaylistTrack: Identifiable, Equatable {
    let uri: String
    let title: String
    let imageURL: String?

    var id: String { uri }
}

/// Decodes a `media_player.browse_media` response for a playlist. The browsed
/// node is nested under a single dynamic entity-id key; its `children` are the
/// playlist's tracks (each a track uri in `media_content_id`, a `title`, and an
/// optional `thumbnail`).
struct MusicPlaylistBrowseResponse: Decodable {
    let tracks: [MusicPlaylistTrack]

    private struct Node: Decodable {
        let children: [Child]?
    }

    private struct Child: Decodable {
        let title: String?
        let mediaContentID: String?
        let thumbnail: String?

        private enum CodingKeys: String, CodingKey {
            case title
            case mediaContentID = "media_content_id"
            case thumbnail
        }
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        guard let entityKey = container.allKeys.first else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Expected a browsed playlist node keyed by entity id."
            ))
        }
        let node = try container.decode(Node.self, forKey: entityKey)
        tracks = (node.children ?? []).compactMap { child in
            guard let uri = child.mediaContentID, let title = child.title else {
                return nil
            }
            return MusicPlaylistTrack(uri: uri, title: title, imageURL: child.thumbnail)
        }
    }
}
