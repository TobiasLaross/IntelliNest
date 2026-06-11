//
//  MusicView.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-09.
//

import SwiftUI

struct MusicView: View {
    @ObservedObject var viewModel: MusicViewModel
    @State private var isShowingSpotifyLogin = false

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                MusicSearchBar(searchText: $viewModel.searchText,
                               onSubmit: { Task { await viewModel.search() } })
                if !viewModel.isSpotifyAuthorized {
                    spotifyLoginTriangle
                }
            }

            ScrollView {
                VStack(spacing: 16) {
                    if let activeSpeaker = viewModel.activeSpeaker {
                        NowPlayingView(speaker: activeSpeaker, viewModel: viewModel)
                        SpeakerGroupingView(viewModel: viewModel)
                        LibraryPlaylistsSection(title: "Senast spelade",
                                                playlists: viewModel.recentlyPlayedPlaylists,
                                                viewModel: viewModel)
                        LibraryPlaylistsSection(title: "Favoriter",
                                                playlists: viewModel.favoritePlaylists,
                                                viewModel: viewModel)
                    } else {
                        SpeakerPickerView(viewModel: viewModel)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .padding(.horizontal)
        .foregroundStyle(.white)
        // Spotify is the source of truth — refresh the account's playlists each
        // time the view appears rather than trusting the once-per-session cache.
        .task { await viewModel.refreshSpotifyPlaylists() }
        .sheet(isPresented: $viewModel.isShowingSearchResults) {
            MusicSearchResultsView(viewModel: viewModel)
        }
        .sheet(item: $viewModel.browsingLibraryPlaylist) { playlist in
            NavigationStack {
                MusicPlaylistView(viewModel: viewModel, playlist: playlist)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Stäng") { viewModel.browsingLibraryPlaylist = nil }
                                .foregroundStyle(.white)
                        }
                    }
            }
        }
        .sheet(isPresented: $isShowingSpotifyLogin) {
            SpotifyLoginPromptView(viewModel: viewModel)
        }
    }

    /// A discrete warning triangle shown next to the search bar while logged out
    /// of Spotify. Tapping opens the dismissable login prompt.
    private var spotifyLoginTriangle: some View {
        Button {
            isShowingSpotifyLogin = true
        } label: {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.yellow)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Anslut Spotify")
    }
}

/// A dismissable modal that explains why Spotify is needed and starts the login.
/// Dismissable by swipe, the drag indicator, or "Senare"; logging in successfully
/// also dismisses it.
private struct SpotifyLoginPromptView: View {
    @ObservedObject var viewModel: MusicViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isLoggingIn = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.yellow)
            Text("Anslut Spotify")
                .font(.title2.bold())
            Text("Logga in på Spotify för att se dina spellistor under Favoriter och spara favoriter.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
            Button(action: logIn) {
                HStack(spacing: 8) {
                    if isLoggingIn {
                        ProgressView().tint(.black)
                    }
                    Text("Logga in på Spotify")
                }
                .font(.headline)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .foregroundStyle(.black)
                .clipShape(Capsule())
            }
            .disabled(isLoggingIn)
            Button("Senare") { dismiss() }
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .backgroundModifier()
        .foregroundStyle(.white)
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
    }

    private func logIn() {
        Task {
            isLoggingIn = true
            await viewModel.connectSpotify()
            isLoggingIn = false
            if viewModel.isSpotifyAuthorized {
                dismiss()
            }
        }
    }
}

struct MusicSearchBar: View {
    @Binding var searchText: String
    let onSubmit: MainActorVoidClosure

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.7))
            TextField("", text: $searchText, prompt: Text("Sök på Spotify").foregroundColor(.white.opacity(0.6)))
                .foregroundStyle(.white)
                .submitLabel(.search)
                .onSubmit(onSubmit)
                .accessibilityLabel("Sök efter musik")
        }
        .padding(10)
        .background(Color.white.opacity(0.12))
        .cornerRadius(12)
    }
}

/// A titled card of library playlists (favourites or recently played) shown
/// under the speaker grouping in place of the old per-speaker list. Renders
/// nothing while the list is empty.
struct LibraryPlaylistsSection: View {
    let title: String
    let playlists: [MusicSearchItem]
    @ObservedObject var viewModel: MusicViewModel

    var body: some View {
        if playlists.isNotEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                ForEach(playlists) { playlist in
                    LibraryPlaylistRow(
                        playlist: playlist,
                        onOpen: { Task { await viewModel.browseLibraryPlaylist(playlist) } }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
    }
}

/// A single playlist row. The whole row navigates into the playlist detail
/// (Spotify-style), where playback lives — so the trailing chevron honestly
/// signals "tapping the row opens it". The detail's play button starts it.
private struct LibraryPlaylistRow: View {
    let playlist: MusicSearchItem
    let onOpen: MainActorVoidClosure

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                AlbumArtView(urlString: playlist.imageURL, size: 48)
                Text(playlist.name)
                    .font(.body)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .contentShape(Rectangle())
        }
        .foregroundStyle(.white)
        .accessibilityLabel(playlist.name)
        .accessibilityHint("Öppna spellistan")
    }
}

struct MusicView_Previews: PreviewProvider {
    static var previews: some View {
        MusicView(viewModel: MusicViewModel(restAPIService: PreviewProviderUtil.restAPIService))
            .backgroundModifier()
    }
}
