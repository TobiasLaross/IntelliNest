//
//  MusicSearchResultsView.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-09.
//

import SwiftUI

/// Presents the search results in their own sheet with a tab per media-type
/// category (Låtar / Album / Artister / Spellistor). Shows a spinner while the
/// search runs and a Swedish "no results" state when nothing matched. Tapping a
/// playlist drills into ``MusicPlaylistView`` rather than playing immediately.
struct MusicSearchResultsView: View {
    @ObservedObject var viewModel: MusicViewModel
    @State private var selectedType: MusicMediaType?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Keep an editable search bar in the sheet so a new query can be
                // run without dismissing the results popup first.
                MusicSearchBar(searchText: $viewModel.searchText,
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
        }
    }

    @ViewBuilder private var content: some View {
        if viewModel.isSearching {
            ProgressView()
                .tint(.white)
                .padding(.top, 40)
        } else if viewModel.hasNoResults {
            Text("Inga resultat")
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 40)
        } else {
            VStack(spacing: 16) {
                categoryPicker
                resultsList
            }
            .padding(.horizontal)
        }
    }

    private var categoryPicker: some View {
        Picker("Kategori", selection: selectionBinding) {
            ForEach(viewModel.searchSections) { section in
                Text(section.mediaType.swedishTitle).tag(section.mediaType)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder private var resultsList: some View {
        if let section = currentSection {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(section.items) { item in
                        if item.mediaType == .playlist {
                            // A playlist opens its track list instead of playing.
                            MusicResultRow(viewModel: viewModel, item: item, trailingSystemImage: "chevron.right") {
                                Task { await viewModel.openPlaylist(item) }
                            }
                        } else {
                            MusicResultRow(viewModel: viewModel, item: item) {
                                Task { await viewModel.play(item: item) }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    /// The currently selected category's section, falling back to the first
    /// available category when nothing is selected yet or the previous
    /// selection is no longer present (e.g. after a fresh search).
    private var currentSection: MusicSearchSection? {
        viewModel.searchSections.first { $0.mediaType == resolvedType }
    }

    private var resolvedType: MusicMediaType {
        if let selectedType, viewModel.searchSections.contains(where: { $0.mediaType == selectedType }) {
            return selectedType
        }
        return viewModel.searchSections.first?.mediaType ?? .track
    }

    private var selectionBinding: Binding<MusicMediaType> {
        Binding(get: { resolvedType }, set: { selectedType = $0 })
    }
}

/// The drill-in view for a playlist: a header with cover art and a play button
/// that plays the whole list, plus the track list where tapping a song plays
/// that song followed by the rest of the playlist.
struct MusicPlaylistView: View {
    @ObservedObject var viewModel: MusicViewModel
    let playlist: MusicSearchItem

    var body: some View {
        VStack(spacing: 16) {
            header
            trackList
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .backgroundModifier()
        .foregroundStyle(.white)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadSavedState(for: playlist) }
        .toolbar {
            // No principal title here on purpose — the full playlist name is shown
            // large in the header below, so a cramped, truncated nav-bar copy adds
            // nothing. Keep only the favourite star.
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.canFavoritePlaylist(playlist) {
                    favoriteButton
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            AlbumArtView(urlString: playlist.imageURL, size: 140)
            Text(playlist.name)
                .font(.title3)
                .bold()
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                capsuleButton(title: "Spela", systemImage: "play.fill") {
                    await viewModel.playPlaylist(playlist)
                }
                .accessibilityLabel("Spela spellistan \(playlist.name)")
                capsuleButton(title: "Shuffle", systemImage: "shuffle") {
                    await viewModel.playPlaylistShuffled(playlist)
                }
                .accessibilityLabel("Spela spellistan \(playlist.name) blandat")
            }
        }
        .padding(.top, 12)
    }

    /// The favourite star. Filled and yellow when favourited in Music Assistant,
    /// outlined otherwise. Toggling it adds/removes the MA favourite (which 2-way
    /// syncs to the Spotify follow).
    private var favoriteButton: some View {
        let saved = viewModel.isSaved(playlist)
        return Button {
            Task { await viewModel.toggleFavorite(playlist) }
        } label: {
            Image(systemName: saved ? "star.fill" : "star")
                .foregroundStyle(saved ? .yellow : .white)
        }
        .accessibilityLabel(saved ? "Ta bort från favoriter" : "Lägg till i favoriter")
    }

    private func capsuleButton(title: String,
                               systemImage: String,
                               action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .padding(.vertical, 10)
                .padding(.horizontal, 24)
                .background(Color.white.opacity(0.15))
                .clipShape(Capsule())
        }
    }

    @ViewBuilder private var trackList: some View {
        if viewModel.isLoadingPlaylist {
            ProgressView()
                .tint(.white)
                .padding(.top, 40)
            Spacer()
        } else if viewModel.playlistTracks.isEmpty {
            Text("Inga låtar")
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 40)
            Spacer()
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.playlistTracks) { track in
                        trackRow(track)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // Reflect each track's Liked-Songs state when the list loads.
            .task(id: viewModel.playlistTracks.map(\.uri).joined(separator: "|")) {
                await viewModel.loadSavedSongStates(uris: viewModel.playlistTracks.map(\.uri))
            }
        }
    }

    /// A playlist track row: tapping plays it (then the rest of the playlist),
    /// the trailing heart toggles Liked Songs, and a long-press exposes add to
    /// queue / add to playlist / remove from this playlist.
    private func trackRow(_ track: MusicPlaylistTrack) -> some View {
        // Only an editable playlist offers "remove from this playlist".
        var removeAction: MainActorVoidClosure?
        if viewModel.canEditPlaylist(playlist) {
            removeAction = { Task { await viewModel.removeTrack(track, fromPlaylist: playlist) } }
        }
        return HStack(spacing: 12) {
            Button {
                Task { await viewModel.playTrackInPlaylist(track, from: playlist) }
            } label: {
                HStack(spacing: 12) {
                    AlbumArtView(urlString: track.imageURL, size: 44)
                    Text(track.title)
                        .font(.body)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Spela \(track.title)")

            if viewModel.canFavoriteSong(uri: track.uri) {
                SongFavoriteButton(viewModel: viewModel, uri: track.uri)
            } else {
                Image(systemName: "play.fill")
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.vertical, 4)
        .foregroundStyle(.white)
        .contextMenu {
            TrackActionButtons(viewModel: viewModel,
                               uri: track.uri,
                               title: track.title,
                               imageURL: track.imageURL,
                               onRemoveFromPlaylist: removeAction)
        }
    }
}

private struct MusicResultRow: View {
    @ObservedObject var viewModel: MusicViewModel
    let item: MusicSearchItem
    var trailingSystemImage = "play.fill"
    let onTap: MainActorVoidClosure

    var body: some View {
        // A track also offers add-to-queue / add-to-playlist via long-press; the
        // other result types (album, artist, playlist) have no track actions.
        if item.mediaType == .track {
            rowButton.contextMenu {
                TrackActionButtons(viewModel: viewModel,
                                   uri: item.uri,
                                   title: item.name,
                                   artist: item.artist,
                                   imageURL: item.imageURL)
            }
        } else {
            rowButton
        }
    }

    private var rowButton: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                AlbumArtView(urlString: item.imageURL, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body)
                        .lineLimit(1)
                    if let artist = item.artist {
                        Text(artist)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: trailingSystemImage)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.vertical, 4)
        }
        .foregroundStyle(.white)
        .accessibilityLabel(item.mediaType == .playlist ? "Öppna \(item.name)" : "Spela \(item.name)")
    }
}
