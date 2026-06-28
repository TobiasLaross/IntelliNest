//
//  SeekBarView.swift
//  IntelliNest
//
//  Created by Tobias on 2026-06-28.
//

import SwiftUI

/// Formats a playback time as `m:ss` (or `h:mm:ss` once past an hour). Kept as a
/// pure, free-standing helper so the elapsed/remaining labels are unit-testable
/// without a view. Negative inputs clamp to zero.
enum PlaybackTimeFormat {
    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(max(seconds, 0).rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}

/// An Apple-Music-style scrubber for the now-playing card: a thin track with a
/// draggable thumb, the elapsed time on the left and the remaining time (`-m:ss`)
/// on the right. The thumb advances live from the speaker's extrapolated position
/// while playing; during a drag the dragged position wins and the seek is sent
/// only on release (no request spam mid-drag, matching `VolumeSliderView`).
///
/// Hidden entirely when the source reports no length (`mediaDuration` nil/0), e.g.
/// a live stream, where seeking is meaningless.
struct SeekBarView: View {
    let speaker: MediaPlayerEntity
    @ObservedObject var viewModel: MusicViewModel

    /// The fraction (0...1) the user is dragging to, or nil when not dragging.
    @State private var dragFraction: Double?

    var body: some View {
        if let duration = speaker.mediaDuration, duration > 0 {
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                let liveElapsed = speaker.currentElapsed(asOf: context.date) ?? 0
                let elapsed = dragFraction.map { $0 * duration } ?? liveElapsed
                let fraction = min(max(elapsed / duration, 0), 1)
                content(duration: duration, elapsed: elapsed, fraction: fraction)
            }
        }
    }

    private func content(duration: Double, elapsed: Double, fraction: Double) -> some View {
        VStack(spacing: 2) {
            track(fraction: fraction, duration: duration)
            HStack {
                Text(PlaybackTimeFormat.clock(elapsed))
                Spacer()
                Text("-\(PlaybackTimeFormat.clock(duration - elapsed))")
            }
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.6))
        }
    }

    private func track(fraction: Double, duration: Double) -> some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let thumbSize: CGFloat = 12
            // Keep the thumb fully inside the track at both ends.
            let travel = max(width - thumbSize, 0)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .frame(height: 4)
                Capsule()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: max(width * fraction, 0), height: 4)
                Circle()
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(x: travel * fraction)
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        dragFraction = clampedFraction(value.location.x, width: width)
                    }
                    .onEnded { value in
                        let target = clampedFraction(value.location.x, width: width) * duration
                        viewModel.seek(to: target)
                        dragFraction = nil
                    }
            )
        }
        .frame(height: 24)
        .accessibilityElement()
        .accessibilityLabel("Spelposition")
        .accessibilityValue(PlaybackTimeFormat.clock(fraction * duration))
        .accessibilityAdjustableAction { direction in
            let step = 5.0
            let current = fraction * duration
            let next = direction == .increment ? current + step : current - step
            viewModel.seek(to: min(max(next, 0), duration))
        }
    }

    private func clampedFraction(_ locationX: CGFloat, width: CGFloat) -> Double {
        guard width > 0 else {
            return 0
        }
        return Double(min(max(locationX / width, 0), 1))
    }
}
