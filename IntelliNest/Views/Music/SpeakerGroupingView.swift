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
    @State private var isExpanded = false

    private var otherSpeakers: [MediaPlayerEntity] {
        viewModel.availableSpeakers.filter { $0.entityId != viewModel.activeSpeakerID }
    }

    /// Names of the speakers grouped with the active one, used for the collapsed
    /// summary line.
    private var groupedNames: [String] {
        otherSpeakers.filter { viewModel.isGrouped($0.entityId) }.map(\.friendlyName)
    }

    private var summary: String {
        groupedNames.isEmpty ? "Inga grupperade" : groupedNames.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gruppera högtalare")
                            .font(.headline)
                        if !isExpanded {
                            Text(summary)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.white.opacity(0.7))
                }
                .foregroundStyle(.white)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Gruppera högtalare")
            .accessibilityValue(isExpanded ? "Expanderad" : "Hopfälld. \(summary)")

            if isExpanded {
                ForEach(otherSpeakers, id: \.entityId) { speaker in
                    let grouped = viewModel.isGrouped(speaker.entityId)
                    VStack(spacing: 8) {
                        Button {
                            Task { await viewModel.toggleGroupMember(speaker.entityId) }
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
                                         onCommit: { viewModel.setVolume($0, for: speaker.entityId) })
                            .accessibilityLabel("Volym \(speaker.friendlyName)")
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(grouped ? Color.yellow.opacity(0.12) : Color.white.opacity(0.06))
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}
