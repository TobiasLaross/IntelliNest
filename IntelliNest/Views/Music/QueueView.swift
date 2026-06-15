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

            // The user's own additions ("I kö") and the playing context ("Nästa
            // från: …") are shown as separate groups, the way Spotify splits them.
            let manual = viewModel.queue.manualUpcoming
            let context = viewModel.queue.contextUpcoming

            if manual.isEmpty, context.isEmpty {
                Section {
                    Text("Inga kommande låtar")
                        .foregroundStyle(.white.opacity(0.6))
                        .listRowBackground(Color.clear)
                } header: {
                    sectionHeader("Näst på tur")
                }
            } else {
                if !manual.isEmpty {
                    Section {
                        upcomingRows(manual, section: .manual)
                    } header: {
                        sectionHeader("I kö")
                    }
                }
                if !context.isEmpty {
                    Section {
                        upcomingRows(context, section: .context)
                    } header: {
                        sectionHeader(contextHeaderTitle)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    /// The header for the context group: names the source playlist when playback
    /// was started from one this session, otherwise the generic "Näst på tur".
    private var contextHeaderTitle: String {
        if let name = viewModel.nowPlayingSourcePlaylist?.name {
            return "Nästa från: \(name)"
        }
        return "Näst på tur"
    }

    @ViewBuilder private func upcomingRows(_ items: [MusicQueueItem], section: QueueSection) -> some View {
        ForEach(items) { item in
            QueueRow(viewModel: viewModel, item: item, showsDragHandle: true)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await viewModel.removeFromQueue(item) }
                    } label: {
                        Label("Ta bort", systemImage: "trash")
                    }
                }
        }
        // Long-press a row to drag it within its group; reorders the live queue.
        .onMove { fromOffsets, toOffset in
            Task { await viewModel.moveUpcoming(section, fromOffsets: fromOffsets, toOffset: toOffset) }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.white)
    }
}

/// One queue row: album art, title, artist, the Liked-Songs heart for Spotify
/// tracks, and — for reorderable upcoming rows — a trailing drag handle hinting
/// that the row can be long-pressed and dragged within its group.
private struct QueueRow: View {
    @ObservedObject var viewModel: MusicViewModel
    let item: MusicQueueItem
    var showsDragHandle = false

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
            if showsDragHandle {
                Image(systemName: "line.3.horizontal")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.4))
                    .accessibilityLabel("Dra för att ändra ordning")
            }
        }
        .listRowBackground(Color.clear)
        .foregroundStyle(.white)
    }
}
