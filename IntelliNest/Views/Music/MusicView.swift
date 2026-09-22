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
    @State private var isSearching = false
    @StateObject private var recentSearches = RecentMusicSearches()

    var body: some View {
        Group {
            if isSearching {
                MusicSearchView(viewModel: viewModel,
                                recentSearches: recentSearches,
                                onShowAll: { mediaType in
                                    recentSearches.record(viewModel.searchText)
                                    searchResultsTab = .mediaType(mediaType)
                                    Task { await viewModel.search() }
                                },
                                onClose: closeSearch)
            } else {
                startScreen
            }
        }
        .padding(.horizontal)
        .foregroundStyle(.white)
        .toolbar(isSearching ? .hidden : .visible, for: .navigationBar)
        // Refresh the MA favourites (star state) and the Spotify listing each time
        // the view appears rather than trusting the once-per-session cache.
        .task {
            await viewModel.refreshFavorites()
        }
        // Returning to the music screen always starts outside the search, so a
        // query left over from an earlier visit mustn't filter the library.
        .onAppear {
            if !isSearching {
                viewModel.searchText = ""
            }
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

    private var startScreen: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                searchButton
                if !viewModel.isSpotifyAuthorized {
                    spotifyLoginTriangle
                }
            }

            ScrollView {
                VStack(spacing: 16) {
                    if let activeSpeaker = viewModel.displayedActiveSpeaker {
                        NowPlayingView(speaker: activeSpeaker, viewModel: viewModel)
                        ForEach(viewModel.librarySections) { section in
                            LibraryPlaylistsSection(viewModel: viewModel,
                                                    section: section,
                                                    onShowAll: { viewModel.expandedLibrarySection = section })
                        }
                    } else {
                        SpeakerPickerView(viewModel: viewModel)
                    }
                }
            }
        }
    }

    /// Looks like the search field but only opens the search screen, so typing
    /// always happens where the results and the close button are.
    private var searchButton: some View {
        Button {
            isSearching = true
        } label: {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.7))
                Text(MusicSearchBar.defaultPrompt)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                Spacer()
            }
            .padding(10)
            .background(Color.white.opacity(0.12))
            .cornerRadius(12)
        }
        .accessibilityLabel("Sök efter musik")
    }

    /// Leaves the search screen with the field emptied, so the start screen shows
    /// the whole library again instead of a filtered slice of it.
    private func closeSearch() {
        recentSearches.record(viewModel.searchText)
        viewModel.searchText = ""
        isSearching = false
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
    static let defaultPrompt = "Sök i biblioteket eller på Spotify"

    @Binding var searchText: String
    var prompt = Self.defaultPrompt
    var focusesOnAppear = false
    let onSubmit: MainActorVoidClosure
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.7))
            TextField("", text: $searchText, prompt: Text(prompt).foregroundColor(.white.opacity(0.6)))
                .foregroundStyle(.white)
                .submitLabel(.search)
                .focused($isFocused)
                .onSubmit(onSubmit)
                .accessibilityLabel("Sök efter musik")
            if searchText.isNotEmpty {
                Button {
                    searchText = ""
                    isFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.6))
                }
                .accessibilityLabel("Rensa sökningen")
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.12))
        .cornerRadius(12)
        .onAppear {
            if focusesOnAppear {
                isFocused = true
            }
        }
    }
}

struct MusicView_Previews: PreviewProvider {
    static var previews: some View {
        MusicView(viewModel: MusicViewModel(restAPIService: PreviewProviderUtil.restAPIService))
            .backgroundModifier()
    }
}
