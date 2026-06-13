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

    /// The rows to show: every available speaker, but the active (primary) one is
    /// only listed while it's grouped with others — so it can be removed, which
    /// promotes another speaker to primary. Alone, removing it would be a no-op,
    /// so it stays out of the list.
    private var listedSpeakers: [MediaPlayerEntity] {
        viewModel.availableSpeakers.filter { $0.entityId != viewModel.activeSpeakerID || viewModel.isGroupActive }
    }

    /// Names of the speakers grouped with the active one, used for the collapsed
    /// summary line.
    private var groupedNames: [String] {
        otherSpeakers.filter { viewModel.isGrouped($0.entityId) }.map(\.friendlyName)
    }

    /// The active (primary) speaker's name, sourced the same way as the other
    /// rows so the summary reads consistently.
    private var activeSpeakerName: String? {
        viewModel.availableSpeakers.first { $0.entityId == viewModel.activeSpeakerID }?.friendlyName
    }

    /// The collapsed summary lists the whole playback group, active speaker first
    /// (e.g. "Kitchen, Gästrummet, Lekrummet"), or notes that nothing is grouped.
    private var summary: String {
        guard !groupedNames.isEmpty else {
            return "Inga grupperade"
        }
        return ([activeSpeakerName].compactMap { $0 } + groupedNames).joined(separator: ", ")
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
                ForEach(listedSpeakers, id: \.entityId) { speaker in
                    SpeakerGroupingRow(viewModel: viewModel,
                                       speaker: speaker,
                                       isPrimary: speaker.entityId == viewModel.activeSpeakerID)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

/// A single grouping row. Tapping the row adds/removes the speaker (removing the
/// primary promotes the next grouped speaker). Each grouped row carries a "Primär"
/// chip — solid on the current primary, a tappable outline on followers that
/// promotes them. Volume lives in the group-volume control on the now-playing
/// card above, so the row carries no slider.
private struct SpeakerGroupingRow: View {
    @ObservedObject var viewModel: MusicViewModel
    let speaker: MediaPlayerEntity
    let isPrimary: Bool

    // The primary is always part of its own group; followers reflect membership.
    private var grouped: Bool {
        isPrimary || viewModel.isGrouped(speaker.entityId)
    }

    private var toggleAccessibilityLabel: String {
        if isPrimary {
            return "Ta bort \(speaker.friendlyName) som primär högtalare ur gruppen"
        }
        return "\(grouped ? "Ta bort" : "Lägg till") \(speaker.friendlyName) i gruppen"
    }

    var body: some View {
        HStack(spacing: 8) {
            // The whole row toggles membership, so this is just a status mark —
            // a plain checkmark when grouped, empty (but space-reserved so names
            // stay aligned) otherwise. Not a control of its own.
            Button(action: toggle) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.yellow)
                        .opacity(grouped ? 1 : 0)
                        .frame(width: 18)
                    Text(speaker.friendlyName)
                    if speaker.isPlaying {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .accessibilityLabel("Spelar nu")
                    }
                    Spacer(minLength: 8)
                    // The current primary's chip rides along with the row tap (which
                    // removes it); a follower's chip is a separate promote button.
                    if isPrimary {
                        primaryChip(filled: true)
                    }
                }
                .frame(minHeight: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(toggleAccessibilityLabel)
            .accessibilityValue(grouped ? "Grupperad" : "Inte grupperad")

            if grouped, !isPrimary {
                Button {
                    viewModel.makePrimary(speaker.entityId)
                } label: {
                    primaryChip(filled: false)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Gör \(speaker.friendlyName) till primär högtalare")
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(grouped ? Color.yellow.opacity(0.12) : Color.white.opacity(0.06))
        .cornerRadius(10)
    }

    /// The "Primär" pill. Solid yellow marks the current primary; an outline marks
    /// a follower that can be promoted by tapping it.
    private func primaryChip(filled: Bool) -> some View {
        Text("Primär")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(filled ? .black : .yellow.opacity(0.9))
            .background {
                if filled {
                    Capsule().fill(.yellow.opacity(0.9))
                } else {
                    Capsule().stroke(.yellow.opacity(0.55), lineWidth: 1)
                }
            }
            .contentShape(Capsule())
    }

    private func toggle() {
        Task {
            if isPrimary {
                await viewModel.removeActiveSpeakerFromGroup()
            } else {
                await viewModel.toggleGroupMember(speaker.entityId)
            }
        }
    }
}
