//
//  MusicPlaylistView.swift
//  IntelliNest
//
//  Created by Tobias on 2026-09-20.
//

import SwiftUI

/// The drill-in view for a playlist: a header with cover art and a play button
/// that plays the whole list, plus the track list where tapping a song plays
/// that song followed by the rest of the playlist. Reached from the search
/// results, the music screen's library sections, and the "Visa alla" listing.
struct MusicPlaylistView: View {
    @ObservedObject var viewModel: MusicViewModel
    let playlist: MusicSearchItem
    /// The header button whose playback request is in flight. Starting a playlist
    /// waits on Home Assistant and Music Assistant, which can take seconds, so the
    /// tapped button shows a spinner until the call returns.
    @State private var startingButton: String?

    var body: some View {
        VStack(spacing: 16) {
            header
            trackList
        }
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
        .padding(.horizontal)
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
            Task {
                startingButton = title
                await action()
                startingButton = nil
            }
        } label: {
            HStack(spacing: 8) {
                if startingButton == title {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.headline)
            .padding(.vertical, 10)
            .padding(.horizontal, 24)
            .background(Color.white.opacity(0.15))
            .clipShape(Capsule())
        }
        .disabled(startingButton != nil)
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
            List(viewModel.playlistTracks) { track in
                trackRow(track)
            }
            .musicListStyle()
            // Reflect each track's Liked-Songs state when the list loads.
            .task(id: viewModel.playlistTracks.map(\.id).joined(separator: "|")) {
                await viewModel.loadSavedSongStates(uris: viewModel.playlistTracks.map(\.uri))
            }
        }
    }

    /// A playlist track row: tapping plays it (then the rest of the playlist), the
    /// trailing heart toggles Liked Songs, a leading swipe queues it, and a
    /// long-press still exposes add to playlist / remove from this playlist.
    private func trackRow(_ track: MusicPlaylistTrack) -> some View {
        HStack(spacing: 12) {
            Button {
                Task { await viewModel.playTrackInPlaylist(track, from: playlist) }
            } label: {
                HStack(spacing: 12) {
                    AlbumArtView(urlString: track.imageURL, size: 44)
                    Text(track.title)
                        .font(.body)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
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
        .foregroundStyle(.white)
        .musicListRow()
        .queueSwipeActions(viewModel: viewModel,
                           uri: track.uri,
                           title: track.title,
                           imageURL: track.imageURL)
        .swipeActions(edge: .trailing) {
            if viewModel.canEditPlaylist(playlist) {
                Button(role: .destructive) {
                    Task { await viewModel.removeTrack(track, fromPlaylist: playlist) }
                } label: {
                    Label("Ta bort", systemImage: "trash")
                }
                .accessibilityLabel("Ta bort \(track.title) från spellistan")
            }
        }
        .contextMenu {
            TrackActionButtons(viewModel: viewModel,
                               uri: track.uri,
                               title: track.title,
                               imageURL: track.imageURL,
                               onRemoveFromPlaylist: removeAction(for: track))
        }
    }

    /// The long-press remove, offered only for a playlist the user can edit on
    /// Spotify. The trailing swipe covers the same action; the menu entry stays for
    /// discoverability and for anyone who never swipes.
    private func removeAction(for track: MusicPlaylistTrack) -> MainActorVoidClosure? {
        guard viewModel.canEditPlaylist(playlist) else {
            return nil
        }
        return { Task { await viewModel.removeTrack(track, fromPlaylist: playlist) } }
    }
}
