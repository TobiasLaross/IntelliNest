//
//  MusicArtistView.swift
//  IntelliNest
//
//  Created by Tobias on 2026-09-20.
//

import SwiftUI

/// The drill-in for an artist or an album. Opening one never changes what's
/// playing — before this, tapping an artist in the search results replaced the
/// whole queue on the spot, so a mistyped search could wipe the evening's music.
/// An artist's children are its albums and top tracks; an album's are its tracks,
/// and tapping an album pushes this same view one level deeper.
struct MusicArtistView: View {
    @ObservedObject var viewModel: MusicViewModel
    let item: MusicSearchItem
    @State private var items: [MusicSearchItem]
    @State private var isLoading: Bool
    @State private var openedAlbum: MusicSearchItem?

    /// `items`/`isLoading` are seeded only by previews and render tests, which have
    /// no `.task` to load them. The app always uses the defaults and lets the task
    /// fill the list.
    init(viewModel: MusicViewModel, item: MusicSearchItem, items: [MusicSearchItem] = [], isLoading: Bool = true) {
        self.viewModel = viewModel
        self.item = item
        _items = State(initialValue: items)
        _isLoading = State(initialValue: isLoading)
    }

    var body: some View {
        VStack(spacing: 16) {
            header
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .backgroundModifier()
        .foregroundStyle(.white)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            items = await viewModel.browseItems(for: item)
            isLoading = false
            await viewModel.loadSavedSongStates(uris: items.filter { $0.mediaType == .track }.map(\.uri))
        }
        .navigationDestination(item: $openedAlbum) { album in
            MusicArtistView(viewModel: viewModel, item: album)
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            AlbumArtView(urlString: item.imageURL, size: 140)
            Text(item.name)
                .font(.title3)
                .bold()
                .multilineTextAlignment(.center)
            Button {
                Task { await viewModel.play(item: item) }
            } label: {
                Label("Spela", systemImage: "play.fill")
                    .font(.headline)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 24)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Capsule())
            }
            .accessibilityLabel("Spela \(item.name)")
        }
        .padding(.top, 12)
        .padding(.horizontal)
    }

    @ViewBuilder private var content: some View {
        if isLoading {
            ProgressView()
                .tint(.white)
                .padding(.top, 40)
            Spacer()
        } else if items.isEmpty {
            Text("Inget att visa")
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 40)
            Spacer()
        } else {
            List(items) { child in
                row(child)
            }
            .musicListStyle()
        }
    }

    /// A track plays on tap and can be swiped into the queue; an album pushes
    /// deeper instead of playing, for the same reason the artist itself does.
    @ViewBuilder private func row(_ child: MusicSearchItem) -> some View {
        if child.mediaType == .track {
            MusicMediaRow(name: child.name,
                          subtitle: child.artist,
                          imageURL: child.imageURL) {
                Task { await viewModel.play(item: child) }
            }
            .musicListRow()
            .queueSwipeActions(viewModel: viewModel,
                               uri: child.uri,
                               title: child.name,
                               artist: child.artist,
                               imageURL: child.imageURL)
            .contextMenu {
                TrackActionButtons(viewModel: viewModel,
                                   uri: child.uri,
                                   title: child.name,
                                   artist: child.artist,
                                   imageURL: child.imageURL)
            }
        } else {
            MusicMediaRow(name: child.name,
                          subtitle: child.mediaType.swedishTitle,
                          imageURL: child.imageURL,
                          trailingSystemImage: "chevron.right") {
                openedAlbum = child
            }
            .musicListRow()
        }
    }
}
