//
//  MusicTrackControls.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-11.
//

import SwiftUI

/// The Liked-Songs heart shown on a track row or now-playing. Filled green when
/// the track is in the user's Spotify Liked Songs, outlined otherwise. Callers
/// render it only for Spotify-resolvable tracks (`canFavoriteSong`).
struct SongFavoriteButton: View {
    @ObservedObject var viewModel: MusicViewModel
    let uri: String

    var body: some View {
        let saved = viewModel.isSongSaved(uri: uri)
        Button {
            Task { await viewModel.toggleSongSaved(uri: uri) }
        } label: {
            Image(systemName: saved ? "heart.fill" : "heart")
                .foregroundStyle(saved ? .green : .white.opacity(0.6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(saved ? "Ta bort från gillade låtar" : "Spara i gillade låtar")
    }
}

/// The track context-menu actions: add to the play queue, add to one of the
/// user's editable playlists, and (in an editable playlist) remove from it. Each
/// action is shown only when it can function. Designed to live inside a
/// `.contextMenu { … }`.
struct TrackActionButtons: View {
    @ObservedObject var viewModel: MusicViewModel
    let uri: String
    let title: String
    var artist: String?
    var imageURL: String?
    /// Set by an editable playlist's detail to offer "remove from this playlist".
    var onRemoveFromPlaylist: MainActorVoidClosure?

    var body: some View {
        Button {
            Task { await viewModel.addToQueue(uri: uri, title: title, artist: artist, imageURL: imageURL) }
        } label: {
            Label("Lägg till i kö", systemImage: "text.line.last.and.arrowtriangle.forward")
        }

        if viewModel.canAddTrackToPlaylist(uri: uri) {
            Menu {
                ForEach(viewModel.editableAccountPlaylists) { playlist in
                    Button(playlist.name) {
                        Task { await viewModel.addTrack(uri: uri, toPlaylist: playlist) }
                    }
                }
            } label: {
                Label("Lägg till i spellista", systemImage: "plus")
            }
        }

        if let onRemoveFromPlaylist {
            Button(role: .destructive) {
                onRemoveFromPlaylist()
            } label: {
                Label("Ta bort från spellistan", systemImage: "minus.circle")
            }
        }
    }
}
