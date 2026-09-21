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
    @State private var searchResultsTab: MusicSearchTab = .all

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                MusicSearchBar(searchText: $viewModel.searchText,
                               onSubmit: { Task { await viewModel.searchNow() } })
                if !viewModel.isSpotifyAuthorized {
                    spotifyLoginTriangle
                }
                if viewModel.displayedActiveSpeaker != nil {
                    speakerPickerButton
                }
            }

            ScrollView {
                VStack(spacing: 16) {
                    if let activeSpeaker = viewModel.displayedActiveSpeaker {
                        // The now-playing card is only in the way while the user is
                        // hunting for something to play.
                        if !viewModel.isFilteringLibrary {
                            NowPlayingView(speaker: activeSpeaker, viewModel: viewModel)
                        }
                        ForEach(viewModel.librarySections) { section in
                            LibraryPlaylistsSection(viewModel: viewModel,
                                                    section: section,
                                                    onShowAll: { viewModel.expandedLibrarySection = section })
                        }
                        if viewModel.isFilteringLibrary {
                            if viewModel.librarySections.isEmpty {
                                Text("Inget i biblioteket matchar")
                                    .foregroundStyle(.white.opacity(0.7))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            SpotifySearchResultsSections(viewModel: viewModel) { mediaType in
                                searchResultsTab = .mediaType(mediaType)
                                Task { await viewModel.search() }
                            }
                        }
                    } else {
                        SpeakerPickerView(viewModel: viewModel)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .padding(.horizontal)
        .foregroundStyle(.white)
        // Refresh the MA favourites (star state) and the Spotify listing each time
        // the view appears rather than trusting the once-per-session cache.
        .task {
            await viewModel.refreshFavorites()
        }
        // Typing filters the loaded library instantly and, a beat later, runs the
        // Music Assistant search whose hits are listed under the library matches.
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.scheduleSearch()
        }
        .sheet(isPresented: $viewModel.isShowingSearchResults) {
            MusicSearchResultsView(viewModel: viewModel, initialTab: searchResultsTab)
        }
        .sheet(item: $viewModel.browsingArtist) { artist in
            NavigationStack {
                MusicArtistView(viewModel: viewModel, item: artist)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Stäng") { viewModel.browsingArtist = nil }
                                .foregroundStyle(.white)
                        }
                    }
            }
        }
        .sheet(isPresented: $viewModel.isShowingSpeakerPicker) {
            SpeakerPickerSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isShowingQueue) {
            QueueView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isShowingFullLyrics) {
            if let activeSpeaker = viewModel.displayedActiveSpeaker {
                LyricsFullView(speaker: activeSpeaker, viewModel: viewModel)
            } else {
                // The speaker dropped out while the sheet was open — don't strand an
                // empty modal; dismiss it.
                Color.clear.onAppear { viewModel.isShowingFullLyrics = false }
            }
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
        .sheet(item: $viewModel.expandedLibrarySection) { section in
            MusicLibraryListView(viewModel: viewModel, section: section)
        }
    }

    /// Opens the speaker picker. It sits at screen level rather than inside the
    /// now-playing card: picking a speaker (or a new group leader) is a choice
    /// about the whole screen, not an action on the speaker currently playing.
    private var speakerPickerButton: some View {
        Button {
            viewModel.isShowingSpeakerPicker = true
        } label: {
            Image(systemName: "hifispeaker.2.fill")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Byt högtalare")
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
    var prompt = "Sök i biblioteket eller på Spotify"
    let onSubmit: MainActorVoidClosure

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.7))
            TextField("", text: $searchText, prompt: Text(prompt).foregroundColor(.white.opacity(0.6)))
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

struct MusicView_Previews: PreviewProvider {
    static var previews: some View {
        MusicView(viewModel: MusicViewModel(restAPIService: PreviewProviderUtil.restAPIService))
            .backgroundModifier()
    }
}
