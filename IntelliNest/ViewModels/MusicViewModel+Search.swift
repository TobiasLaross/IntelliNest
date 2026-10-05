//
//  MusicViewModel+Search.swift
//  IntelliNest
//
//  Created by Tobias on 2026-09-20.
//

import Foundation

/// Music search, split out of `MusicViewModel` to keep that type focused on
/// speaker and group state. Two layers sit behind the one search field: an
/// instant, offline filter over the already-loaded library (see
/// `MusicViewModel+Library`) and the Music Assistant search reached here, fired a
/// beat after the user stops typing so the results are ready before they ask.
extension MusicViewModel {
    /// The query with surrounding whitespace removed — what every match and fetch
    /// actually runs on.
    var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Queues a background search for the current query, replacing any still-pending
    /// one so only the pause the user actually stopped at reaches Home Assistant.
    /// The results land in `searchSections` without opening the results sheet —
    /// typing on the music screen is usually a library filter, and a sheet jumping
    /// up mid-keystroke would bury what the user was reading.
    func scheduleSearch() {
        pendingSearchTask?.cancel()
        guard trimmedSearchText.count >= Self.minimumSearchLength else {
            pendingSearchTask = nil
            return
        }
        pendingSearchTask = Task { [weak self] in
            await self?.searchDebounce()
            guard !Task.isCancelled else {
                return
            }
            await self?.search(presentResults: false)
        }
    }

    /// Runs the search for the current query straight away, skipping the debounce.
    /// Enter on the music screen: the hits are already listed inline under the
    /// library, so Enter only makes them arrive sooner rather than opening a sheet.
    func searchNow() async {
        pendingSearchTask?.cancel()
        pendingSearchTask = nil
        guard trimmedSearchText.count >= Self.minimumSearchLength,
              lastCompletedSearchQuery != trimmedSearchText || isSearching else {
            return
        }
        await search(presentResults: false)
    }

    /// Runs the Music Assistant search. `presentResults` distinguishes the two
    /// callers: an explicit search (Enter in the results sheet, or "Visa alla" on
    /// an inline category) opens the results sheet and reports failures, while the
    /// background search only fills `searchSections`.
    func search(presentResults: Bool = true) async {
        let query = trimmedSearchText
        guard query.isNotEmpty else {
            searchSections = []
            hasSearched = false
            lastCompletedSearchQuery = nil
            return
        }

        if presentResults {
            openedPlaylist = nil
            openedArtist = nil
            isShowingSearchResults = true
            // The background search may already have fetched this exact query while
            // the user was typing — show those results instead of refetching them.
            if lastCompletedSearchQuery == query, !isSearching {
                return
            }
        }

        searchRequestToken += 1
        let token = searchRequestToken
        isSearching = true
        hasSearched = true
        do {
            let response = try await restAPIService.searchMusic(query: query)
            guard token == searchRequestToken else {
                return
            }
            searchSections = sectionsPinningLibraryPlaylists(response.sections, query: query)
            lastCompletedSearchQuery = query
        } catch {
            guard token == searchRequestToken else {
                return
            }
            Log.error("Music search failed: \(error)")
            searchSections = []
            hasSearched = false
            lastCompletedSearchQuery = nil
            // A background search fails quietly: the user hasn't asked for results
            // yet, and a banner thrown mid-keystroke is noise they can't act on.
            if presentResults {
                isShowingSearchResults = false
                setErrorBannerText("Sökningen misslyckades", "Kunde inte söka efter musik")
            }
        }
        if token == searchRequestToken {
            isSearching = false
        }
    }

    /// Loads an artist's or album's children for the browse list the user drilled
    /// into. Read-only — browsing never changes what's playing, which is the whole
    /// point of opening an artist instead of tapping it to play. Returns empty and
    /// banners on failure so the view shows its empty state rather than a spinner
    /// that never resolves.
    func browseItems(for item: MusicSearchItem) async -> [MusicSearchItem] {
        guard let browseSpeaker = activeSpeakerID ?? availableSpeakers.first?.entityId else {
            return []
        }
        do {
            return try await restAPIService.browseArtistItems(uri: item.uri, mediaType: item.mediaType, on: browseSpeaker)
        } catch {
            Log.error("Failed to browse \(item.mediaType.rawValue): \(error)")
            setErrorBannerText("Kunde inte öppna \(item.name)", "Det gick inte att hämta innehållet")
            return []
        }
    }

