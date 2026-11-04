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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGFloat = 0
    @State private var trackOpacity: Double = 1
    /// The title shown when a swipe skipped, while the row waits off screen for the
    /// next one to load. Nil when no skip is in flight.
    @State private var titleAtSkip: String??
    /// The row has flown out and waits on the far side for the next track.
    @State private var isParked = false
    @State private var slideInFallback: Task<Void, Never>?

    /// Far enough to carry the art and title past the bar's clipped edge.
    private static let flyDistance: CGFloat = 360

    var body: some View {
        let speakerID = viewModel.controlledSpeakerID(in: entry)
        let speaker = viewModel.displayedSpeaker(speakerID)
        VStack(spacing: 0) {
            trackRow(speakerID: speakerID, speaker: speaker)
                .frame(height: 56)

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
            .opacity(trackOpacity)
            .contentShape(Rectangle())
            // Not a Button: a Button claims the touch, so a swipe that starts on the
            // title never reached a drag gesture on the row. Here the swipe is tried
            // first and the tap only fires when the finger didn't travel.
            .gesture(trackSwipe.exclusively(before: TapGesture().onEnded { openPlayer() }))
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { openPlayer() }
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
        .onChange(of: speaker?.mediaTitle) { _, title in
            if isParked, let titleAtSkip, title != titleAtSkip {
                slideIn()
            }
        }
        .onDisappear {
            slideInFallback?.cancel()
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

    /// The art and title slide with the finger. A swipe past the threshold skips and
    /// carries them off that way; the next track then slides in from the other side
    /// once it loads. A shorter drag springs back.
    private var trackSwipe: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                if titleAtSkip == nil, abs(value.translation.width) > abs(value.translation.height) {
                    dragOffset = value.translation.width / 2
                }
            }
            .onEnded { value in
                guard titleAtSkip == nil else {
                    return
                }
                guard let swipe = MiniPlayerSwipe(translation: value.translation) else {
                    withAnimation(.spring(duration: 0.3)) {
                        dragOffset = 0
                    }
                    return
                }
                skip(swipe)
                flyOut(swipe)
            }
    }

    private var currentTitle: String? {
        viewModel.displayedSpeaker(viewModel.controlledSpeakerID(in: entry))?.mediaTitle
    }

    private func flyOut(_ swipe: MiniPlayerSwipe) {
        // With Reduce Motion the track only fades out and back in.
        let direction: CGFloat = reduceMotion ? 0 : (swipe == .next ? -1 : 1)
        titleAtSkip = .some(currentTitle)
        withAnimation(.easeIn(duration: 0.18)) {
            dragOffset = direction * Self.flyDistance
            trackOpacity = 0
        } completion: {
            // Park on the far side, so the next track enters from where it came.
            dragOffset = -direction * Self.flyDistance
            isParked = true
            if let titleAtSkip, currentTitle != titleAtSkip {
                slideIn()
            }
        }
        // The track may not change (the start of the queue, or a slow reload), so
        // never leave the row empty for long.
        slideInFallback?.cancel()
        slideInFallback = Task {
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled {
                slideIn()
            }
        }
    }

    private func slideIn() {
        slideInFallback?.cancel()
        slideInFallback = nil
        titleAtSkip = nil
        isParked = false
        withAnimation(.spring(duration: 0.35)) {
            dragOffset = 0
            trackOpacity = 1
        }
    }

    private func openPlayer() {
        viewModel.selectRoom(entry)
        viewModel.isShowingNowPlaying = true
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
