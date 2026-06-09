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
struct MusicSearchItem: Identifiable, Equatable {
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
