//
//  SpeakerGroupingView.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-09.
//

import SwiftUI

/// Sonos-style grouping: the active speaker is the leader, and the other
/// available speakers can be toggled into or out of its group.
struct SpeakerGroupingView: View {
    @ObservedObject var viewModel: MusicViewModel

    private var otherSpeakers: [MediaPlayerEntity] {
        viewModel.availableSpeakers.filter { $0.entityId != viewModel.activeSpeakerID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gruppera högtalare")
                .font(.headline)
            ForEach(otherSpeakers, id: \.entityId) { speaker in
                let grouped = viewModel.isGrouped(speaker.entityId)
                VStack(spacing: 8) {
                    Button {
                        viewModel.toggleGroupMember(speaker.entityId)
                    } label: {
                        HStack {
                            Image(systemName: grouped ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(grouped ? .yellow : .white.opacity(0.6))
                            Text(speaker.friendlyName)
                            if speaker.isPlaying {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                    .accessibilityLabel("Spelar nu")
                            }
                            Spacer()
                        }
                    }
                    .accessibilityLabel("\(grouped ? "Ta bort" : "Lägg till") \(speaker.friendlyName) i gruppen")
                    .accessibilityValue(grouped ? "Grupperad" : "Inte grupperad")

                    VolumeSliderView(volume: speaker.volumeLevel,
                                     onChange: { viewModel.setVolume($0, for: speaker.entityId) })
                        .accessibilityLabel("Volym \(speaker.friendlyName)")
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(grouped ? Color.yellow.opacity(0.12) : Color.white.opacity(0.06))
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}
