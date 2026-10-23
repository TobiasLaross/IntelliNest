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
/// is, with the controlled room's mini player under it so the music can be sent
/// to another room without leaving the search. The player steps aside while the
/// keyboard is up, so the field sits right on the keys and the list keeps its
/// room. Before a query is typed it lists the items recently picked from the
/// results, newest nearest the field.
struct MusicSearchView: View {
    @ObservedObject var viewModel: MusicViewModel
    @ObservedObject var recentSearches: RecentMusicSearches
    let onClose: MainActorVoidClosure
    /// Starts false even though the field focuses on appear: with a hardware keyboard
    /// no notification arrives, and the player must not stay hidden.
    @State private var isKeyboardVisible = false

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

            if !isKeyboardVisible {
                speakerSelection
                    .padding(.bottom, 4)
            }
        }
        .tracksKeyboardVisibility($isKeyboardVisible)
    }

    @ViewBuilder private var speakerSelection: some View {
        if viewModel.miniPlayerRooms.isNotEmpty {
            MiniPlayerView(viewModel: viewModel)
        } else {
            // Nothing is playing and no room is controlled yet, so there is no
            // player to show; offer the room picker on its own.
            Button {
                viewModel.isShowingSpeakerPicker = true
            } label: {
                Label("Välj rum", systemImage: "hifispeaker.2")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}

/// The recent picks, stacked upward from the search field so the newest one sits
/// closest to the thumb. Tapping one does what tapping it in the results did.
struct RecentMusicPicksView: View {
    @ObservedObject var viewModel: MusicViewModel
    @ObservedObject var recentSearches: RecentMusicSearches
    /// The pick whose tap is still being carried out, so its row shows a spinner.
    @State private var startingURI: String?

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
                    MusicSearchHitRow(item: item,
                                      isNowPlaying: viewModel.isNowPlayingHit(item),
                                      isStarting: startingURI == item.uri,
                                      showsTrailingImage: false) {
                        recentSearches.record(item)
                        Task {
                            startingURI = item.uri
                            await viewModel.open(item)
                            // A later tap may have taken over the spinner meanwhile.
                            if startingURI == item.uri {
                                startingURI = nil
                            }
                        }
                    }
                    .trackActionsMenu(for: item, viewModel: viewModel)
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
