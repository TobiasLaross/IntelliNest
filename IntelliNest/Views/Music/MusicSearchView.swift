//
//  MusicSearchView.swift
//  IntelliNest
//
//  Created by Tobias on 2026-09-22.
//

import SwiftUI

/// The search screen the music start screen's search bar opens. It takes over the
/// whole screen — navigation bar included — so the only way out is "Avbryt", and
/// the back arrow can no longer throw the user off the music screen mid-search.
/// The field sits at the bottom, on top of the keyboard, where the thumb already
/// is. Before a query is typed it lists the items recently picked from the
/// results, newest nearest the field.
struct MusicSearchView: View {
    @ObservedObject var viewModel: MusicViewModel
    @ObservedObject var recentSearches: RecentMusicSearches
    let onClose: MainActorVoidClosure

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if viewModel.isFilteringLibrary {
                    MusicSearchResultsView(viewModel: viewModel, onPick: recentSearches.record)
                } else {
                    RecentMusicPicksView(viewModel: viewModel, recentSearches: recentSearches)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .frame(maxHeight: .infinity)

            HStack(spacing: 12) {
                MusicSearchBar(searchText: $viewModel.searchText,
                               prompt: "Sök musik",
                               focusesOnAppear: true,
                               onSubmit: { Task { await viewModel.searchNow() } })
                Button("Avbryt", action: onClose)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                    .accessibilityLabel("Stäng sökningen")
            }
            .padding(.vertical, 8)
        }
    }
}

/// The recent picks, stacked upward from the search field so the newest one sits
/// closest to the thumb. Tapping one does what tapping it in the results did.
struct RecentMusicPicksView: View {
    @ObservedObject var viewModel: MusicViewModel
    @ObservedObject var recentSearches: RecentMusicSearches

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .bottom)
            }
            .defaultScrollAnchor(.bottom)
        }
    }

    @ViewBuilder private var content: some View {
        if recentSearches.items.isEmpty {
            Text("Sök efter låtar, album, artister och spellistor")
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Senaste")
                        .musicSearchSectionLabel()
                    Spacer()
                    Button("Rensa") { recentSearches.clear() }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .accessibilityLabel("Rensa senaste")
                }
                MusicSearchHitList(items: Array(recentSearches.items.reversed())) { item in
                    MusicSearchHitRow(item: item, showsTrailingImage: false) {
                        recentSearches.record(item)
                        Task { await viewModel.open(item) }
                    }
                    removeButton(item)
                }
            }
        }
    }

    private func removeButton(_ item: MusicSearchItem) -> some View {
        Button {
            recentSearches.remove(item)
        } label: {
            Image(systemName: "xmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ta bort \(item.name) från senaste")
    }
}
