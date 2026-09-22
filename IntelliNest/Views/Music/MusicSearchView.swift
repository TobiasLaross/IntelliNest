//
//  MusicSearchView.swift
//  IntelliNest
//
//  Created by Tobias on 2026-09-22.
//

import SwiftUI

/// The search screen the music start screen's search bar opens. It takes over the
/// whole screen — navigation bar included — so the only way out is the close
/// button, and the back arrow can no longer throw the user off the music screen
/// mid-search. Before a query is typed it lists the recent searches.
struct MusicSearchView: View {
    @ObservedObject var viewModel: MusicViewModel
    @ObservedObject var recentSearches: RecentMusicSearches
    let onShowAll: (MusicMediaType) -> Void
    let onClose: MainActorVoidClosure

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                MusicSearchBar(searchText: $viewModel.searchText,
                               focusesOnAppear: true,
                               onSubmit: submit)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Stäng sökningen")
            }
            .padding(.top, 8)

            ScrollView {
                MusicSearchContent(viewModel: viewModel, recentSearches: recentSearches, onShowAll: onShowAll)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func submit() {
        recentSearches.record(viewModel.searchText)
        Task { await viewModel.searchNow() }
    }
}

/// What sits under the search field: the recent searches while it is empty, the
/// library matches and Spotify hits once something is typed.
struct MusicSearchContent: View {
    @ObservedObject var viewModel: MusicViewModel
    @ObservedObject var recentSearches: RecentMusicSearches
    let onShowAll: (MusicMediaType) -> Void

    var body: some View {
        VStack(spacing: 16) {
            if viewModel.isFilteringLibrary {
                results
            } else {
                recents
            }
        }
    }

    @ViewBuilder private var results: some View {
        ForEach(viewModel.librarySections) { section in
            LibraryPlaylistsSection(viewModel: viewModel,
                                    section: section,
                                    onShowAll: { viewModel.expandedLibrarySection = section })
        }
        if viewModel.librarySections.isEmpty {
            Text("Inget i biblioteket matchar")
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        SpotifySearchResultsSections(viewModel: viewModel, onShowAll: onShowAll)
    }

    @ViewBuilder private var recents: some View {
        if recentSearches.queries.isEmpty {
            Text("Sök efter låtar, album, artister och spellistor")
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Senaste sökningar")
                        .font(.headline)
                    Spacer()
                    Button("Rensa") { recentSearches.clear() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.bottom, 4)
                ForEach(recentSearches.queries, id: \.self) { query in
                    recentRow(query)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
    }

    private func recentRow(_ query: String) -> some View {
        HStack(spacing: 12) {
            Button {
                viewModel.searchText = query
                recentSearches.record(query)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(.white.opacity(0.6))
                    Text(query)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            Button {
                recentSearches.remove(query)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Ta bort \(query) från senaste sökningar")
        }
        .foregroundStyle(.white)
    }
}
