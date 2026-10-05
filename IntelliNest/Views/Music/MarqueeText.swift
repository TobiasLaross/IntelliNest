//
//  MarqueeText.swift
//  IntelliNest
//
//  Created by Tobias on 2026-10-05.
//

import SwiftUI

/// Where a marquee's text sits at a given moment. Kept apart from the view so the
/// timing can be tested by passing elapsed seconds instead of waiting for them.
struct MarqueeScroll: Equatable {
    let textWidth: CGFloat
    let containerWidth: CGFloat
    /// Space between the end of the text and the copy that follows it in.
    var gap: CGFloat = 40
    var pointsPerSecond: CGFloat = 30
    /// How long the text rests at its start before each pass.
    var pause: TimeInterval = 2.5

    /// Half a point of slack so rounding in text measurement can't start a
    /// scroll for a title that fits.
    var overflows: Bool {
        textWidth > containerWidth + 0.5
    }

    /// How far one pass moves: the text plus the gap, which brings the trailing
    /// copy to exactly where the text started.
    var distance: CGFloat {
        textWidth + gap
    }

    var cycleDuration: TimeInterval {
        pause + TimeInterval(distance / pointsPerSecond)
    }

    /// The horizontal offset `elapsed` seconds after the marquee (re)started: zero
    /// through the pause, then moving left at a constant speed, wrapping back to
    /// zero at the end of each pass.
    func offset(after elapsed: TimeInterval) -> CGFloat {
        guard overflows, pointsPerSecond > 0, elapsed > 0 else {
            return 0
        }
        let phase = elapsed.truncatingRemainder(dividingBy: cycleDuration)
        guard phase > pause else {
            return 0
        }
        return -CGFloat(phase - pause) * pointsPerSecond
    }
}

/// A single line of text that scrolls sideways when it is too wide for its frame,
/// so a long track title can be read in full. Text that fits is a plain one-line
/// `Text`, unchanged. The scroll rests at the start between passes and starts over
/// when the text changes. With Reduce Motion on it wraps onto more lines instead.
struct MarqueeText: View {
    let text: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var startDate = Date.now

    private let edgeFadeWidth: CGFloat = 12

    private var scroll: MarqueeScroll {
        MarqueeScroll(textWidth: textWidth, containerWidth: containerWidth)
    }

    var body: some View {
        if reduceMotion {
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            marquee
        }
    }

    private var marquee: some View {
        // A hidden one-line copy gives the view exactly the size a plain truncating
        // `Text` would get, so layouts around it don't move.
        Text(text)
            .lineLimit(1)
            .hidden()
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                containerWidth = width
            }
            .background(alignment: .leading) {
                Text(text)
                    .fixedSize()
                    .hidden()
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.width
                    } action: { width in
                        textWidth = width
                    }
            }
            .overlay(alignment: .leading) {
                visibleText
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
            .onChange(of: text) {
                startDate = .now
            }
    }

    @ViewBuilder private var visibleText: some View {
        let scroll = scroll
        if scroll.overflows {
            TimelineView(.animation) { context in
                let offset = scroll.offset(after: context.date.timeIntervalSince(startDate))
                HStack(spacing: scroll.gap) {
                    Text(text)
                    Text(text)
                }
                .fixedSize()
                .offset(x: offset)
                .frame(width: scroll.containerWidth, alignment: .leading)
                .clipped()
                .mask(edgeFade(fadesLeading: offset < 0))
            }
        } else {
            Text(text)
                .lineLimit(1)
        }
    }

    /// Softens the edges the text slides past. The leading edge only fades while
    /// moving, so the first letters read cleanly while the text rests.
    private func edgeFade(fadesLeading: Bool) -> some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [fadesLeading ? .clear : .black, .black],
                           startPoint: .leading,
                           endPoint: .trailing)
                .frame(width: edgeFadeWidth)
            Rectangle()
            LinearGradient(colors: [.black, .clear],
                           startPoint: .leading,
                           endPoint: .trailing)
                .frame(width: edgeFadeWidth)
        }
    }
}
