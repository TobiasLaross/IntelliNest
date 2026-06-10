//
//  SpeakerPickerView.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-09.
//

import SwiftUI

/// Shown when no speaker is active. Lists the available speakers so the user can
/// pick one to control.
struct SpeakerPickerView: View {
    @ObservedObject var viewModel: MusicViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Välj högtalare")
                .font(.headline)
            ForEach(viewModel.availableSpeakers, id: \.entityId) { speaker in
                VStack(spacing: 8) {
                    Button {
                        viewModel.selectSpeaker(speaker.entityId)
                    } label: {
                        HStack {
                            Image(systemName: "hifispeaker.fill")
                            Text(speaker.friendlyName)
                            Spacer()
                            if speaker.isPlaying {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundStyle(.green)
                                    .accessibilityLabel("Spelar nu")
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .accessibilityLabel("Välj \(speaker.friendlyName)")

                    VolumeSliderView(volume: speaker.volumeLevel,
                                     onCommit: { viewModel.setVolume($0, for: speaker.entityId) })
                        .accessibilityLabel("Volym \(speaker.friendlyName)")
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.08))
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}
