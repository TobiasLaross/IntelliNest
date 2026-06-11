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
/// A raw Music Assistant media item as returned by both `search` and
/// `get_library`. Carries the playable `uri`, display `name`, an optional cover
/// `image` (under either `image` or `media_image`), and `artists` metadata.
private struct MusicRawMediaItem: Decodable {
    let uri: String?
    let name: String?
    let image: String?
    let artists: [MusicRawArtist]?

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
        artists = try container.decodeIfPresent([MusicRawArtist].self, forKey: .artists)
    }

    /// Builds a `MusicSearchItem` of `mediaType`, or nil when the playable
    /// fields (`uri`, `name`) are missing.
    func searchItem(mediaType: MusicMediaType) -> MusicSearchItem? {
        guard let uri, let name else {
            return nil
        }
        return MusicSearchItem(uri: uri,
                               name: name,
                               mediaType: mediaType,
                               imageURL: image,
                               artist: artists?.first?.name)
    }
}

private struct MusicRawArtist: Decodable {
    let name: String?
}

struct MusicSearchResponse: Decodable {
    let sections: [MusicSearchSection]

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
            let rawItems = try container.decodeIfPresent([MusicRawMediaItem].self, forKey: key) ?? []
            let items = rawItems.compactMap { $0.searchItem(mediaType: mediaType) }
            if items.isNotEmpty {
                builtSections.append(MusicSearchSection(mediaType: mediaType, items: items))
            }
        }
        sections = builtSections
    }
}

/// Decodes a `music_assistant.get_library` `return_response` body for playlists.
/// Music Assistant returns the items under an `items` array; some versions
/// return a bare array instead, so both shapes are accepted.
struct MusicLibraryResponse: Decodable {
    let playlists: [MusicSearchItem]

    private enum CodingKeys: String, CodingKey {
        case items
    }

    init(from decoder: Decoder) throws {
        let rawItems: [MusicRawMediaItem] = if let container = try? decoder.container(keyedBy: CodingKeys.self),
                                               let items = try? container.decodeIfPresent([MusicRawMediaItem].self, forKey: .items) {
            items
        } else {
            try decoder.singleValueContainer().decode([MusicRawMediaItem].self)
        }
        playlists = rawItems.compactMap { $0.searchItem(mediaType: .playlist) }
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
