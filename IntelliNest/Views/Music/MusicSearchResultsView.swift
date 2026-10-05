//
//  MusicSearchResultsView.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-09.
//

import SwiftUI

/// The results for the query in the search field, as one mixed list: the house's
/// matching playlists (badged "Bibliotek") and the Spotify hits, each row saying
/// what it is. Filter buttons above narrow it to one type in full.
struct MusicSearchResultsView: View {
    @ObservedObject var viewModel: MusicViewModel
    /// Called with every hit the user taps, so the search screen can remember it.
    let onPick: (MusicSearchItem) -> Void
    @State private var filter: MusicMediaType?

    /// `filter` is seeded only by previews and render tests; the app always opens
    /// the results on "Allt".
    init(viewModel: MusicViewModel, onPick: @escaping (MusicSearchItem) -> Void, filter: MusicMediaType? = nil) {
        self.viewModel = viewModel
        self.onPick = onPick
        _filter = State(initialValue: filter)
    }

    var body: some View {
        let filters = viewModel.searchFilters
        // A filter whose type the new query no longer returns falls back to "Allt".
        let activeFilter = filter.flatMap { filters.contains($0) ? $0 : nil }
        let hits = viewModel.searchHits(filter: activeFilter)
        VStack(alignment: .leading, spacing: 4) {
            // Pinned above the list, so the filters stay in reach however far down
            // the user has scrolled.
            if filters.count > 1 {
                filterBar(filters, active: activeFilter)
                    .padding(.vertical, 8)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    MusicSearchHitList(items: hits) { hit in
                        row(hit.item, isInLibrary: hit.isInLibrary)
                    }
                    status(isEmpty: hits.isEmpty)
                }
                .padding(.bottom, 8)
            }
        }
    }

    private func filterBar(_ filters: [MusicMediaType], active: MusicMediaType?) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip("Allt", isActive: active == nil) { filter = nil }
                ForEach(filters, id: \.self) { mediaType in
                    filterChip(mediaType.swedishTitle, isActive: active == mediaType) { filter = mediaType }
                }
            }
        }
        // Let the row scroll out to the screen edge instead of being cut at the
        // screen's side padding, so the last button reads as "more to scroll".
        .scrollClipDisabled()
    }

    private func filterChip(_ title: String, isActive: Bool, action: @escaping MainActorVoidClosure) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isActive ? .semibold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .foregroundStyle(isActive ? Color.black : Color.white)
                .background(isActive ? Color.white : Color.white.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    @ViewBuilder private func row(_ item: MusicSearchItem, isInLibrary: Bool) -> some View {
        let hitRow = MusicSearchHitRow(item: item,
                                       isInLibrary: isInLibrary,
                                       isNowPlaying: item.mediaType == .playlist && viewModel.isNowPlaying(item)) {
            onPick(item)
            Task { await viewModel.open(item) }
        }
        if item.mediaType == .track {
            hitRow.contextMenu {
                TrackActionButtons(viewModel: viewModel,
                                   uri: item.uri,
                                   title: item.name,
                                   artist: item.artist,
                                   imageURL: item.imageURL)
            }
        } else {
            hitRow
        }
    }

    @ViewBuilder private func status(isEmpty: Bool) -> some View {
        if viewModel.isSearching, viewModel.inlineSearchSections.isEmpty {
            HStack(spacing: 8) {
                ProgressView()
                    .tint(.white)
                Text("Söker på Spotify…")
            }
            .foregroundStyle(.white.opacity(0.7))
        } else if isEmpty, viewModel.hasNoResults {
            Text("Inga träffar")
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

/// Rows separated by hairlines, without a card around them.
struct MusicSearchHitList<Item: Identifiable, Row: View>: View {
    let items: [Item]
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 8) {
                    row(item)
                }
                .padding(.vertical, 6)
                if index < items.count - 1 {
                    Divider()
                        .overlay(Color.white.opacity(0.08))
                }
            }
        }
    }
}

/// One search hit or recent pick: artwork (round for an artist), the name, and
/// a "Låt · Victor Leksell"-style subtitle saying what the row is.
struct MusicSearchHitRow: View {
    let item: MusicSearchItem
    var isInLibrary = false
    var isNowPlaying = false
    /// Play for a track, a chevron for anything that opens a screen.
    var showsTrailingImage = true
    let onTap: MainActorVoidClosure

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                AlbumArtView(urlString: item.imageURL, size: 44, isCircular: item.mediaType == .artist)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body)
                        .foregroundStyle(isNowPlaying ? .green : .white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        if isInLibrary {
                            Text("Bibliotek")
                                .font(.caption2.weight(.bold))
                                .textCase(.uppercase)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                        }
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                if isNowPlaying {
                    NowPlayingIndicator()
                }
                if showsTrailingImage {
                    Image(systemName: item.mediaType == .track ? "play.fill" : "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .accessibilityLabel(isInLibrary ? "\(item.name), \(subtitle), i biblioteket" : "\(item.name), \(subtitle)")
        .accessibilityValue(isNowPlaying ? "Spelas nu" : "")
    }

    private var subtitle: String {
        [item.mediaType.swedishSingular, item.artist].compactMap(\.self).joined(separator: " · ")
    }
}

extension Text {
    /// The small uppercase label over a block of search rows.
    func musicSearchSectionLabel() -> some View {
        font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .kerning(0.6)
            .foregroundStyle(.white.opacity(0.6))
    }
}
