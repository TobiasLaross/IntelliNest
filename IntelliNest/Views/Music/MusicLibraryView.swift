//
//  MusicLibraryView.swift
//  IntelliNest
//
//  Created by Tobias on 2026-09-20.
//

import SwiftUI

/// A titled card of library playlists — recently played, the huset favourites, or
/// one person's own playlists. Only the first few rows are shown; the rest sit
/// behind "Visa alla", which opens the whole section with its own filter. While
/// the music screen's search field is filtering, every match is shown instead, so
/// a search never hides a hit behind a button.
struct LibraryPlaylistsSection: View {
    @ObservedObject var viewModel: MusicViewModel
    let section: MusicLibrarySection
    let onShowAll: MainActorVoidClosure

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
                .font(.headline)
            ForEach(viewModel.collapsedPlaylists(in: section)) { playlist in
                LibraryPlaylistRow(
                    viewModel: viewModel,
                    playlist: playlist,
                    onOpen: { Task { await viewModel.browseLibraryPlaylist(playlist) } }
                )
                .contextMenu {
                    if viewModel.canPinPlaylists(in: section), viewModel.isPinned(playlist, in: section) {
                        Button("Lossa från musiksidan", systemImage: "pin.slash") {
                            viewModel.togglePin(playlist, in: section)
                        }
                    }
                }
            }
            if hiddenCount > 0 {
                showAllButton
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private var hiddenCount: Int {
        viewModel.hiddenPlaylistCount(in: section)
    }

    private var showAllButton: some View {
        Button(action: onShowAll) {
            HStack(spacing: 4) {
                Text("Visa alla (\(section.playlists.count))")
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white.opacity(0.7))
            .padding(.top, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Visa alla \(section.playlists.count) spellistor i \(section.title)")
    }
}

/// A single playlist row. Tapping the row opens the playlist detail
/// (Spotify-style), where playback lives. Spotify-resolvable playlists also show
/// a favourite star — filled for ones already in the library (the "Favoriter"
/// rows are always filled; tapping un-favorites), empty and tappable-to-save for
/// a recently-played playlist that isn't saved yet. Non-Spotify rows keep the
/// plain chevron.
struct LibraryPlaylistRow: View {
    @ObservedObject var viewModel: MusicViewModel
    let playlist: MusicSearchItem
    /// Set only in the "Visa alla" listing, where each row gets a pin that picks
    /// which playlists the section shows on the music start screen.
    var pinSection: MusicLibrarySection?
    let onOpen: MainActorVoidClosure

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    AlbumArtView(urlString: playlist.imageURL, size: 48)
                    Text(playlist.name)
                        .font(.body)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(playlist.name)
            .accessibilityHint("Öppna spellistan")

            if let pinSection {
                pinButton(in: pinSection)
            }

            if viewModel.canFavoritePlaylist(playlist) {
                favoriteStar
            } else {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .foregroundStyle(.white)
    }

    private func pinButton(in section: MusicLibrarySection) -> some View {
        let pinned = viewModel.isPinned(playlist, in: section)
        return Button {
            viewModel.togglePin(playlist, in: section)
        } label: {
            Image(systemName: pinned ? "pin.fill" : "pin")
                .foregroundStyle(pinned ? .white : .white.opacity(0.6))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canPin(playlist, in: section))
        .opacity(viewModel.canPin(playlist, in: section) ? 1 : 0.3)
        .accessibilityLabel(pinned ? "Lossa \(playlist.name) från musiksidan" : "Fäst \(playlist.name) på musiksidan")
    }

    private var favoriteStar: some View {
        let saved = viewModel.isSaved(playlist)
        return Button {
            Task { await viewModel.toggleFavorite(playlist) }
        } label: {
            Image(systemName: saved ? "star.fill" : "star")
                .foregroundStyle(saved ? .yellow : .white.opacity(0.6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(saved ? "Ta bort \(playlist.name) från favoriter" : "Lägg till \(playlist.name) i favoriter")
    }
}

/// One library section in full, opened from "Visa alla". Carries its own filter
/// field so a long section — Tobias's own playlists, typically the longest — can
/// be narrowed without backing out to the music screen first. Tapping a playlist
/// pushes its detail inside this sheet rather than stacking another one.
struct MusicLibraryListView: View {
    @ObservedObject var viewModel: MusicViewModel
    let section: MusicLibrarySection
    @State private var filterText: String
    @State private var openedPlaylist: MusicSearchItem?

    /// `filterText` is seeded only by previews and render tests; the app always
    /// opens the listing unfiltered.
    init(viewModel: MusicViewModel, section: MusicLibrarySection, filterText: String = "") {
        self.viewModel = viewModel
        self.section = section
        _filterText = State(initialValue: filterText)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                MusicSearchBar(searchText: $filterText,
                               prompt: "Filtrera \(section.title.lowercased())",
                               onSubmit: {})
                    .padding(.horizontal)
                    .padding(.top, 12)
                if viewModel.canPinPlaylists(in: section) {
                    pinHint
                }
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .backgroundModifier()
            .foregroundStyle(.white)
            .navigationTitle(section.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Stäng") { viewModel.expandedLibrarySection = nil }
                        .foregroundStyle(.white)
                }
            }
            .navigationDestination(item: $openedPlaylist) { playlist in
                MusicPlaylistView(viewModel: viewModel, playlist: playlist)
            }
        }
    }

    @ViewBuilder private var content: some View {
        if filtered.isEmpty {
            Text("Inga träffar")
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 40)
            Spacer()
        } else {
            List(filtered) { playlist in
                LibraryPlaylistRow(
                    viewModel: viewModel,
                    playlist: playlist,
                    pinSection: viewModel.canPinPlaylists(in: section) ? section : nil,
                    onOpen: { Task { await open(playlist) } }
                )
                .musicListRow()
            }
            .musicListStyle()
        }
    }

    private var pinHint: some View {
        let pinnedCount = viewModel.pinnedPlaylists(in: section).count
        return Label("Fäst upp till \(MusicViewModel.collapsedLibraryRowCount) spellistor att visa på musiksidan "
            + "(\(pinnedCount)/\(MusicViewModel.collapsedLibraryRowCount))",
            systemImage: "pin")
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.7))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
    }

    private var filtered: [MusicSearchItem] {
        let query = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isNotEmpty else {
            return section.playlists
        }
        return section.playlists.filter { viewModel.matchesLibrarySearch($0.name, query: query) }
    }

    private func open(_ playlist: MusicSearchItem) async {
        openedPlaylist = playlist
        await viewModel.loadPlaylistTracks(playlist)
    }
}

/// The Spotify hits listed under the filtered library, one card per category,
/// so a search shows the house's own playlists and everything else together
/// without a tap in between. Each card shows the first few hits; "Visa alla"
/// opens the full results sheet on that category.
struct SpotifySearchResultsSections: View {
    @ObservedObject var viewModel: MusicViewModel
    let onShowAll: (MusicMediaType) -> Void

