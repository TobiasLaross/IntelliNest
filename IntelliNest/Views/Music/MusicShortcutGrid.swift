//
//  MusicShortcutGrid.swift
//  IntelliNest
//
//  Created by Tobias on 2026-10-05.
//

import SwiftUI

/// The two-column grid of recently played playlists at the top of the music
/// screen, the way Spotify's home opens. A tap opens the playlist; a long press
/// plays it straight away in the controlled room.
struct MusicShortcutGrid: View {
    @ObservedObject var viewModel: MusicViewModel
    let onShowAll: MainActorVoidClosure

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Senast spelade")
                    .font(.headline)
                Spacer()
                Button(action: onShowAll) {
                    HStack(spacing: 4) {
                        Text("Visa alla")
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(minHeight: 32)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Visa alla senast spelade")
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(viewModel.shortcutPlaylists) { playlist in
                    tile(playlist)
                }
            }
        }
    }

    private func tile(_ playlist: MusicSearchItem) -> some View {
        let isNowPlaying = viewModel.isNowPlaying(playlist)
        return Button {
            Task { await viewModel.browseLibraryPlaylist(playlist) }
        } label: {
            HStack(spacing: 8) {
                AlbumArtView(urlString: playlist.imageURL, size: 56)
                // Three short lines fit the tile, so even a long playlist name such as
                // "Victor Leksell/Miriam Bryant/Molly Sandén" reads in full.
                Text(playlist.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isNowPlaying ? .green : .white)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)
                // The green name marks the playlist that is playing; a wave icon
                // here would cost the name the width it needs.
                Spacer(minLength: 4)
            }
            .frame(height: 56)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isNowPlaying ? "\(playlist.name), spelas nu" : playlist.name)
        .accessibilityHint("Öppna spellistan")
        .contextMenu {
            Button("Spela", systemImage: "play.fill") {
                Task { await viewModel.playPlaylist(playlist) }
            }
            Button("Blanda", systemImage: "shuffle") {
                Task { await viewModel.playPlaylistShuffled(playlist) }
            }
        }
    }
}
