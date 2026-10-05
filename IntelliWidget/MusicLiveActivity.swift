//
//  MusicLiveActivity.swift
//  IntelliWidget
//
//  Created by Tobias on 2026-10-05.
//

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct MusicLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MusicActivityAttributes.self) { context in
            MusicLockScreenView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.45))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(MusicActivityLink.nowPlayingURL)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    MusicArtworkView(fileName: context.state.artworkFileName, side: 52)
                }
                DynamicIslandExpandedRegion(.center) {
                    MusicTrackTitleView(state: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    MusicVolumeBadge(volume: context.state.groupVolume)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        MusicProgressView(state: context.state)
                        MusicControlsView(state: context.state)
                    }
                }
            } compactLeading: {
                MusicArtworkView(fileName: context.state.artworkFileName, side: 24)
            } compactTrailing: {
                Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
                    .foregroundStyle(.white.opacity(0.8))
            } minimal: {
                MusicArtworkView(fileName: context.state.artworkFileName, side: 24)
            }
            .widgetURL(MusicActivityLink.nowPlayingURL)
        }
    }
}

private struct MusicLockScreenView: View {
    let state: MusicActivityAttributes.ContentState

    var body: some View {
        // Kept within the 160 pt the lock screen allows, even with a two-line title.
        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                MusicArtworkView(fileName: state.artworkFileName, side: 56)
                VStack(alignment: .leading, spacing: 2) {
                    MusicTrackTitleView(state: state)
                    MusicVolumeBadge(roomName: state.roomName, volume: state.groupVolume)
                }
            }
            MusicProgressView(state: state)
            MusicControlsView(state: state)
        }
        .padding(12)
        .foregroundStyle(.white)
    }
}

private struct MusicTrackTitleView: View {
    let state: MusicActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // A Live Activity can't scroll text, so a long title wraps to a second line and shrinks a little
            // before it would ever truncate.
            Text(state.title)
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
            if let artist = state.artist, !artist.isEmpty {
                Text(artist)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MusicVolumeBadge: View {
    var roomName: String?
    let volume: Double

    private var percent: Int {
        Int((volume * 100).rounded())
    }

    var body: some View {
        Label {
            Text([roomName, "\(percent) %"].compactMap { $0 }.joined(separator: " · "))
        } icon: {
            Image(systemName: "hifispeaker.fill")
        }
        .font(.caption2.monospacedDigit())
        .lineLimit(1)
        .foregroundStyle(.white.opacity(0.6))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(roomName ?? "") gruppvolym \(percent) procent")
    }
}

private struct MusicArtworkView: View {
    let fileName: String?
    let side: CGFloat

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.white.opacity(0.1)
                    Image(systemName: "music.note")
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: side > 30 ? 8 : 5))
    }

    private var image: UIImage? {
        guard let fileName, let url = MusicActivityArtwork.fileURL(named: fileName) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }
}

/// The scrubber, read-only. While playing, the bar and both times are timer-driven so they keep moving between the
/// app's updates; while paused they are fixed at the paused position.
private struct MusicProgressView: View {
    let state: MusicActivityAttributes.ContentState

    var body: some View {
        if let duration = state.duration, duration > 0 {
            HStack(spacing: 10) {
                if state.isPlaying, let start = state.trackStart {
                    let end = start.addingTimeInterval(duration)
                    Text(timerInterval: start ... end, countsDown: false)
                        .frame(width: 40, alignment: .leading)
                    ProgressView(timerInterval: start ... end, countsDown: false) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                    HStack(spacing: 0) {
                        Text("-")
                        Text(timerInterval: start ... end, countsDown: true)
                    }
                    .frame(width: 44, alignment: .trailing)
                } else {
                    let elapsed = state.elapsed(asOf: .now) ?? 0
                    Text(Self.format(elapsed))
                        .frame(width: 40, alignment: .leading)
                    ProgressView(value: elapsed, total: duration)
                    Text("-" + Self.format(duration - elapsed))
                        .frame(width: 44, alignment: .trailing)
                }
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.white.opacity(0.6))
            .tint(.white.opacity(0.8))
        }
    }

    private static func format(_ seconds: Double) -> String {
        let total = Int(max(seconds, 0).rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct MusicControlsView: View {
    let state: MusicActivityAttributes.ContentState

    var body: some View {
        HStack {
            control(.volumeDown, systemImage: "speaker.minus.fill", label: "Sänk gruppvolymen", size: 18)
            Spacer()
            control(.previousTrack, systemImage: "backward.fill", label: "Föregående", size: 24)
            Spacer()
            control(.playPause,
                    systemImage: state.isPlaying ? "pause.fill" : "play.fill",
                    label: state.isPlaying ? "Pausa" : "Spela",
                    size: 28)
            Spacer()
            control(.nextTrack, systemImage: "forward.fill", label: "Nästa", size: 24)
            Spacer()
            control(.volumeUp, systemImage: "speaker.plus.fill", label: "Höj gruppvolymen", size: 18)
        }
        .foregroundStyle(.white)
    }

    private func control(_ command: MusicActivityCommand, systemImage: String, label: String, size: CGFloat) -> some View {
        Button(intent: MusicActivityCommandIntent(command)) {
            Image(systemName: systemImage)
                .font(.system(size: size))
                .frame(width: 44, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
