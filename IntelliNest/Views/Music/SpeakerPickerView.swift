//
//  SpeakerPickerView.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-09.
//

import SwiftUI

/// Lists the available speakers so the user can pick one to control. Shown
/// inline while no speaker is active, and inside `SpeakerPickerSheet` when the
/// user changes speaker from an already-playing screen.
struct SpeakerPickerView: View {
    @ObservedObject var viewModel: MusicViewModel
    /// Called after a speaker is picked, so the sheet presentation can dismiss
    /// itself. Inline presentation leaves it empty — the picker is replaced by
    /// the now-playing card on its own.
    var onSelect: MainActorVoidClosure = {}
    /// The sheet presentation draws its own header, so it hides the inline one.
    var showsTitle = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsTitle {
                Text("Välj högtalare")
                    .font(.headline)
            }
            ForEach(viewModel.speakerPickerEntries) { entry in
                if entry.isGroup {
                    SpeakerPickerGroupCard(viewModel: viewModel, entry: entry, onSelect: onSelect)
                } else {
                    SpeakerPickerRow(viewModel: viewModel, speaker: entry.leader, onSelect: onSelect)
                        .speakerPickerCard(isActive: entry.contains(viewModel.activeSpeakerID))
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

/// A synced Music Assistant group as one card: a header naming the group (leader
/// first) that selects the leader, a slider setting every member at once, and each
/// member's own row nested inside so the group can still be balanced.
private struct SpeakerPickerGroupCard: View {
    @ObservedObject var viewModel: MusicViewModel
    let entry: SpeakerPickerEntry
    let onSelect: MainActorVoidClosure

    private var isActive: Bool {
        entry.contains(viewModel.activeSpeakerID)
    }

    var body: some View {
        VStack(spacing: 10) {
            Button {
                viewModel.selectSpeaker(entry.leader.entityId)
                onSelect()
            } label: {
                HStack {
                    Image(systemName: "hifispeaker.2.fill")
                    Text(entry.title)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    if entry.members.contains(where: \.isPlaying) {
                        playingMark
                    }
                    chevron
                }
            }
            .foregroundStyle(isActive ? .yellow : .white)
            .accessibilityLabel("Välj gruppen \(entry.title)")
            .accessibilityAddTraits(isActive ? [.isSelected] : [])

            VolumeSliderView(volume: entry.averageVolume,
                             onCommit: { viewModel.setGroupVolume($0, for: entry) })
                .accessibilityLabel("Gruppvolym \(entry.title)")

            ForEach(entry.members, id: \.entityId) { speaker in
                SpeakerPickerRow(viewModel: viewModel, speaker: speaker, onSelect: onSelect)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
            }
        }
        .speakerPickerCard(isActive: isActive)
    }
}

/// One speaker: a button that selects it, tinted yellow while it's the active
/// speaker, above its own volume slider. Shown as a card of its own, or nested in
/// a group card.
private struct SpeakerPickerRow: View {
    @ObservedObject var viewModel: MusicViewModel
    let speaker: MediaPlayerEntity
    let onSelect: MainActorVoidClosure

    var body: some View {
        let isActive = speaker.entityId == viewModel.activeSpeakerID
        VStack(spacing: 8) {
            Button {
                viewModel.selectSpeaker(speaker.entityId)
                onSelect()
            } label: {
                HStack {
                    Image(systemName: "hifispeaker.fill")
                    Text(speaker.friendlyName)
                    Spacer()
                    if speaker.isPlaying {
                        playingMark
                    }
                    chevron
                }
            }
            // The speaker in control right now is tinted yellow, matching the
            // now-playing card, so "byt högtalare" starts from a visible
            // current selection instead of an undifferentiated list.
            .foregroundStyle(isActive ? .yellow : .white)
            .accessibilityLabel("Välj \(speaker.friendlyName)")
            .accessibilityAddTraits(isActive ? [.isSelected] : [])

            VolumeSliderView(volume: speaker.volumeLevel,
                             onCommit: { viewModel.setVolume($0, for: speaker.entityId) })
                .accessibilityLabel("Volym \(speaker.friendlyName)")
        }
    }
}

private var playingMark: some View {
    Image(systemName: "speaker.wave.2.fill")
        .foregroundStyle(.green)
        .accessibilityLabel("Spelar nu")
}

private var chevron: some View {
    Image(systemName: "chevron.right")
        .font(.caption)
        .foregroundStyle(.white.opacity(0.5))
}

private extension View {
    /// The card chrome shared by single speakers and groups, outlined in yellow
    /// when it holds the active speaker.
    func speakerPickerCard(isActive: Bool) -> some View {
        padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color.white.opacity(0.08))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.yellow.opacity(isActive ? 0.7 : 0), lineWidth: 2)
            )
    }
}

/// The speaker picker presented as a dismissable sheet. Used when a speaker is
/// already active: the picker is a screen-level action, not part of the
/// now-playing card, and closing it must return to the music screen rather than
/// popping the whole navigation stack back home.
struct SpeakerPickerSheet: View {
    @ObservedObject var viewModel: MusicViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Välj högtalare")
                    .font(.title3.bold())
                Spacer()
                Button("Stäng") { dismiss() }
            }
            .padding(.horizontal)
            .padding(.top, 24)
            .padding(.bottom, 12)

            ScrollView {
                SpeakerPickerView(viewModel: viewModel, onSelect: { dismiss() }, showsTitle: false)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .backgroundModifier()
        .foregroundStyle(.white)
        .presentationDragIndicator(.visible)
    }
}
