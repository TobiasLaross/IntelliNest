//
//  VerticalSlider.swift
//  IntelliNest
//
//  Created by Tobias on 2023-06-02.

import SwiftUI

struct VerticalSlider: View {
    private let maxBrightness: Int = 254
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

    @Binding var light: LightEntity
    let onSliderRelease: (LightEntity) -> Void
    let onTap: (LightEntity) -> Void

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
                self.startingValue = self.light.brightness
            }
    }

    func swipeDragGesture() -> _ChangedGesture<DragGesture> {
        DragGesture(minimumDistance: 0)
            .onChanged {
                let delta = self.startingValue - Int(($0.location.y - $0.startLocation.y) * dragCoefficient)
                self.light.brightness = min(max(0, delta), maxBrightness)
            }
    }

    func endDragGesture() -> _EndedGesture<DragGesture> {
        DragGesture(minimumDistance: 0)
            .onEnded { _ in
                self.onSliderRelease(self.light)
            }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                darkGrayColor
                    .frame(width: geometry.size.width, height: geometry.size.height)
                lightGrayColor
                    .frame(width: geometry.size.width,
                           height: geometry.size.height * max(CGFloat(light.brightness), 0) / CGFloat(maxBrightness))
                    .cornerRadius(0)
            }
            .foregroundColor(Color.gray)
            .onTapGesture {
                onTap(light)
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
            VerticalSlider(light: .constant(.init(entityId: .lamporILekrummet)),
                           onSliderRelease: { _ in },
                           onTap: { _ in })
                .frame(width: 145, height: 390)
        }
    }
}
