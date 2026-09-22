//
//  MusicViewModel+Library.swift
//  IntelliNest
//
//  Created by Tobias on 2026-09-20.
//

import Foundation

/// One titled block of playlists on the music start screen. The three sources
/// (recently played, the huset favourites, and each person's own playlists) are
/// flattened to this so the view renders one list instead of four hand-wired
/// variants, and so the filter and the "Visa alla" drill-in work the same in all
/// of them.
struct MusicLibrarySection: Identifiable, Equatable {
    let id: String
    let title: String
    let playlists: [MusicSearchItem]
}

/// Persists which playlists each library section pins to the music start screen,
/// keyed by section id with the playlist URIs in the order they were pinned.
/// Closures rather than `UserDefaults` directly so tests keep the pins in memory.
struct PinnedPlaylistStore {
    let load: @MainActor () -> [String: [String]]
    let save: @MainActor ([String: [String]]) -> Void

    static let userDefaults = PinnedPlaylistStore(
        load: {
            UserDefaults.shared.dictionary(forKey: StorageKeys.pinnedMusicPlaylists.rawValue) as? [String: [String]] ?? [:]
        },
        save: {
            UserDefaults.shared.set($0, forKey: StorageKeys.pinnedMusicPlaylists.rawValue)
        }
    )
}

/// The start screen's library: which sections it shows, the instant filter over
/// them, and the full listing behind "Visa alla".
extension MusicViewModel {
    /// Rows a section shows before the rest go behind "Visa alla". Four keeps the
    /// whole screen — now-playing card included — inside one thumb-scroll while
    /// every section stays visible; before this, four fully-expanded sections
    /// pushed the later ones off the bottom entirely.
    static let collapsedLibraryRowCount = 4
    /// Characters needed before typing reaches Home Assistant. The library filter
    /// itself runs from the first character; only the network call waits.
    static let minimumSearchLength = 2
    /// Items per media type in the results sheet's "Allt" tab.
    static let overviewRowCount = 3
    static let recentlyPlayedSectionID = "recentlyPlayed"

    /// Every library section that has something in it, in display order: what was
    /// played most recently, the house favourites, then one section per person.
    var allLibrarySections: [MusicLibrarySection] {
        var sections = [
            MusicLibrarySection(id: Self.recentlyPlayedSectionID, title: "Senast spelade", playlists: recentlyPlayedPlaylists),
            MusicLibrarySection(id: "favorites", title: "Favoriter", playlists: favoritePlaylists)
        ]
        sections += personalPlaylistSections.map {
            MusicLibrarySection(id: $0.id, title: $0.title, playlists: $0.playlists)
        }
        return sections.filter(\.playlists.isNotEmpty)
    }

    /// Whether the search field currently narrows the library.
    var isFilteringLibrary: Bool {
        trimmedSearchText.isNotEmpty
    }

    /// The sections as rendered: everything while the field is empty, only the
    /// matching playlists while it isn't. A section with no match drops out rather
    /// than leaving an empty heading behind.
    var librarySections: [MusicLibrarySection] {
        guard isFilteringLibrary else {
            return allLibrarySections
        }
        let query = trimmedSearchText
        return allLibrarySections.compactMap { section in
            let matches = section.playlists.filter { matchesLibrarySearch($0.name, query: query) }
            guard matches.isNotEmpty else {
                return nil
            }
            return MusicLibrarySection(id: section.id, title: section.title, playlists: matches)
        }
    }

    /// Every distinct library playlist matching the query, across all sections.
    /// Pinned above the remote hits in the search sheet's Spellistor tab.
    func matchingLibraryPlaylists(query: String) -> [MusicSearchItem] {
        var seenURIs: Set<String> = []
        var matches: [MusicSearchItem] = []
        for playlist in allLibrarySections.flatMap(\.playlists) {
            guard matchesLibrarySearch(playlist.name, query: query), !seenURIs.contains(playlist.uri) else {
                continue
            }
            seenURIs.insert(playlist.uri)
            matches.append(playlist)
        }
        return matches
    }

    /// The rows a collapsed section shows, and whether it is holding any back.
    func collapsedPlaylists(in section: MusicLibrarySection) -> [MusicSearchItem] {
        // While filtering, every match is worth seeing — the list is short by
        // definition and hiding matches behind "Visa alla" defeats the search.
        guard !isFilteringLibrary else {
            return section.playlists
        }
        let pinned = pinnedPlaylists(in: section)
        let unpinned = section.playlists.filter { !pinned.contains($0) }
        return Array((pinned + unpinned).prefix(Self.collapsedLibraryRowCount))
    }

