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

    /// The grouped speakers as a one-line summary, primary first
    /// (e.g. "Kitchen, Matbord-ute"), shown under the collapsed slider so the
    /// group is visible without expanding. Empty when nothing is grouped.
    private var groupSummary: String {
        guard viewModel.isGroupActive else {
            return ""
        }
        let primaryName = viewModel.availableSpeakers
            .first { $0.entityId == viewModel.activeSpeakerID }?.friendlyName
        let followerNames = viewModel.groupedSpeakers
            .filter { $0.entityId != viewModel.activeSpeakerID }
            .map(\.friendlyName)
        return ([primaryName].compactMap { $0 } + followerNames).joined(separator: ", ")
    }

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

            // While collapsed, name the grouped speakers under the slider — the same
            // summary the old grouping card showed — so the group is legible at a
            // glance. Aligned with the slider (past the chevron) and kept to one line.
            if !isExpanded, groupSummary.isNotEmpty {
                Text(groupSummary)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 26)
                    .accessibilityLabel("Grupperade högtalare: \(groupSummary)")
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

    // A follower can always be tapped to join or leave; the primary can only be
    // tapped to leave once a real group exists. Alone there's nothing to ungroup,
    // so the primary row is inert (no dead "remove from group" tap, no misleading
    // VoiceOver action) rather than a no-op button.
    private var canToggle: Bool {
        isPrimary ? viewModel.isGroupActive : true
    }

    private var toggleAccessibilityLabel: String {
        if isPrimary {
            return viewModel.isGroupActive
                ? "Ta bort \(speaker.friendlyName) som primär högtalare ur gruppen"
                : "\(speaker.friendlyName), primär högtalare"
        }
        return "\(grouped ? "Ta bort" : "Lägg till") \(speaker.friendlyName) i gruppen"
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // The lone primary has nothing to ungroup, so its row is plain
                // status — not a button; everyone else taps to join or leave.
                if canToggle {
                    Button(action: toggle) { membershipMark }
                        .buttonStyle(.plain)
                        .disabled(isPending)
                        .accessibilityLabel(toggleAccessibilityLabel)
                        .accessibilityValue(isPending ? "Uppdaterar" : (grouped ? "Grupperad" : "Inte grupperad"))
                } else {
                    membershipMark
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(toggleAccessibilityLabel)
                }

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

    /// The status content of the row: the grouped checkmark (or a spinner while a
    /// join/unjoin settles), the speaker name, a now-playing mark, and the primary's
    /// solid chip. The checkmark is a status mark, not a control — the row tap (when
    /// present) owns the membership toggle.
    private var membershipMark: some View {
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
            if isPrimary {
                primaryChip(filled: true)
            }
        }
        .frame(minHeight: 28)
        .contentShape(Rectangle())
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
