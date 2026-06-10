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
                             onChange: { viewModel.setVolume($0) })
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

struct VolumeSliderView: View {
    let volume: Double
    let onChange: DoubleClosure

    var body: some View {
        HStack {
            Image(systemName: "speaker.fill")
                .foregroundStyle(.white.opacity(0.7))
            Slider(value: Binding(get: { volume }, set: { onChange($0) }), in: 0 ... 1)
                .accessibilityLabel("Volym")
            Image(systemName: "speaker.wave.3.fill")
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
