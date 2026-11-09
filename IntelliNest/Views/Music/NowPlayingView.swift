//
//  NowPlayingView.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-09.
//

import SwiftUI

/// The full-screen player, opened from the mini player: art first, then the
/// track, scrubber, transport and volume, with the room, lyrics and queue along
/// the bottom like Spotify. The room pill is the way into the room sheet, where
/// control moves to another room without stopping this one.
struct NowPlayingView: View {
    let speaker: MediaPlayerEntity
    @ObservedObject var viewModel: MusicViewModel
    let onClose: MainActorVoidClosure

    /// Shows each grouped speaker's own volume under the group slider. Opened by
    /// tapping the group slider's thumb; the art shrinks to make room.
    @State private var isShowingSpeakerVolumes = false

    private var showsSpeakerVolumes: Bool {
        isShowingSpeakerVolumes && viewModel.isGroupActive
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                // Square art as wide as the screen allows.
                GeometryReader { geometry in
                    AlbumArtView(urlString: speaker.entityPicture, size: geometry.size.width)
                }
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: showsSpeakerVolumes ? 180 : .infinity)
                .accessibilityHidden(true)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        // Long titles and artists scroll (or wrap, with Reduce Motion)
                        // so the whole name can be read instead of being cut off.
                        MarqueeText(text: speaker.mediaTitle ?? "Inget spelas")
                            .font(.title3.bold())
                        if let artist = speaker.mediaArtist {
                            MarqueeText(text: artist)
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    Spacer(minLength: 8)
                    if let uri = speaker.mediaContentID, viewModel.canFavoriteSong(uri: uri) {
                        SongFavoriteButton(viewModel: viewModel, uri: uri)
                            .font(.title2)
                    }
                }

                SeekBarView(speaker: speaker, viewModel: viewModel)

                TransportControlsView(speaker: speaker, viewModel: viewModel)

                volumeSection

                if viewModel.isLyricsExpanded {
                    LyricsStripView(speaker: speaker, viewModel: viewModel)
                }