    /// The Spotify hits listed under the library matches on the music screen, so a
    /// search shows everything at once instead of behind a "search Spotify" tap.
    /// Playlists already listed above as library matches are left out rather than
    /// shown twice. Empty until the search for the query in the field has
    /// finished, so an older query's hits never sit under a newer query.
    var inlineSearchSections: [MusicSearchSection] {
        let query = trimmedSearchText
        guard query.count >= Self.minimumSearchLength, lastCompletedSearchQuery == query else {
            return []
        }
        let libraryURIs = Set(librarySections.flatMap(\.playlists).map(\.uri))
        return searchSections.compactMap { section in
            let items = section.items.filter { !libraryURIs.contains($0.uri) }
            guard items.isNotEmpty else {
                return nil
            }
            return MusicSearchSection(mediaType: section.mediaType, items: items)
        }
    }

    var hasNoResults: Bool {
        hasSearched && !isSearching && searchSections.isEmpty
    }

    /// The search screen's results as one mixed list: the user's own matching
    /// playlists and the Spotify hits, each row labelled with its type. Under
    /// "Allt" (`filter` nil) the types are taken in turns — the best artist, the
    /// best library playlist, the best track, the best album, the best playlist,
    /// then everyone's second best — so the top of the list holds the strongest
    /// hit of every kind without trying to rank an artist against a song, which
    /// Music Assistant's per-type relevance can't do. A filter lists that one type
    /// in full, with library playlists leading Spellistor.
    func searchHits(filter: MusicMediaType?) -> [MusicSearchHit] {
        let library = isFilteringLibrary ? matchingLibraryPlaylists(query: trimmedSearchText) : []
        let sections = inlineSearchSections
        let remote = { (mediaType: MusicMediaType) in
            (sections.first { $0.mediaType == mediaType }?.items ?? [])
                .map { MusicSearchHit(item: $0, isInLibrary: false) }
        }
        var columns = [
            remote(.artist),
            library.map { MusicSearchHit(item: $0, isInLibrary: true) },
            remote(.track),
            remote(.album),
            remote(.playlist)
        ]
        if let filter {
            columns = columns.map { column in column.filter { $0.item.mediaType == filter } }
        }
        let interleaved = filter == nil ? Self.interleave(columns) : columns.flatMap(\.self)
        // Music Assistant can return one artist or track twice — once from its own
        // library, once from Spotify — under different uris, so a hit is a repeat
        // when its type, name and artist all match one already listed.
        var seen: Set<String> = []
        return interleaved.filter { hit in
            let item = hit.item
            let key = [item.mediaType.rawValue, normalizedName(item.name), normalizedName(item.artist ?? "")]
            return seen.insert(key.joined(separator: "|")).inserted && seen.insert(item.uri).inserted
        }
    }

    /// The filter buttons worth showing: only the types the current results hold.
    var searchFilters: [MusicMediaType] {
        let available = Set(searchHits(filter: nil).map(\.item.mediaType))
        return MusicMediaType.allCases.filter { available.contains($0) }
    }

    /// What tapping a search hit does. A track plays; anything else opens its own
    /// screen, so a stray tap on an artist or playlist can't replace the queue.
    func open(_ item: MusicSearchItem) async {
        switch item.mediaType {
        case .track:
            await play(item: item)
        case .playlist:
            await browseLibraryPlaylist(item)
        case .artist, .album:
            browsingArtist = item
        }
    }

    private static func interleave(_ columns: [[MusicSearchHit]]) -> [MusicSearchHit] {
        let depth = columns.map(\.count).max() ?? 0
        return (0 ..< depth).flatMap { rank in
            columns.compactMap { column in rank < column.count ? column[rank] : nil }
        }
    }

    /// Moves the user's own matching playlists to the top of the Spellistor results.
    /// Searching "Brynäs" should surface the Brynäs playlist on the sofa, not a
    /// stranger's — Music Assistant ranks by its own relevance and has no idea which
    /// playlists are in the house. Remote hits for the same playlist are dropped so
    /// it isn't listed twice; they are matched by name as well as uri because the
    /// library copy and the search hit can carry different provider uris.
    private func sectionsPinningLibraryPlaylists(_ sections: [MusicSearchSection], query: String) -> [MusicSearchSection] {
        let pinned = matchingLibraryPlaylists(query: query)
        guard pinned.isNotEmpty else {
            return sections
        }
        var itemsByType: [MusicMediaType: [MusicSearchItem]] = [:]
        for section in sections {
            itemsByType[section.mediaType] = section.items
        }
        let pinnedURIs = Set(pinned.map(\.uri))
        let pinnedNames = Set(pinned.map { normalizedName($0.name) })
        let remote = (itemsByType[.playlist] ?? []).filter {
            !pinnedURIs.contains($0.uri) && !pinnedNames.contains(normalizedName($0.name))
        }
        itemsByType[.playlist] = pinned + remote
        // Rebuild in the canonical media-type order rather than the response's.
        return MusicMediaType.allCases.compactMap { mediaType in
            guard let items = itemsByType[mediaType], items.isNotEmpty else {
                return nil
            }
            return MusicSearchSection(mediaType: mediaType, items: items)
        }
    }
}
