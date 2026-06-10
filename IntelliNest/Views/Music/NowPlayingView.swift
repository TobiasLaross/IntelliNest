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
                Image(systemName: "hifispeaker.fill")
                    .foregroundStyle(.yellow)
                Text(speaker.friendlyName)
                    .font(.headline)
                    .foregroundStyle(.yellow)
                    .lineLimit(1)
                Spacer()
                Button {
                    viewModel.activeSpeakerID = nil
                } label: {
                    Image(systemName: "hifispeaker.2.fill")
                }
                .accessibilityLabel("Byt högtalare")
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Vald högtalare: \(speaker.friendlyName)")

            HStack(spacing: 12) {
                AlbumArtView(urlString: speaker.entityPicture, size: 64)
                VStack(alignment: .leading, spacing: 2) {
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
                Spacer()
            }

            TransportControlsView(speaker: speaker, viewModel: viewModel)

            VolumeSliderView(volume: speaker.volumeLevel,
                             onCommit: { viewModel.setVolume($0) })
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.yellow.opacity(0.7), lineWidth: 2)
        )
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
struct VolumeSliderView: View {
    let volume: Double
    let onCommit: DoubleClosure

    @State private var dragValue: Double?

    private var displayed: Double {
        dragValue ?? volume
    }

    private var percent: Int {
        Int((displayed * 100).rounded())
    }

    var body: some View {
        HStack {
            Image(systemName: "speaker.fill")
                .foregroundStyle(.white.opacity(0.7))
            HorizontalFillSlider(fraction: displayed,
                                 onChange: { dragValue = $0 },
                                 onCommit: {
                                     if let dragValue {
                                         onCommit(dragValue)
                                     }
                                     dragValue = nil
                                 })
                                 .frame(height: 26)
                                 .accessibilityElement()
                                 .accessibilityLabel("Volym")
                                 .accessibilityValue("\(percent) procent")
                                 .accessibilityAdjustableAction { direction in
                                     let step = 0.05
                                     let next = min(max(displayed + (direction == .increment ? step : -step), 0), 1)
                                     onCommit(next)
                                 }
            Text("\(percent)%")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 40, alignment: .trailing)
                .accessibilityHidden(true)
        }
    }
}

/// A horizontal fill slider mirroring `VerticalSlider`'s look (dark track, light
/// fill, thin border). Tapping or dragging sets the value from the touch x; the
/// change is reported live and committed on release.
private struct HorizontalFillSlider: View {
    let fraction: Double
    let onChange: DoubleClosure
    let onCommit: MainActorVoidClosure

    private let trackColor = Color(white: 57.0 / 255).opacity(0.3)
    private let fillColor = Color(white: 201.0 / 255)

    var body: some View {
        GeometryReader { geometry in
            let clamped = min(max(fraction, 0), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(trackColor)
                Capsule().fill(fillColor)
                    .frame(width: geometry.size.width * clamped)
            }
            .overlay(Capsule().stroke(.black.opacity(0.5), lineWidth: 1))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        onChange(min(max(value.location.x / geometry.size.width, 0), 1))
                    }
                    .onEnded { _ in onCommit() }
            )
        }
    }
}
