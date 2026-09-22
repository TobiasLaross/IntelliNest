//
//  MusicSearchResultsView.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-09.
//

import SwiftUI

/// Which slice of the search results is on screen. "Allt" leads because a search
/// is usually for one specific thing and the user shouldn't have to guess which
/// category Music Assistant filed it under — the old view opened on Låtar, so
/// finding a playlist started with noticing the picker and tapping across.
enum MusicSearchTab: Hashable, Identifiable {
    case all
    case mediaType(MusicMediaType)

    var id: String {
        switch self {
        case .all:
            "all"
        case let .mediaType(mediaType):
            mediaType.rawValue
        }
    }

    var swedishTitle: String {
        switch self {
        case .all:
            "Allt"
        case let .mediaType(mediaType):
            mediaType.swedishTitle
        }
    }
}

/// Presents the search results in their own sheet: an "Allt" overview plus a tab
/// per media-type category (Låtar / Album / Artister / Spellistor). Shows a
/// spinner while the search runs and a Swedish "no results" state when nothing
/// matched. A playlist or artist drills in rather than playing immediately.
struct MusicSearchResultsView: View {
    @ObservedObject var viewModel: MusicViewModel
    @State private var selectedTab: MusicSearchTab

    /// `initialTab` is the category whose "Visa alla" opened the sheet.
    init(viewModel: MusicViewModel, initialTab: MusicSearchTab = .all) {
        self.viewModel = viewModel
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Keep an editable search bar in the sheet so a new query can be
                // run without dismissing the results popup first.
                MusicSearchBar(searchText: $viewModel.searchText,
                               prompt: "Sök på Spotify",
                               onSubmit: { Task { await viewModel.search() } })
                    .padding(.horizontal)
                    .padding(.top, 12)
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .backgroundModifier()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Stäng") { viewModel.closeSearchResults() }
                        .foregroundStyle(.white)
                }
            }
            .navigationDestination(item: $viewModel.openedPlaylist) { playlist in
                MusicPlaylistView(viewModel: viewModel, playlist: playlist)
            }
            .navigationDestination(item: $viewModel.openedArtist) { artist in
                MusicArtistView(viewModel: viewModel, item: artist)
            }
        }
        // Typing in the sheet's field searches on its own after a short pause, so
        // the results follow the query without a trip to the keyboard's Sök key.
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.scheduleSearch()
        }
    }

    @ViewBuilder private var content: some View {
        if viewModel.isSearching, viewModel.searchSections.isEmpty {
            ProgressView()
                .tint(.white)
                .padding(.top, 40)
            Spacer()
        } else if viewModel.hasNoResults {
            Text("Inga resultat")
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 40)
            Spacer()
        } else {
            VStack(spacing: 12) {
                categoryPicker
                    .padding(.horizontal)
                resultsList
            }
        }
    }

    private var categoryPicker: some View {
        Picker("Kategori", selection: selectionBinding) {
            ForEach(tabs) { tab in
                Text(tab.swedishTitle).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    /// "Allt" first, then one tab per category the search actually returned.
    private var tabs: [MusicSearchTab] {
        [.all] + viewModel.searchSections.map { MusicSearchTab.mediaType($0.mediaType) }
    }

    /// The sections shown under the current tab: a trimmed overview of every
    /// category under "Allt", or the one category in full.
    private var visibleSections: [MusicSearchSection] {
        switch resolvedTab {
        case .all:
            viewModel.searchOverviewSections
        case let .mediaType(mediaType):
            viewModel.searchSections.filter { $0.mediaType == mediaType }
        }
    }

    private var resultsList: some View {
        List {
            ForEach(visibleSections) { section in
                Section {
                    ForEach(section.items) { item in
                        resultRow(item)
                    }
                } header: {
                    // Under a single-category tab the picker already says which
                    // category this is; only the overview needs headings.
                    if resolvedTab == .all {
                        Text(section.mediaType.swedishTitle)
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .musicListStyle()
    }

    /// A track plays and can be swiped into the queue. A playlist or artist opens
    /// its own screen — playing an artist on a stray tap wipes the current queue,
    /// which is exactly what a mistyped search shouldn't do.
    @ViewBuilder private func resultRow(_ item: MusicSearchItem) -> some View {
        switch item.mediaType {
        case .track:
            MusicMediaRow(name: item.name, subtitle: item.artist, imageURL: item.imageURL) {
                Task { await viewModel.play(item: item) }
            }
            .musicListRow()
            .queueSwipeActions(viewModel: viewModel,
                               uri: item.uri,
                               title: item.name,
                               artist: item.artist,
                               imageURL: item.imageURL)
            .contextMenu {
                TrackActionButtons(viewModel: viewModel,
                                   uri: item.uri,
                                   title: item.name,
                                   artist: item.artist,
                                   imageURL: item.imageURL)
            }
        case .playlist:
            MusicMediaRow(name: item.name,
                          subtitle: item.artist,
                          imageURL: item.imageURL,
                          trailingSystemImage: "chevron.right",
                          isNowPlaying: viewModel.isNowPlaying(item)) {
                Task { await viewModel.openPlaylist(item) }
            }
            .musicListRow()
        case .artist, .album:
            MusicMediaRow(name: item.name,
                          subtitle: item.artist,
                          imageURL: item.imageURL,
                          trailingSystemImage: "chevron.right") {
                viewModel.openedArtist = item
            }
            .musicListRow()
        }
    }

    /// The selected tab, falling back to "Allt" when the previous selection is no
    /// longer present (e.g. the new query returned no artists).
    private var resolvedTab: MusicSearchTab {
        tabs.contains(selectedTab) ? selectedTab : .all
    }

    private var selectionBinding: Binding<MusicSearchTab> {
        Binding(get: { resolvedTab }, set: { selectedTab = $0 })
    }
}