    func hiddenPlaylistCount(in section: MusicLibrarySection) -> Int {
        section.playlists.count - collapsedPlaylists(in: section).count
    }

    // MARK: - Recently played and now playing

    /// In-app plays remembered per session; more than a section's worth would
    /// only push Music Assistant's own history out of "Visa alla".
    static let sessionPlayedLimit = 5

    /// Rebuilds "Senast spelade": the playlist playing now first, then this
    /// session's in-app plays MA doesn't list, then MA's `last_played` order —
    /// deduped, so a playlist MA does know keeps a single row. Session plays MA
    /// already lists defer to MA's position, which also reflects plays started
    /// elsewhere after them.
    func applyRecentlyPlayed() {
        let unlistedSessionPlays = sessionPlayedPlaylists.filter { played in
            !maRecentlyPlayedPlaylists.contains { isSamePlaylist($0, played) }
        }
        var merged: [MusicSearchItem] = []
        for playlist in [nowPlayingSourcePlaylist].compactMap(\.self) + unlistedSessionPlays + maRecentlyPlayedPlaylists
            where !merged.contains(where: { isSamePlaylist($0, playlist) }) {
            merged.append(playlist)
        }
        recentlyPlayedPlaylists = merged
    }

    /// Whether two rows are the same playlist. By uri first; by name as the
    /// fallback, since one playlist reaches the app under different uris — a
    /// `library://playlist/<id>` from Music Assistant, a `spotify://playlist/<id>`
    /// from the Spotify listing.
    func isSamePlaylist(_ lhs: MusicSearchItem, _ rhs: MusicSearchItem) -> Bool {
        lhs.uri == rhs.uri || normalizedName(lhs.name) == normalizedName(rhs.name)
    }

    /// Whether `playlist` is what the active speaker is playing from right now,
    /// which marks its row in every library list. Only a playing speaker counts:
    /// a paused or idle one leaves the "Spelas från" breadcrumb but isn't playing
    /// anything to point at.
    func isNowPlaying(_ playlist: MusicSearchItem) -> Bool {
        guard let source = nowPlayingSourcePlaylist, activeSpeaker?.isPlaying == true else {
            return false
        }
        return isSamePlaylist(source, playlist)
    }

    // MARK: - Pinning

    /// "Senast spelade" is ordered by recency; pinning rows there would fight it.
    func canPinPlaylists(in section: MusicLibrarySection) -> Bool {
        section.id != Self.recentlyPlayedSectionID
    }

    /// The section's pinned playlists in pin order. A pin whose playlist has left
    /// the section (deleted, unfollowed) is skipped rather than holding a slot.
    func pinnedPlaylists(in section: MusicLibrarySection) -> [MusicSearchItem] {
        let pinnedURIs = pinnedPlaylistURIs[section.id] ?? []
        return pinnedURIs.compactMap { uri in section.playlists.first { $0.uri == uri } }
    }

    func isPinned(_ playlist: MusicSearchItem, in section: MusicLibrarySection) -> Bool {
        pinnedPlaylists(in: section).contains(playlist)
    }

    /// Pinning is capped at the rows the start screen shows, so a pin always
    /// means "visible on the start screen".
    func canPin(_ playlist: MusicSearchItem, in section: MusicLibrarySection) -> Bool {
        isPinned(playlist, in: section) || pinnedPlaylists(in: section).count < Self.collapsedLibraryRowCount
    }

    func togglePin(_ playlist: MusicSearchItem, in section: MusicLibrarySection) {
        // Resolve the unfiltered section: pruning against a filtered copy would
        // drop every pin that doesn't match the current search.
        let section = allLibrarySections.first { $0.id == section.id } ?? section
        // Rebuild from the live pins so stale URIs are pruned on every write.
        var pinnedURIs = pinnedPlaylists(in: section).map(\.uri)
        if let index = pinnedURIs.firstIndex(of: playlist.uri) {
            pinnedURIs.remove(at: index)
        } else if canPin(playlist, in: section) {
            pinnedURIs.append(playlist.uri)
        } else {
            return
        }
        pinnedPlaylistURIs[section.id] = pinnedURIs.isEmpty ? nil : pinnedURIs
        pinnedPlaylistStore.save(pinnedPlaylistURIs)
    }

    /// Case- and diacritic-insensitive substring match, so "lugnt" finds "Lugnt &
    /// Skönt" and "skont" finds it too — nobody reaches for the ö key mid-search.
    func matchesLibrarySearch(_ name: String, query: String) -> Bool {
        name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
