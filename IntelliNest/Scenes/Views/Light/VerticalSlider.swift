//
//  VerticalSlider.swift
//  IntelliNest
//
//  Created by Tobias on 2023-06-02.

import SwiftUI

struct VerticalSlider<T: Slideable>: View {
    private let maxValue: Int = 254
    private let dragCoefficient: CGFloat = 1.8
    private let darkGrayColorIntensity = 37.0
    private let lightGrayColorIntensity = 201.0
    private var darkGrayColor: Color {
        Color(red: darkGrayColorIntensity / 255,
              green: darkGrayColorIntensity / 255,
              blue: darkGrayColorIntensity / 255)
    }

    private var lightGrayColor: Color {
        Color(red: lightGrayColorIntensity / 255,
              green: lightGrayColorIntensity / 255,
              blue: lightGrayColorIntensity / 255)
    }

    var slideable: T
    let onSliderChangeAction: SlideableIntClosure
    let onSliderReleaseAction: SlideableClosure
    let onTapAction: SlideableClosure

    @State private var startingValue = 0

    func swipeGesture(geometry: GeometryProxy) -> some Gesture {
        let longPress = longPressGesture()
        let swipe = swipeDragGesture()
        let endGesture = endDragGesture()

        return longPress.sequenced(before: swipe).sequenced(before: endGesture)
    }

    func longPressGesture() -> _EndedGesture<LongPressGesture> {
        LongPressGesture(minimumDuration: 0)
            .onEnded { _ in
                startingValue = slideable.value
            }
    }

    func swipeDragGesture() -> _ChangedGesture<DragGesture> {
        DragGesture(minimumDistance: 0)
            .onChanged {
                let delta = startingValue - Int(($0.location.y - $0.startLocation.y) * dragCoefficient)
                onSliderChangeAction(slideable, min(max(0, delta), maxValue))
            }
    }

    func endDragGesture() -> _EndedGesture<DragGesture> {
        DragGesture(minimumDistance: 0)
            .onEnded { _ in
                onSliderReleaseAction(slideable)
            }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                darkGrayColor
                    .frame(width: geometry.size.width, height: geometry.size.height)
                lightGrayColor
                    .frame(width: geometry.size.width,
                           height: geometry.size.height * max(CGFloat(slideable.value), 0) / CGFloat(maxValue))
                    .cornerRadius(0)
            }
            .foregroundColor(Color.gray)
            .onTapGesture {
                onTapAction(slideable)
            }
            .cornerRadius(geometry.size.width / 3.3)
            .gesture(
                AnyGesture(swipeGesture(geometry: geometry).map { _ in () })
            )
        }
    }
}

struct VerticalSlider_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            VerticalSlider(slideable: LightEntity(entityId: .lightsInPlayroom),
                           onSliderChangeAction: { _, _ in },
                           onSliderReleaseAction: { _ in },
                           onTapAction: { _ in })
                .frame(width: 145, height: 390)
        }
    }
}
