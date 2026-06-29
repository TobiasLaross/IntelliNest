//
//  LyricsCache.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-29.
//

import Foundation

/// A small persistent cache of fetched lyrics, keyed by a normalized track key
/// (title + artist + album). Lyrics for a track never change, so a hit is served
/// without touching the network — instant on a re-open and across launches.
///
/// Backed by a single JSON file in the Caches directory. Only successful lookups
/// are stored: a `.notFound` collapses transient failures and true misses, so it
/// stays retryable (matching the fetch-side latch). Capacity-bounded with simple
/// LRU eviction. An `actor` so the in-memory map and the file stay consistent off
/// the main actor; all I/O is best-effort and never throws into the caller.
actor LyricsCache {
    private var entries: [String: LyricsResult] = [:]
    /// Keys in least-recently-used order (oldest first) for capacity eviction.
    private var lru: [String] = []
    private let capacity: Int
    private let fileURL: URL?
    private var didLoad = false

    /// `directory: nil` keeps the cache in memory only — used by tests and previews
    /// so they never read or write the shared on-disk cache.
    init(capacity: Int = 200,
         directory: URL? = LyricsCache.defaultDirectory,
         filename: String = "lyrics-cache.json") {
        self.capacity = capacity
        fileURL = directory?.appendingPathComponent(filename)
    }

    static var defaultDirectory: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    }

    /// A stable key from the track identity, normalized so trivial case/spacing
    /// differences don't fragment the cache. The unit separator can't appear in the
    /// fields, so a title can't collide with an artist.
    static func key(title: String, artist: String, album: String?) -> String {
        func normalized(_ value: String) -> String {
            value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return [normalized(title), normalized(artist), normalized(album ?? "")].joined(separator: "\u{1F}")
    }

    func value(forKey key: String) -> LyricsResult? {
        loadIfNeeded()
        guard let result = entries[key] else {
            return nil
        }
        touch(key)
        return result
    }

    func insert(_ result: LyricsResult, forKey key: String) {
        // Never cache a miss — it must stay retryable so a transient failure doesn't
        // permanently suppress a later successful lookup.
        guard result != .notFound else {
            return
        }
        loadIfNeeded()
        entries[key] = result
        touch(key)
        evictIfNeeded()
        persist()
    }

    private func touch(_ key: String) {
        lru.removeAll { $0 == key }
        lru.append(key)
    }

    private func evictIfNeeded() {
        while lru.count > capacity, let oldest = lru.first {
            lru.removeFirst()
            entries[oldest] = nil
        }
    }

    /// Loads the on-disk cache into memory once, on first access. A missing or
    /// corrupt file simply starts the cache empty — never a crash.
    private func loadIfNeeded() {
        guard !didLoad else {
            return
        }
        didLoad = true
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL),
              let stored = try? JSONDecoder().decode([StoredEntry].self, from: data) else {
            return
        }
        for entry in stored {
            entries[entry.key] = entry.result
            lru.append(entry.key)
        }
    }

    /// Writes the whole cache back to disk (LRU order preserved). Best-effort: a
    /// failed write just means the next launch re-fetches.
    private func persist() {
        guard let fileURL else {
            return
        }
        // The default Caches directory always exists, but an injected one might not —
        // create it first so the write doesn't silently fail and drop the cache.
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        let stored = lru.compactMap { key in entries[key].map { StoredEntry(key: key, result: $0) } }
        guard let data = try? JSONEncoder().encode(stored) else {
            return
        }
        try? data.write(to: fileURL, options: .atomic)
    }

    private struct StoredEntry: Codable {
        let key: String
        let result: LyricsResult
    }
}
