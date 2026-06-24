//
//  GroupVolumeView.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-09.
//

import SwiftUI

/// The speaker & volume control on the now-playing card. The top slider sets the
/// active speaker — or the whole group when grouped — at once. The chevron expands
/// a per-speaker list where speakers are added to or removed from the group,
/// promoted to primary, and balanced individually. Folding grouping in here
/// replaces the old separate "Gruppera högtalare" card.
struct GroupVolumeView: View {
    @ObservedObject var viewModel: MusicViewModel
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 16)
                }
                .accessibilityLabel(isExpanded ? "Dölj högtalare" : "Visa högtalare")

                VolumeSliderView(volume: viewModel.groupVolume,
                                 onCommit: { viewModel.setGroupVolume($0) })
                    .accessibilityLabel(viewModel.isGroupActive ? "Gruppvolym" : "Volym")
            }

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(viewModel.availableSpeakers, id: \.entityId) { speaker in
                        SpeakerVolumeRow(viewModel: viewModel,
                                         speaker: speaker,
                                         isPrimary: speaker.entityId == viewModel.activeSpeakerID)
                    }
                }
            }
        }
    }
}

/// One speaker in the expanded list. The checkmark toggles the speaker in and out
/// of the active speaker's group (removing the primary promotes the next member);
/// the "Primär" chip marks the leader — a tappable outline on a follower promotes
/// it. Grouped speakers also get their own slider so the group can be balanced.
private struct SpeakerVolumeRow: View {
    @ObservedObject var viewModel: MusicViewModel
    let speaker: MediaPlayerEntity
    let isPrimary: Bool

    // The primary is always part of its own group; followers reflect membership.
    private var grouped: Bool {
        isPrimary || viewModel.isGrouped(speaker.entityId)
    }

    // A join/unjoin for this speaker is still settling, so show a spinner and hold
    // off further taps until the membership refreshes.
    private var isPending: Bool {
        viewModel.pendingGroupingSpeakers.contains(speaker.entityId)
    }

    // The per-speaker slider only earns its space while there's a real group to
    // balance; alone, the top slider already controls the single active speaker.
    private var showsVolume: Bool {
        grouped && viewModel.isGroupActive
    }

    private var toggleAccessibilityLabel: String {
        if isPrimary {
            return "Ta bort \(speaker.friendlyName) som primär högtalare ur gruppen"
        }
        return "\(grouped ? "Ta bort" : "Lägg till") \(speaker.friendlyName) i gruppen"
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // The whole row toggles membership, so this is just a status mark —
                // a checkmark when grouped, empty (space-reserved so names stay
                // aligned) otherwise. Not a control of its own.
                Button(action: toggle) {
                    HStack(spacing: 8) {
                        Group {
                            if isPending {
                                ProgressView()
                                    .controlSize(.mini)
                                    .tint(.yellow)
                            } else {
                                Image(systemName: "checkmark")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.yellow)
                                    .opacity(grouped ? 1 : 0)
                            }
                        }
                        .frame(width: 18)
                        Text(speaker.friendlyName)
                            .font(.subheadline)
                        if speaker.isPlaying {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                                .accessibilityLabel("Spelar nu")
                        }
                        Spacer(minLength: 8)
                        // The current primary's chip rides along with the row tap
                        // (which removes it); a follower's chip is a separate button.
                        if isPrimary {
                            primaryChip(filled: true)
                        }
                    }
                    .frame(minHeight: 28)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isPending)
                .accessibilityLabel(toggleAccessibilityLabel)
                .accessibilityValue(isPending ? "Uppdaterar" : (grouped ? "Grupperad" : "Inte grupperad"))

                if grouped, !isPrimary {
                    Button {
                        viewModel.makePrimary(speaker.entityId)
                    } label: {
                        primaryChip(filled: false)
                    }
                    .buttonStyle(.plain)
                    .disabled(isPending)
                    .accessibilityLabel("Gör \(speaker.friendlyName) till primär högtalare")
                }
            }

            if showsVolume {
                VolumeSliderView(volume: speaker.volumeLevel,
                                 onCommit: { viewModel.setVolume($0, for: speaker.entityId) })
                    .accessibilityLabel("Volym \(speaker.friendlyName)")
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