                bottomRow
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
        .animation(.spring(duration: 0.3), value: showsSpeakerVolumes)
        // Collapse when the group splits, so a later group doesn't reopen expanded.
        .onChange(of: viewModel.isGroupActive) { _, isGrouped in
            if !isGrouped {
                isShowingSpeakerVolumes = false
            }
        }
        // Prefetch lyrics whenever the track changes so they're ready the moment the
        // user opens the panel, rather than starting the lookup on that tap.
        .task(id: viewModel.currentLyricsTrackKey) {
            await viewModel.refreshLyricsForCurrentTrack()
        }
    }

    /// The group slider, and each grouped speaker's own slider once expanded.
    private var volumeSection: some View {
        VStack(spacing: 8) {
            VolumeSliderView(volume: viewModel.groupVolume,
                             onThumbTap: viewModel.isGroupActive ? { isShowingSpeakerVolumes.toggle() } : nil,
                             onCommit: { viewModel.setGroupVolume($0) })
                .accessibilityLabel(viewModel.isGroupActive ? "Gruppvolym" : "Volym")
                .accessibilityActions {
                    if viewModel.isGroupActive {
                        Button(showsSpeakerVolumes ? "Dölj högtalarvolymer" : "Visa högtalarvolymer") {
                            isShowingSpeakerVolumes.toggle()
                        }
                    }
                }

            if showsSpeakerVolumes {
                ForEach(viewModel.groupedSpeakers, id: \.entityId) { member in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(member.friendlyName)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .accessibilityHidden(true)
                        VolumeSliderView(volume: member.volumeLevel,
                                         onCommit: { viewModel.setVolume($0, for: member.entityId) })
                            .accessibilityLabel("Volym \(member.friendlyName)")
                    }
                    .padding(.leading, 16)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    /// A close chevron, and the playlist the track is playing from when it is
    /// known. Tapping the playlist opens it, without stopping playback.
    private var header: some View {
        HStack(spacing: 8) {
            Button(action: onClose) {
                Image(systemName: "chevron.down")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Stäng spelaren")

            Spacer(minLength: 0)
            sourceLabel
            Spacer(minLength: 0)

            // Balances the chevron so the title stays centred.
            Color.clear.frame(width: 44, height: 44)
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder private var sourceLabel: some View {
        if let source = viewModel.nowPlayingSourcePlaylist {
            Button {
                Task { await viewModel.openNowPlayingPlaylist() }
            } label: {
                VStack(spacing: 2) {
                    Text("Spelar från spellista")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                    MarqueeText(text: source.name)
                        .font(.subheadline.weight(.semibold))
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Öppna spellistan som spelas")
        } else {
            Text(viewModel.controlledRoomTitle)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
    }

    /// The room pill on the left, lyrics and queue on the right.
    private var bottomRow: some View {
        HStack(spacing: 4) {
            Button {
                viewModel.isShowingSpeakerPicker = true
            } label: {
                Label(viewModel.controlledRoomTitle,
                      systemImage: viewModel.isGroupActive ? "hifispeaker.2.fill" : "hifispeaker.fill")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .foregroundStyle(.black)
                    .background(Capsule().fill(.yellow))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Spelar i \(viewModel.controlledRoomTitle)")
            .accessibilityHint("Byt rum eller gruppera högtalare")

            Spacer(minLength: 8)

            iconButton("quote.bubble", label: "Visa sångtext", isActive: viewModel.isLyricsExpanded) {
                viewModel.toggleLyricsExpanded()
            }
            iconButton("list.bullet", label: "Visa kö") {
                Task { await viewModel.openQueue() }
            }
        }
    }

    /// An icon with a full 44×44 hit target. `isActive` tints it yellow to show a
    /// toggled-on state (the lyrics toggle).
    private func iconButton(_ systemName: String,
                            label: String,
                            isActive: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3)
                .foregroundStyle(isActive ? .yellow : .white)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
    }
}

private struct TransportControlsView: View {
    let speaker: MediaPlayerEntity
    @ObservedObject var viewModel: MusicViewModel

    var body: some View {
        HStack(spacing: 28) {
            Button {
                viewModel.toggleShuffle()
            } label: {
                Image(systemName: "shuffle")
                    .foregroundStyle(speaker.shuffle ? .yellow : .white)
            }
            .accessibilityLabel("Blanda")
            .accessibilityValue(speaker.shuffle ? "På" : "Av")

            Button {
                viewModel.previousTrack()
            } label: {
                Image(systemName: "backward.fill")
            }
            .accessibilityLabel("Föregående låt")

            Button {
                viewModel.togglePlayPause()
            } label: {
                if viewModel.pendingPlaybackSpeakers.contains(speaker.entityId) {
                    ProgressView()
                        .controlSize(.large)
                        .frame(width: 54, height: 54)
                } else {
                    Image(systemName: speaker.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .resizable()
                        .frame(width: 54, height: 54)
                }
            }
            .accessibilityLabel(speaker.isPlaying ? "Pausa" : "Spela")
            .contextMenu {
                // Long-press escape hatch for when the shown state is wrong (Music
                // Assistant and the Sonos disagree), so a plain tap can't pause.
                Button {
                    viewModel.forcePause()
                } label: {
                    Label("Tvinga paus", systemImage: "pause.fill")
                }
            }

            Button {
                viewModel.nextTrack()
            } label: {
                Image(systemName: "forward.fill")
            }
            .accessibilityLabel("Nästa låt")

            Button {
                viewModel.toggleRepeat()
            } label: {
                Image(systemName: speaker.repeatMode == .one ? "repeat.1" : "repeat")
                    .foregroundStyle(speaker.repeatMode == .off ? .white : .yellow)
            }
            .accessibilityLabel("Upprepa")
            .accessibilityValue(repeatAccessibilityValue)
        }
        .font(.title2)
    }

    private var repeatAccessibilityValue: String {
        switch speaker.repeatMode {
        case .off: "Av"
        case .all: "Alla"
        case .one: "En"
        }
    }
}
