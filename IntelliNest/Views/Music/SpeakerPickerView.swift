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
            ForEach(viewModel.availableSpeakers, id: \.entityId) { speaker in
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
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundStyle(.green)
                                    .accessibilityLabel("Spelar nu")
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
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
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.08))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.yellow.opacity(isActive ? 0.7 : 0), lineWidth: 2)
                )
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
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
