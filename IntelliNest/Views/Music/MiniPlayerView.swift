//
//  MiniPlayerView.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-09.
//

import SwiftUI

/// Which way a horizontal swipe across the mini player moves through the queue,
/// like Spotify's: left for the next track, right for the previous one. Kept apart
/// from the view so the thresholds can be tested without a gesture.
enum MiniPlayerSwipe: Equatable {
    case next
    case previous

    static let threshold: CGFloat = 60

    /// Nil for a drag that is too short, or more vertical than horizontal, so a
    /// tap or a scroll of the library never skips a track.
    init?(translation: CGSize) {
        guard abs(translation.width) >= Self.threshold, abs(translation.width) > abs(translation.height) else {
            return nil
        }
        self = translation.width < 0 ? .next : .previous
    }
}

/// The bar pinned to the bottom of the music screen for the controlled room (or,
/// with none controlled, the first room playing). Tapping it opens the full-screen
/// player, swiping it sideways skips tracks, its slider sets the room's volume, and
/// the speaker button opens the room sheet where control moves between rooms.
struct MiniPlayerView: View {
    @ObservedObject var viewModel: MusicViewModel

    var body: some View {
        let rooms = viewModel.miniPlayerRooms
        Group {
            if let entry = rooms.first(where: { $0.contains(viewModel.activeSpeakerID) }) ?? rooms.first {
                MiniPlayerBar(viewModel: viewModel, entry: entry)
                    .padding(.horizontal, 2)
            }
        }
        // Keep the Liked-Songs heart in sync with the controlled room's track.
        .task(id: viewModel.displayedActiveSpeaker?.mediaContentID) {
            await viewModel.loadSavedSongStates(uris: [viewModel.displayedActiveSpeaker?.mediaContentID].compactMap { $0 })
        }
    }
}

/// The room's mini player: art, track, the room in yellow, the room picker and
/// play/pause, with the room's volume underneath. A thin line along the bottom
/// shows the progress.
private struct MiniPlayerBar: View {
    @ObservedObject var viewModel: MusicViewModel
    let entry: SpeakerPickerEntry
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        let speakerID = viewModel.controlledSpeakerID(in: entry)
        let speaker = viewModel.displayedSpeaker(speakerID)
        VStack(spacing: 0) {
            trackRow(speakerID: speakerID, speaker: speaker)
                .frame(height: 56)
                // Only the track row swipes, so dragging the volume slider never skips a track.
                .contentShape(Rectangle())
                .gesture(trackSwipe)

            VolumeSliderView(volume: entry.averageVolume,
                             onCommit: { viewModel.setGroupVolume($0, for: entry) })
                .accessibilityLabel(entry.isGroup ? "Gruppvolym \(entry.title)" : "Volym \(entry.title)")
                .padding(.trailing, 8)
                .padding(.bottom, 10)
        }
        .foregroundStyle(.white)
        .padding(.leading, 8)
        .padding(.trailing, 4)
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