    var body: some View {
        let sections = viewModel.inlineSearchSections
        if sections.isEmpty {
            status
        } else {
            ForEach(sections) { section in
                card(section)
            }
        }
    }

    @ViewBuilder private var status: some View {
        if viewModel.isSearching {
            HStack(spacing: 8) {
                ProgressView()
                    .tint(.white)
                Text("Söker på Spotify…")
            }
            .foregroundStyle(.white.opacity(0.7))
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if viewModel.hasNoResults {
            Text("Inga träffar på Spotify")
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func card(_ section: MusicSearchSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(section.mediaType.swedishTitle) på Spotify")
                .font(.headline)
            ForEach(section.items.prefix(MusicViewModel.overviewRowCount)) { item in
                row(item)
            }
            if section.items.count > MusicViewModel.overviewRowCount {
                showAllButton(section)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    /// Same behaviour as the results sheet: a track plays, anything else opens
    /// its own screen so a stray tap can't replace the queue.
    @ViewBuilder private func row(_ item: MusicSearchItem) -> some View {
        switch item.mediaType {
        case .track:
            MusicMediaRow(name: item.name, subtitle: item.artist, imageURL: item.imageURL) {
                Task { await viewModel.play(item: item) }
            }
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
                          trailingSystemImage: "chevron.right") {
                Task { await viewModel.browseLibraryPlaylist(item) }
            }
        case .artist, .album:
            MusicMediaRow(name: item.name,
                          subtitle: item.artist,
                          imageURL: item.imageURL,
                          trailingSystemImage: "chevron.right") {
                viewModel.browsingArtist = item
            }
        }
    }

    private func showAllButton(_ section: MusicSearchSection) -> some View {
        Button {
            onShowAll(section.mediaType)
        } label: {
            HStack(spacing: 4) {
                Text("Visa alla (\(section.items.count))")
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white.opacity(0.7))
            .padding(.top, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Visa alla \(section.items.count) \(section.mediaType.swedishTitle.lowercased()) på Spotify")
    }
}
