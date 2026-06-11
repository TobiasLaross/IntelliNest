//
//  QueueView.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-11.
//

import SwiftUI

/// The play queue for the active speaker, presented as a sheet from the
/// now-playing area. Shows the current track ("Spelas nu") and the upcoming
/// tracks ("Näst på tur"); upcoming tracks can be swiped away. Each Spotify
/// track carries the Liked-Songs heart.
struct QueueView: View {
    @ObservedObject var viewModel: MusicViewModel

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .backgroundModifier()
                .foregroundStyle(.white)
                .navigationTitle("Kö")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Stäng") { viewModel.isShowingQueue = false }
                            .foregroundStyle(.white)
                    }
                }
        }
        .task { await viewModel.loadQueue() }
    }

    @ViewBuilder private var content: some View {
        if viewModel.isLoadingQueue, viewModel.queue == .empty {
            ProgressView()
                .tint(.white)
                .padding(.top, 60)
        } else if isQueueEmpty {
            emptyState
        } else {
            queueList
        }
    }

    private var isQueueEmpty: Bool {
        viewModel.queue.currentItem == nil && viewModel.queue.upcomingItems.isEmpty
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.4))
            Text("Inget spelas")
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var queueList: some View {
        List {
            Section {
                if let current = viewModel.queue.currentItem {
                    QueueRow(viewModel: viewModel, item: current)
                } else {
                    Text("Inget spelas")
                        .foregroundStyle(.white.opacity(0.6))
                        .listRowBackground(Color.clear)
                }
            } header: {
                sectionHeader("Spelas nu")
            }

            Section {
                if viewModel.queue.upcomingItems.isEmpty {
                    Text("Inga kommande låtar")
                        .foregroundStyle(.white.opacity(0.6))
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.queue.upcomingItems) { item in
                        QueueRow(viewModel: viewModel, item: item)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await viewModel.removeFromQueue(item) }
                                } label: {
                                    Label("Ta bort", systemImage: "trash")
                                }
                            }
                    }
                }
            } header: {
                sectionHeader("Näst på tur")
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.white)
    }
}

/// One queue row: album art, title, artist, and the Liked-Songs heart for
/// Spotify tracks.
private struct QueueRow: View {
    @ObservedObject var viewModel: MusicViewModel
    let item: MusicQueueItem

    var body: some View {
        HStack(spacing: 12) {
            AlbumArtView(urlString: item.imageURL, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
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
            if let uri = item.uri, viewModel.canFavoriteSong(uri: uri) {
                SongFavoriteButton(viewModel: viewModel, uri: uri)
            }
        }
        .listRowBackground(Color.clear)
        .foregroundStyle(.white)
    }
}