    private func trackRow(speakerID: EntityId, speaker: MediaPlayerEntity?) -> some View {
        HStack(spacing: 10) {
            Button {
                viewModel.selectRoom(entry)
                viewModel.isShowingNowPlaying = true
            } label: {
                HStack(spacing: 10) {
                    AlbumArtView(urlString: speaker?.entityPicture, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        MarqueeText(text: speaker?.mediaTitle ?? "Inget spelas")
                            .font(.subheadline.weight(.semibold))
                        Label(entry.title, systemImage: entry.isGroup ? "hifispeaker.2.fill" : "hifispeaker.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                }
                .offset(x: dragOffset)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(speaker?.mediaTitle ?? "Inget spelas"), \(entry.title)")
            .accessibilityHint("Öppna spelaren")
            .accessibilityAction(named: "Nästa låt") { skip(.next) }
            .accessibilityAction(named: "Föregående låt") { skip(.previous) }

            if speakerID == viewModel.activeSpeakerID,
               let uri = speaker?.mediaContentID, viewModel.canFavoriteSong(uri: uri) {
                SongFavoriteButton(viewModel: viewModel, uri: uri)
                    .font(.title3)
                    .frame(width: 36, height: 44)
            }

            speakerButton
            playPauseButton(speakerID: speakerID, isPlaying: speaker?.isPlaying == true)
        }
    }

    private var speakerButton: some View {
        Button {
            viewModel.selectRoom(entry)
            viewModel.isShowingSpeakerPicker = true
        } label: {
            Image(systemName: "hifispeaker.2")
                .font(.title3)
                .frame(width: 40, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Välj högtalare")
    }

    private func playPauseButton(speakerID: EntityId, isPlaying: Bool) -> some View {
        Button {
            viewModel.togglePlayPause(for: speakerID)
        } label: {
            Group {
                if viewModel.pendingPlaybackSpeakers.contains(speakerID) {
                    ProgressView()
                } else {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.pendingPlaybackSpeakers.contains(speakerID))
        .accessibilityLabel(isPlaying ? "Pausa \(entry.title)" : "Spela \(entry.title)")
    }

    /// The track slides with the finger, then skips once the swipe passes the
    /// threshold and springs back either way.
    private var trackSwipe: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                if abs(value.translation.width) > abs(value.translation.height) {
                    dragOffset = value.translation.width / 2
                }
            }
            .onEnded { value in
                if let swipe = MiniPlayerSwipe(translation: value.translation) {
                    skip(swipe)
                }
                withAnimation(.spring(duration: 0.3)) {
                    dragOffset = 0
                }
            }
    }

    private func skip(_ swipe: MiniPlayerSwipe) {
        viewModel.selectRoom(entry)
        switch swipe {
        case .next:
            viewModel.nextTrack()
        case .previous:
            viewModel.previousTrack()
        }
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
/// SwiftUI can only present from the topmost view; see `MusicSheetHost`.
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
        // A playlist opened from the player closes with it; left set, it would pop
        // up again the next time the player opens.
        .onDisappear {
            viewModel.playerBrowsingPlaylist = nil
        }
        .sheet(isPresented: viewModel.presentation(\.isShowingSpeakerPicker, from: .player)) {
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
        .sheet(item: $viewModel.playerBrowsingPlaylist) { playlist in
            // The player sits right underneath, so a mini player here would only repeat it.
            MusicPlaylistBrowseSheet(viewModel: viewModel, playlist: playlist, docksMiniPlayer: false)
        }
    }
}

/// A library playlist opened for browsing, with its own close button. Presented
/// from the start screen or from the player's "Spelar från" link.
struct MusicPlaylistBrowseSheet: View {
    @ObservedObject var viewModel: MusicViewModel
    let playlist: MusicSearchItem
    var docksMiniPlayer = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            MusicPlaylistView(viewModel: viewModel, playlist: playlist)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Stäng") { dismiss() }
                            .foregroundStyle(.white)
                    }
                }
        }
        .browseSheetMiniPlayer(viewModel, isEnabled: docksMiniPlayer)
    }
}

/// The layers of the music screen that present sheets of their own. SwiftUI only
/// presents from the topmost view, so each shared sheet is live on one layer at a time.
enum MusicSheetHost {
    /// The music start screen and its search.
    case musicScreen
    /// A browse sheet over the music screen — "Visa alla", an artist or a library
    /// playlist — whose docked mini player opens the player and the rooms over it.
    case browseSheet
    /// The full-screen player.
    case player
}

extension MusicViewModel {
    /// Whether a browse sheet covers the music screen. A playlist opened from the
    /// player sits over the player instead, so it doesn't count.
    var isShowingBrowseSheet: Bool {
        expandedLibrarySection != nil || browsingArtist != nil
            || browsingLibraryPlaylist != nil
    }

    /// Where the full-screen player opens from: over a browse sheet when one is up,
    /// so opening the player never closes the list the user was in.
    private var playerHost: MusicSheetHost {
        isShowingBrowseSheet ? .browseSheet : .musicScreen
    }

    private var topSheetHost: MusicSheetHost {
        isShowingNowPlaying ? .player : playerHost
    }

    /// A sheet binding that is live only while `host` is the topmost layer.
    func presentation(_ keyPath: ReferenceWritableKeyPath<MusicViewModel, Bool>, from host: MusicSheetHost) -> Binding<Bool> {
        Binding(
            get: { self[keyPath: keyPath] && self.topSheetHost == host },
            set: { self[keyPath: keyPath] = $0 }
        )
    }

    func nowPlayingPresentation(from host: MusicSheetHost) -> Binding<Bool> {
        Binding(
            get: { self.isShowingNowPlaying && self.playerHost == host },
            set: { self.isShowingNowPlaying = $0 }
        )
    }
}

extension View {
    /// Docks the mini player under a browse sheet while the keyboard is down, and
    /// presents the player and the rooms from the sheet so they open over it.
    func browseSheetMiniPlayer(_ viewModel: MusicViewModel, isEnabled: Bool = true) -> some View {
        modifier(BrowseSheetMiniPlayer(viewModel: viewModel, isEnabled: isEnabled))
    }
}

private struct BrowseSheetMiniPlayer: ViewModifier {
    @ObservedObject var viewModel: MusicViewModel
    let isEnabled: Bool
    @State private var isKeyboardVisible = false

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                if isEnabled, !isKeyboardVisible, viewModel.miniPlayerRooms.isNotEmpty {
                    MiniPlayerView(viewModel: viewModel)
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                }
            }
            .tracksKeyboardVisibility($isKeyboardVisible)
            .sheet(isPresented: isEnabled ? viewModel.presentation(\.isShowingSpeakerPicker, from: .browseSheet) : .constant(false)) {
                SpeakerPickerSheet(viewModel: viewModel)
            }
            .sheet(isPresented: isEnabled ? viewModel.nowPlayingPresentation(from: .browseSheet) : .constant(false)) {
                NowPlayingSheet(viewModel: viewModel)
            }
    }
}
