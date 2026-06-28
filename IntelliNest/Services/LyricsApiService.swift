//
//  LyricsApiService.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-28.
//

import Foundation

/// Fetches lyrics for the now-playing track. Hidden behind a protocol so
/// `MusicViewModel` can be tested with a stub and previews need no network.
@MainActor
protocol LyricsService {
    /// Looks up lyrics for a track. Prefers time-synced lyrics; falls back to plain
    /// text, then `.notFound`. Never throws — every failure degrades to `.notFound`.
    func fetchLyrics(title: String, artist: String, album: String?, durationSeconds: Double?) async -> LyricsResult
}

/// A no-op lyrics service used by previews and tests so the music UI works without
/// reaching the network.
@MainActor
final class DisabledLyricsService: LyricsService {
    func fetchLyrics(title: String, artist: String, album: String?, durationSeconds: Double?) async -> LyricsResult {
        .notFound
    }
}

/// Looks up lyrics from LRCLIB (synced, primary) with lyrics.ovh (plain, backup).
/// Both are free, key-less, on-demand lookups suited to a personal app; LRCLIB asks
/// callers to send a descriptive `User-Agent`, which this does. All failures are
/// swallowed into `.notFound` so a missing or unreachable source never disrupts
/// playback.
@MainActor
final class LyricsApiService: LyricsService {
    private let session: URLSession
    private let userAgent: String

    private let lrclibBaseURL = "https://lrclib.net/api"
    private let lyricsOvhBaseURL = "https://api.lyrics.ovh/v1"
    /// Per-request timeout. Short enough that a stalled provider doesn't hang the
    /// lyrics spinner, generous enough for a slow mobile network.
    private static let requestTimeout: TimeInterval = 8

    init(session: URLSession = .shared, userAgent: String = LyricsApiService.defaultUserAgent) {
        self.session = session
        self.userAgent = userAgent
    }

    /// `IntelliNest/<app version> (+repo url)`, the descriptive agent LRCLIB requests.
    /// `nonisolated` so it can be used as a default argument (evaluated outside the
    /// main actor).
    nonisolated static var defaultUserAgent: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return "IntelliNest/\(version) (+https://github.com/tobiaslaross/IntelliNest)"
    }

    func fetchLyrics(title: String, artist: String, album: String?, durationSeconds: Double?) async -> LyricsResult {
        guard title.isNotEmpty, artist.isNotEmpty else {
            return .notFound
        }
        let primary = await fetchFromLRCLIB(title: title, artist: artist, album: album, durationSeconds: durationSeconds)
        if primary != .notFound {
            return primary
        }
        if let plain = await fetchFromLyricsOvh(title: title, artist: artist) {
            return .plain(plain)
        }
        return .notFound
    }

    // MARK: - LRCLIB (primary, synced)

    private func fetchFromLRCLIB(title: String, artist: String, album: String?, durationSeconds: Double?) async -> LyricsResult {
        var components = URLComponents(string: "\(lrclibBaseURL)/get")
        var queryItems = [
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "track_name", value: title)
        ]
        if let album, album.isNotEmpty {
            queryItems.append(URLQueryItem(name: "album_name", value: album))
        }
        if let durationSeconds {
            queryItems.append(URLQueryItem(name: "duration", value: String(Int(durationSeconds.rounded()))))
        }
        components?.queryItems = queryItems

        if let url = components?.url, let record = await getJSON(url, as: LRCLIBRecord.self) {
            let result = record.lyricsResult
            if result != .notFound {
                return result
            }
        }
        return await searchLRCLIB(title: title, artist: artist, durationSeconds: durationSeconds)
    }

    /// Falls back to LRCLIB's fuzzy search when the exact `get` misses, then picks
    /// the candidate closest to the known track length (preferring synced ones).
    private func searchLRCLIB(title: String, artist: String, durationSeconds: Double?) async -> LyricsResult {
        var components = URLComponents(string: "\(lrclibBaseURL)/search")
        components?.queryItems = [URLQueryItem(name: "q", value: "\(title) \(artist)")]
        guard let url = components?.url,
              let records = await getJSON(url, as: [LRCLIBRecord].self),
              records.isNotEmpty else {
            return .notFound
        }
        let synced = records.filter { $0.syncedLyrics?.isNotEmpty == true }
        let pool = synced.isNotEmpty ? synced : records
        let best: LRCLIBRecord = if let durationSeconds {
            pool.min {
                abs(($0.duration ?? 0) - durationSeconds) < abs(($1.duration ?? 0) - durationSeconds)
            } ?? pool[0]
        } else {
            pool[0]
        }
        return best.lyricsResult
    }

    // MARK: - lyrics.ovh (backup, plain)

    private func fetchFromLyricsOvh(title: String, artist: String) async -> String? {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove("/")
        guard let escapedArtist = artist.addingPercentEncoding(withAllowedCharacters: allowed),
              let escapedTitle = title.addingPercentEncoding(withAllowedCharacters: allowed),
              let url = URL(string: "\(lyricsOvhBaseURL)/\(escapedArtist)/\(escapedTitle)") else {
            return nil
        }
        guard let record = await getJSON(url, as: LyricsOvhRecord.self),
              let lyrics = record.lyrics,
              lyrics.isNotEmpty else {
            return nil
        }
        return lyrics
    }

    // MARK: - Networking

    private func getJSON<Response: Decodable>(_ url: URL, as type: Response.Type) async -> Response? {
        // Cap each lookup so a slow or stalled provider can't leave the lyrics
        // spinner hanging — the chain has a backup source, and a miss is fine.
        var request = URLRequest(url: url, timeoutInterval: Self.requestTimeout)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200 ..< 300).contains(httpResponse.statusCode) else {
                return nil
            }
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            // Log only the host, never the full URL — it carries the song/artist, and
            // app logs are forwarded to Home Assistant's system log.
            Log.error("Lyrics fetch failed for \(url.host ?? "lyrics provider"): \(error)")
            return nil
        }
    }
}

/// One LRCLIB record (from `get` or an item of `search`). Carries both the synced
/// and plain forms; `lyricsResult` prefers synced when it actually parses.
private struct LRCLIBRecord: Decodable {
    let duration: Double?
    let plainLyrics: String?
    let syncedLyrics: String?

    var lyricsResult: LyricsResult {
        if let syncedLyrics, syncedLyrics.isNotEmpty {
            let lines = LyricsTimeline.parseLRC(syncedLyrics)
            if lines.isNotEmpty {
                return .synced(lines)
            }
        }
        if let plainLyrics, plainLyrics.isNotEmpty {
            return .plain(plainLyrics)
        }
        return .notFound
    }
}

private struct LyricsOvhRecord: Decodable {
    let lyrics: String?
}
