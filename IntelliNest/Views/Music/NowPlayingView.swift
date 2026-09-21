//
//  NowPlayingView.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-09.
//

import SwiftUI

struct NowPlayingView: View {
    let speaker: MediaPlayerEntity
    @ObservedObject var viewModel: MusicViewModel

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                speakerNameButton
                Spacer(minLength: 4)
                // Each action gets a full 44×44 hit target so the controls are
                // comfortably tappable and evenly spaced.
                HStack(spacing: 4) {
                    headerButton("quote.bubble",
                                 label: "Visa sångtext",
                                 isActive: viewModel.isLyricsExpanded) {
                        viewModel.toggleLyricsExpanded()
                    }
                    headerButton("list.bullet", label: "Visa kö") {
                        Task { await viewModel.openQueue() }
                    }
                }
                // Pull the row of icons to the card's edge so the 44pt hit targets
                // don't add visible padding beyond the card's own inset.
                .padding(.trailing, -10)
            }

            HStack(spacing: 12) {
                nowPlayingMetadata
                Spacer(minLength: 8)
                if let uri = speaker.mediaContentID, viewModel.canFavoriteSong(uri: uri) {
                    SongFavoriteButton(viewModel: viewModel, uri: uri)
                        .font(.title3)
                }
            }

            SeekBarView(speaker: speaker, viewModel: viewModel)

            TransportControlsView(speaker: speaker, viewModel: viewModel)

            if viewModel.isLyricsExpanded {
                LyricsStripView(speaker: speaker, viewModel: viewModel)
            }

            GroupVolumeView(viewModel: viewModel)
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.yellow.opacity(0.7), lineWidth: 2)
        )
        // Keep the now-playing Liked-Songs heart in sync with the live track.
        .task(id: speaker.mediaContentID) {
            await viewModel.loadSavedSongStates(uris: [speaker.mediaContentID].compactMap { $0 })
        }
        // Prefetch lyrics whenever the track changes so they're ready the moment the
        // user opens the panel, rather than starting the lookup on that tap.
        .task(id: viewModel.currentLyricsTrackKey) {
            await viewModel.refreshLyricsForCurrentTrack()
        }
    }

    /// A header action rendered with a full 44×44 hit target (Apple's minimum), so
    /// the now-playing controls are easy to tap and evenly spaced. `isActive`
    /// tints the icon yellow to show a toggled-on state (used by the lyrics toggle).
    /// The speaker name doubles as the way to switch speaker — the same picker as
    /// the button beside the search field, where a thumb already rests on the card.
    private var speakerNameButton: some View {
        Button {
            viewModel.isShowingSpeakerPicker = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "hifispeaker.fill")
                Text(speaker.friendlyName)
                    .font(.headline)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.yellow)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(speaker.friendlyName), byt högtalare")
    }

    private func headerButton(_ systemName: String,
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

    /// The album art and track metadata. Tapping it opens the playlist the track
    /// is playing from, when that source is known; otherwise it is inert (no
    /// dead-end). The transport and volume controls below stay separate, so the
    /// jump tap never swallows a play/pause or volume change.
    @ViewBuilder private var nowPlayingMetadata: some View {
        if viewModel.nowPlayingSourcePlaylist != nil {
            Button {
                Task { await viewModel.openNowPlayingPlaylist() }
            } label: {
                metadataLabel
            }
            .buttonStyle(.plain)
            .accessibilityHint("Öppna spellistan som spelas")
        } else {
            metadataLabel
        }
    }

    private var metadataLabel: some View {
        HStack(spacing: 12) {
            AlbumArtView(urlString: speaker.entityPicture, size: 64)
            VStack(alignment: .leading, spacing: 2) {
                if let source = viewModel.nowPlayingSourcePlaylist {
                    Text("Spelas från \(source.name)")
                        .font(.caption2)
                        .foregroundStyle(.yellow.opacity(0.8))
                        .lineLimit(1)
                }
                Text(speaker.mediaTitle ?? "Inget spelas")
                    .font(.headline)
                    .lineLimit(1)
                if let artist = speaker.mediaArtist {
                    Text(artist)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
        }
        .contentShape(Rectangle())
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
                Image(systemName: speaker.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .resizable()
                    .frame(width: 54, height: 54)
            }
            .accessibilityLabel(speaker.isPlaying ? "Pausa" : "Spela")

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

/// Volume control styled like the light-brightness slider (`VerticalSlider`):
/// a custom fill bar that updates the label live while dragging and commits the
/// new volume to Home Assistant only on release (no request spam mid-drag).
/// Pass `axis: .vertical` to rotate it 90° into a tall brightness-style bar.
struct VolumeSliderView: View {
    let volume: Double
    var axis: Axis = .horizontal
    let onCommit: DoubleClosure

    @State private var dragValue: Double?

    private var displayed: Double {
        dragValue ?? volume
    }

    private var percent: Int {
        Int((displayed * 100).rounded())
    }

    private var slider: some View {
        FillSlider(fraction: displayed,
                   axis: axis,
                   onChange: { dragValue = $0 },
                   onCommit: {
                       if let dragValue {
                           onCommit(dragValue)
                       }
                       dragValue = nil
                   })
                   .accessibilityElement()
                   .accessibilityLabel("Volym")
                   .accessibilityValue("\(percent) procent")
                   .accessibilityAdjustableAction { direction in
                       let step = 0.05
                       let next = min(max(displayed + (direction == .increment ? step : -step), 0), 1)
                       onCommit(next)
                   }
    }

    private var label: some View {
        Text("\(percent)%")
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.7))
            .accessibilityHidden(true)
    }

    private var speakerIcon: some View {
        Image(systemName: "speaker.fill")
            .foregroundStyle(.white.opacity(0.7))
    }

    var body: some View {
        switch axis {
        case .horizontal:
            HStack {
                speakerIcon
                slider.frame(height: 26)
                label.frame(width: 40, alignment: .trailing)
            }
        case .vertical:
            VStack(spacing: 6) {
                label
                slider.frame(width: 36, height: 140)
                speakerIcon
            }
        }
    }
}

/// A slim-track slider with a pill thumb, the shape iOS 26 system sliders and the
/// Sonos app use for volume. Only a drag that starts on the thumb changes the
/// value, and it moves by the finger's travel rather than jumping to the touch
/// point — so brushing the track while scrolling can't blast the speakers. The
/// change is reported live and committed on release. `axis` rotates it 90°:
/// `.horizontal` fills left-to-right, `.vertical` fills bottom-to-top.
private struct FillSlider: View {
    let fraction: Double
    var axis: Axis = .horizontal
    let onChange: DoubleClosure
    let onCommit: MainActorVoidClosure

    /// The value when the thumb was grabbed; nil when no thumb drag is in progress.
    @State private var grabbedFraction: Double?
    /// Set when a drag started off the thumb, so the rest of that drag is ignored.
    @State private var isDragRejected = false

    private let trackColor = Color.white.opacity(0.18)
    private let fillColor = Color.white.opacity(0.85)
    private let trackThickness: CGFloat = 6
    /// Thumb size along and across the slider.
    private let thumbLength: CGFloat = 34
    private let thumbThickness: CGFloat = 22
    /// Half the minimum 44pt touch target, measured along the slider from the thumb centre.
    private let thumbHitRadius: CGFloat = 22

    private var isGrabbed: Bool {
        grabbedFraction != nil
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let isHorizontal = axis == .horizontal
            let length = isHorizontal ? width : height
            let travel = max(length - thumbLength, 1)
            let clamped = CGFloat(min(max(fraction, 0), 1))
            let thumbCenter = thumbLength / 2 + travel * clamped
            ZStack(alignment: isHorizontal ? .leading : .bottom) {
                ZStack(alignment: isHorizontal ? .leading : .bottom) {
                    Capsule().fill(trackColor)
                    Capsule().fill(fillColor)
                        .frame(width: isHorizontal ? thumbCenter : nil,
                               height: isHorizontal ? nil : thumbCenter)
                }
                .frame(width: isHorizontal ? nil : trackThickness,
                       height: isHorizontal ? trackThickness : nil)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isHorizontal ? .leading : .bottom)

                Capsule()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.3), radius: isGrabbed ? 6 : 3, y: 1)
                    .frame(width: isHorizontal ? thumbLength : thumbThickness,
                           height: isHorizontal ? thumbThickness : thumbLength)
                    .scaleEffect(isGrabbed ? 1.2 : 1)
                    .animation(.spring(duration: 0.2), value: isGrabbed)
                    .offset(x: isHorizontal ? thumbCenter - thumbLength / 2 : 0,
                            y: isHorizontal ? 0 : -(thumbCenter - thumbLength / 2))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isHorizontal ? .leading : .bottom)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        if grabbedFraction == nil, !isDragRejected {
                            let start = isHorizontal ? value.startLocation.x : height - value.startLocation.y
                            if abs(start - thumbCenter) <= thumbHitRadius {
                                grabbedFraction = Double(clamped)
                            } else {
                                isDragRejected = true
                            }
                        }
                        guard let grabbedFraction else { return }
                        let moved = isHorizontal ? value.translation.width : -value.translation.height
                        let next = grabbedFraction + Double(moved / travel)
                        onChange(min(max(next, 0), 1))
                    }
                    .onEnded { _ in
                        if grabbedFraction != nil {
                            onCommit()
                        }
                        grabbedFraction = nil
                        isDragRejected = false
                    }
            )
        }
    }
}
