//
//  VolumeSliderView.swift
//  IntelliNest
//
//  Created by Tobias on 2026-11-09.
//

import SwiftUI

/// Volume control styled like the light-brightness slider (`VerticalSlider`):
/// a custom fill bar that updates the label live while dragging and commits the
/// new volume to Home Assistant only on release (no request spam mid-drag).
/// Pass `axis: .vertical` to rotate it 90° into a tall brightness-style bar.
struct VolumeSliderView: View {
    let volume: Double
    var axis: Axis = .horizontal
    /// Called on a tap (not a drag) on the thumb. Nil leaves taps inert.
    var onThumbTap: MainActorVoidClosure?
    let onCommit: DoubleClosure

    @State private var dragValue: Double?

    private var displayed: Double {
        dragValue ?? volume
    }

    private var percent: Int {
        Int((displayed * 100).rounded())
    }

    private var slider: some View {
        FillSlider(fraction: displayed,
                   axis: axis,
                   onThumbTap: onThumbTap,
                   onChange: { dragValue = $0 },
                   onCommit: {
                       if let dragValue {
                           onCommit(dragValue)
                       }
                       dragValue = nil
                   })
                   .accessibilityElement()
                   .accessibilityLabel("Volym")
                   .accessibilityValue("\(percent) procent")
                   .accessibilityAdjustableAction { direction in
                       let step = 0.05
                       let next = min(max(displayed + (direction == .increment ? step : -step), 0), 1)
                       onCommit(next)
                   }
    }

    private var label: some View {
        Text("\(percent)%")
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.7))
            .accessibilityHidden(true)
    }

    private var speakerIcon: some View {
        Image(systemName: "speaker.fill")
            .foregroundStyle(.white.opacity(0.7))
    }

    var body: some View {
        switch axis {
        case .horizontal:
            HStack {
                speakerIcon
                slider.frame(height: 26)
                label.frame(width: 40, alignment: .trailing)
            }
        case .vertical:
            VStack(spacing: 6) {
                label
                slider.frame(width: 36, height: 140)
                speakerIcon
            }
        }
    }
}

/// A slim-track slider with a pill thumb, the shape iOS 26 system sliders and the
/// Sonos app use for volume. Only a drag that starts on the thumb changes the
/// value, and it moves by the finger's travel rather than jumping to the touch
/// point — so brushing the track while scrolling can't blast the speakers. The
/// change is reported live and committed on release. `axis` rotates it 90°:
/// `.horizontal` fills left-to-right, `.vertical` fills bottom-to-top.
private struct FillSlider: View {
    let fraction: Double
    var axis: Axis = .horizontal
    var onThumbTap: MainActorVoidClosure?
    let onChange: DoubleClosure
    let onCommit: MainActorVoidClosure

    /// The value when the thumb was grabbed; nil when no thumb drag is in progress.
    @State private var grabbedFraction: Double?
    /// Set when a drag started off the thumb, so the rest of that drag is ignored.
    @State private var isDragRejected = false

    private let trackColor = Color.white.opacity(0.18)
    private let fillColor = Color.white.opacity(0.85)
    private let trackThickness: CGFloat = 6
    /// Thumb size along and across the slider.
    private let thumbLength: CGFloat = 34
    private let thumbThickness: CGFloat = 22
    /// Half the minimum 44pt touch target, measured along the slider from the thumb centre.
    private let thumbHitRadius: CGFloat = 22

    private var isGrabbed: Bool {
        grabbedFraction != nil
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let isHorizontal = axis == .horizontal
            let length = isHorizontal ? width : height
            let travel = max(length - thumbLength, 1)
            let clamped = CGFloat(min(max(fraction, 0), 1))
            let thumbCenter = thumbLength / 2 + travel * clamped
            ZStack(alignment: isHorizontal ? .leading : .bottom) {
                ZStack(alignment: isHorizontal ? .leading : .bottom) {
                    Capsule().fill(trackColor)
                    Capsule().fill(fillColor)
                        .frame(width: isHorizontal ? thumbCenter : nil,
                               height: isHorizontal ? nil : thumbCenter)
                }
                .frame(width: isHorizontal ? nil : trackThickness,
                       height: isHorizontal ? trackThickness : nil)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isHorizontal ? .leading : .bottom)

                Capsule()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.3), radius: isGrabbed ? 6 : 3, y: 1)
                    .frame(width: isHorizontal ? thumbLength : thumbThickness,
                           height: isHorizontal ? thumbThickness : thumbLength)
                    .scaleEffect(isGrabbed ? 1.2 : 1)
                    .animation(.spring(duration: 0.2), value: isGrabbed)
                    .offset(x: isHorizontal ? thumbCenter - thumbLength / 2 : 0,
                            y: isHorizontal ? 0 : -(thumbCenter - thumbLength / 2))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isHorizontal ? .leading : .bottom)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        if grabbedFraction == nil, !isDragRejected {
                            let start = isHorizontal ? value.startLocation.x : height - value.startLocation.y
                            if abs(start - thumbCenter) <= thumbHitRadius {
                                grabbedFraction = Double(clamped)
                            } else {
                                isDragRejected = true
                            }
                        }
                        guard let grabbedFraction else { return }
                        let moved = isHorizontal ? value.translation.width : -value.translation.height
                        let next = grabbedFraction + Double(moved / travel)
                        onChange(min(max(next, 0), 1))
                    }
                    .onEnded { _ in
                        if grabbedFraction != nil {
                            onCommit()
                        }
                        grabbedFraction = nil
                        isDragRejected = false
                    }
            )
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        let tapped = isHorizontal ? value.location.x : height - value.location.y
                        if let onThumbTap, abs(tapped - thumbCenter) <= thumbHitRadius {
                            onThumbTap()
                        }
                    }
            )
        }
    }
}
