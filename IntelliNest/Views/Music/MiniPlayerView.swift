//
//  MiniPlayerView.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-09.
//

import SwiftUI

/// The bar pinned to the bottom of the music screen, one page per room that is
/// playing. Swiping to another page moves control to that room and leaves the
/// rest playing, so the kitchen and the bedroom can each run their own music.
/// Tapping a page opens the full-screen player for that room.
struct MiniPlayerView: View {
    @ObservedObject var viewModel: MusicViewModel

    var body: some View {
        let rooms = viewModel.miniPlayerRooms
        VStack(spacing: 6) {
            TabView(selection: selection(in: rooms)) {
                ForEach(rooms) { entry in
                    MiniPlayerBar(viewModel: viewModel, entry: entry)
                        .padding(.horizontal, 2)
                        .tag(Optional(entry.id))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 60)

            if rooms.count > 1 {
                pageDots(rooms)
            }
        }
        // Keep the Liked-Songs heart in sync with the controlled room's track.
        .task(id: viewModel.displayedActiveSpeaker?.mediaContentID) {
            await viewModel.loadSavedSongStates(uris: [viewModel.displayedActiveSpeaker?.mediaContentID].compactMap { $0 })
        }
    }

    /// The page shown is always the controlled room; swiping selects the new one.
    private func selection(in rooms: [SpeakerPickerEntry]) -> Binding<EntityId?> {
        Binding(
            get: { rooms.first { $0.contains(viewModel.activeSpeakerID) }?.id },
            set: { newID in
                if let entry = rooms.first(where: { $0.id == newID }) {
                    viewModel.selectRoom(entry)
                }
            }
        )
    }

    private func pageDots(_ rooms: [SpeakerPickerEntry]) -> some View {
        HStack(spacing: 6) {
            ForEach(rooms) { entry in
                Circle()
                    .fill(entry.contains(viewModel.activeSpeakerID) ? Color.white : Color.white.opacity(0.35))
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(rooms.count) rum spelar. Svep för att byta rum")
    }
}

/// One room's page in the mini player: art, track, the room in yellow, and
/// play/pause for that room. A thin line along the bottom shows the progress.
private struct MiniPlayerBar: View {
    @ObservedObject var viewModel: MusicViewModel
    let entry: SpeakerPickerEntry

    var body: some View {
        let speakerID = viewModel.controlledSpeakerID(in: entry)
        let speaker = viewModel.displayedSpeaker(speakerID)
        HStack(spacing: 10) {
            Button {
                viewModel.selectRoom(entry)
                viewModel.isShowingNowPlaying = true
            } label: {
                HStack(spacing: 10) {
                    AlbumArtView(urlString: speaker?.entityPicture, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(speaker?.mediaTitle ?? "Inget spelas")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Label(entry.title, systemImage: entry.isGroup ? "hifispeaker.2.fill" : "hifispeaker.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(speaker?.mediaTitle ?? "Inget spelas"), \(entry.title)")
            .accessibilityHint("Öppna spelaren")

            if speakerID == viewModel.activeSpeakerID,
               let uri = speaker?.mediaContentID, viewModel.canFavoriteSong(uri: uri) {
                SongFavoriteButton(viewModel: viewModel, uri: uri)
                    .font(.title3)
                    .frame(width: 36, height: 44)
            }

            Button {
                viewModel.togglePlayPause(for: speakerID)
            } label: {
                Image(systemName: speaker?.isPlaying == true ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(speaker?.isPlaying == true ? "Pausa \(entry.title)" : "Spela \(entry.title)")
        }
        .foregroundStyle(.white)
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .frame(height: 56)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(red: 0.16, green: 0.24, blue: 0.25)))
        .overlay(alignment: .bottom) {
            if let speaker {
                MiniProgressLine(speaker: speaker)
                    .padding(.horizontal, 10)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
    }
}

/// The 2pt progress line under a mini player page, advanced once a second from
/// the speaker's extrapolated position. Hidden for sources with no known length.
private struct MiniProgressLine: View {
    let speaker: MediaPlayerEntity

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let duration = speaker.mediaDuration, duration > 0,
               let elapsed = speaker.currentElapsed(asOf: context.date) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.2))
                        Capsule().fill(Color.white)
                            .frame(width: geometry.size.width * min(max(elapsed / duration, 0), 1))
                    }
                }
                .frame(height: 2)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The full-screen player as presented from the mini player. It owns the sheets
/// opened from inside it (rooms, queue, lyrics, the playing playlist), since
/// SwiftUI can only present from the topmost view; `MusicView` presents the
/// rooms and playlist sheets only while the player is closed.
struct NowPlayingSheet: View {
    @ObservedObject var viewModel: MusicViewModel

    var body: some View {
        Group {
            if let speaker = viewModel.displayedActiveSpeaker {
                NowPlayingView(speaker: speaker, viewModel: viewModel, onClose: { viewModel.isShowingNowPlaying = false })
            } else {
                // The room dropped out while the player was open; don't strand an
                // empty modal.
                Color.clear.onAppear { viewModel.isShowingNowPlaying = false }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .backgroundModifier()
        .foregroundStyle(.white)
        .presentationDragIndicator(.visible)
        .sheet(isPresented: viewModel.presentation(\.isShowingSpeakerPicker, inPlayer: true)) {
            SpeakerPickerSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isShowingQueue) {
            QueueView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isShowingFullLyrics) {
            if let speaker = viewModel.displayedActiveSpeaker {
                LyricsFullView(speaker: speaker, viewModel: viewModel)
            } else {
                Color.clear.onAppear { viewModel.isShowingFullLyrics = false }
            }
        }
        .sheet(item: viewModel.presentation(\.browsingLibraryPlaylist, inPlayer: true)) { playlist in
            MusicPlaylistBrowseSheet(viewModel: viewModel, playlist: playlist)
        }
    }
}

/// A library playlist opened for browsing, with its own close button. Presented
/// from the start screen or from the player's "Spelar från" link.
struct MusicPlaylistBrowseSheet: View {
    @ObservedObject var viewModel: MusicViewModel
    let playlist: MusicSearchItem

    var body: some View {
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
}

extension MusicViewModel {
    /// A sheet binding that is live only on one side of the full-screen player, so
    /// a sheet both the start screen and the player can open is presented by
    /// whichever is on top: `inPlayer: true` for the player, false for the screen
    /// underneath.
    func presentation(_ keyPath: ReferenceWritableKeyPath<MusicViewModel, Bool>, inPlayer: Bool) -> Binding<Bool> {
        Binding(
            get: { self[keyPath: keyPath] && self.isShowingNowPlaying == inPlayer },
            set: { self[keyPath: keyPath] = $0 }
        )
    }

    func presentation<Item>(_ keyPath: ReferenceWritableKeyPath<MusicViewModel, Item?>,
                            inPlayer: Bool) -> Binding<Item?> {
        Binding(
            get: { self.isShowingNowPlaying == inPlayer ? self[keyPath: keyPath] : nil },
            set: { self[keyPath: keyPath] = $0 }
        )
    }
}
