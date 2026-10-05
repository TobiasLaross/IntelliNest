//
//  SpeakerPickerView.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-09.
//

import SwiftUI

/// Every room as a live card: what it is playing, play/pause, and its volume.
/// Tapping a card moves control to that room and leaves the others playing, so
/// different rooms can play different music. Linking a room is the only way to
/// make it play the same thing as the controlled room. Shown inline while no room
/// is controlled yet, and inside `SpeakerPickerSheet` otherwise.
struct SpeakerPickerView: View {
    @ObservedObject var viewModel: MusicViewModel
    /// Called after a room is picked, so the sheet presentation can dismiss itself.
    /// Inline presentation leaves it empty — the picker is replaced on its own.
    var onSelect: MainActorVoidClosure = {}
    /// The sheet presentation draws its own header, so it hides the inline one.
    var showsTitle = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsTitle {
                Text("Välj rum")
                    .font(.headline)
            }
            ForEach(viewModel.speakerPickerEntries) { entry in
                RoomCard(viewModel: viewModel, entry: entry, onSelect: onSelect)
            }
        }
    }
}

/// One room, or a synced group of rooms shown as one card with each member's own
/// volume nested inside so the group can still be balanced.
private struct RoomCard: View {
    @ObservedObject var viewModel: MusicViewModel
    let entry: SpeakerPickerEntry
    let onSelect: MainActorVoidClosure

    private var isControlled: Bool {
        entry.contains(viewModel.activeSpeakerID)
    }

    private var speakerID: EntityId {
        viewModel.controlledSpeakerID(in: entry)
    }

    private var shown: MediaPlayerEntity? {
        viewModel.displayedSpeaker(speakerID)
    }

    /// A lone room can be linked into the controlled room's music. Groups are
    /// left alone: linking one would silently break up whatever it is playing.
    private var canLink: Bool {
        viewModel.activeSpeakerID != nil && !isControlled && !entry.isGroup
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                selectButton
                if shown?.hasLiveAudio == true {
                    playPauseButton
                }
            }

            VolumeSliderView(volume: entry.averageVolume,
                             onCommit: { viewModel.setGroupVolume($0, for: entry) })
                .accessibilityLabel(entry.isGroup ? "Gruppvolym \(entry.title)" : "Volym \(entry.title)")

            if entry.isGroup {
                ForEach(entry.members, id: \.entityId) { member in
                    RoomMemberRow(viewModel: viewModel, speaker: member, canUnlink: isControlled)
                }
            }

            if canLink {
                linkButton
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.yellow.opacity(isControlled ? 0.8 : 0), lineWidth: 2)
        )
    }

    private var selectButton: some View {
        Button {
            viewModel.selectRoom(entry)
            onSelect()
        } label: {
            HStack(spacing: 12) {
                AlbumArtView(urlString: shown?.hasLiveAudio == true ? shown?.entityPicture : nil, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(entry.title)
                            .font(.headline)
                            .foregroundStyle(isControlled ? .yellow : .white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        if isControlled {
                            Text("Styrs nu")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(.yellow))
                        }
                    }
                    Text(shown?.roomStatusText ?? "Tyst")
                        .font(.caption)
                        .foregroundStyle(shown?.isPlaying == true ? .white.opacity(0.85) : .white.opacity(0.55))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Styr \(entry.title)")
        .accessibilityValue(shown?.roomStatusText ?? "Tyst")
        .accessibilityAddTraits(isControlled ? [.isSelected] : [])
    }

    private var playPauseButton: some View {
        let isPlaying = shown?.isPlaying == true
        return Button {
            viewModel.togglePlayPause(for: speakerID)
        } label: {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(.black)
                .frame(width: 38, height: 38)
                .background(Circle().fill(.white))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? "Pausa \(entry.title)" : "Spela \(entry.title)")
    }

    private var linkButton: some View {
        let isPending = viewModel.pendingGroupingSpeakers.contains(entry.leader.entityId)
        return Button {
            Task { await viewModel.toggleGroupMember(entry.leader.entityId) }
        } label: {
            HStack(spacing: 6) {
                if isPending {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(.yellow)
                } else {
                    Image(systemName: "link")
                }
                Text("Spela samma som \(viewModel.controlledRoomTitle)")
                    .lineLimit(1)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.yellow)
            .frame(minHeight: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isPending)
        .accessibilityLabel("Länka \(entry.title) till \(viewModel.controlledRoomTitle)")
    }
}

/// A member of a synced group: its name, its own volume, and — in the controlled
/// room's group — a button that takes it out of the group.
private struct RoomMemberRow: View {
    @ObservedObject var viewModel: MusicViewModel
    let speaker: MediaPlayerEntity
    let canUnlink: Bool

    var body: some View {
        let isPending = viewModel.pendingGroupingSpeakers.contains(speaker.entityId)
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text(speaker.friendlyName)
                    .font(.subheadline)
                if speaker.isPlaying {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .accessibilityLabel("Spelar nu")
                }
                Spacer(minLength: 8)
                if canUnlink {
                    Button {
                        Task { await unlink() }
                    } label: {
                        Group {
                            if isPending {
                                ProgressView()
                                    .controlSize(.mini)
                                    .tint(.yellow)
                            } else {
                                Image(systemName: "link.badge.minus")
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                        .frame(width: 44, height: 32)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isPending)
                    .accessibilityLabel("Ta bort \(speaker.friendlyName) ur gruppen")
                }
            }
            VolumeSliderView(volume: speaker.volumeLevel,
                             onCommit: { viewModel.setVolume($0, for: speaker.entityId) })
                .accessibilityLabel("Volym \(speaker.friendlyName)")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// The controlled speaker leaving its group hands control to the next member,
    /// so the room still playing stays the one being controlled.
    private func unlink() async {
        if speaker.entityId == viewModel.activeSpeakerID {
            await viewModel.removeActiveSpeakerFromGroup()
        } else {
            await viewModel.toggleGroupMember(speaker.entityId)
        }
    }
}

/// The rooms presented as a dismissable sheet, opened from the player's room pill.
struct SpeakerPickerSheet: View {
    @ObservedObject var viewModel: MusicViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Rum")
                    .font(.title3.bold())
                Spacer()
                Button("Klar") { dismiss() }
            }
            .padding(.horizontal)
            .padding(.top, 24)
            Text("Tryck på ett rum för att styra det. De andra rummen fortsätter spela.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 12)

            ScrollView {
                SpeakerPickerView(viewModel: viewModel, onSelect: { dismiss() }, showsTitle: false)
                    .padding(.horizontal)
                    .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .backgroundModifier()
        .foregroundStyle(.white)
        .presentationDragIndicator(.visible)
    }
}
