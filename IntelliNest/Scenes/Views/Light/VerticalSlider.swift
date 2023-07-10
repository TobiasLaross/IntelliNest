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
    let onSliderReleaseAction: AsyncSlideableClosure
    let onTapAction: AsyncSlideableClosure

    @State private var startingValue = 0
    @State private var isSliding = false

    func swipeDragGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isSliding {
                    isSliding = true
                    let touchPosition = value.startLocation.y
                    let sliderHeight = geometry.size.height
                    startingValue = Int((1 - touchPosition / sliderHeight) * CGFloat(maxValue))
                }
                let delta = startingValue - Int((value.location.y - value.startLocation.y) * dragCoefficient)
                onSliderChangeAction(slideable, min(max(0, delta), maxValue))
            }
            .onEnded { _ in
                Task { @MainActor in
                    await onSliderReleaseAction(slideable)
                    isSliding = false
                }
            }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                darkGrayColor
                    .frame(width: geometry.size.width, height: geometry.size.height)
                lightGrayColor
                    .frame(width: geometry.size.width,
                           height: geometry.size.height * max(CGFloat(slideable.value(isSliding: isSliding)),
                                                              0) / CGFloat(maxValue))
                    .cornerRadius(0)
            }
            .foregroundColor(Color.gray)
            .onTapGesture {
                Task { @MainActor in
                    await onTapAction(slideable)
                }
            }
            .cornerRadius(geometry.size.width / 3.3)
            .gesture(
                AnyGesture(swipeDragGesture(geometry: geometry).map { _ in () })
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
