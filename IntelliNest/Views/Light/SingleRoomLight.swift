//
//  SingleRoomLight.swift
//  IntelliNest
//
//  Created by Tobias on 2022-07-13.
//

import SwiftUI

struct SingleRoomLight: View {
    let roomName: String
    @Binding var light: LightEntity
    let onTapAction: AsyncSlideableClosure
    let onSliderChangeAction: SlideableIntClosure
    let onSliderReleaseAction: AsyncSlideableClosure
    let roomTitleSize: CGFloat
    let sliderWidth: CGFloat
    let sliderHeight: CGFloat

    var body: some View {
        VStack {
            VStack {
                Text(roomName)
                    .font(.system(size: roomTitleSize))
                    .foregroundColor(.white)
                BulbButton(light: light, onTapAction: onTapAction)
            }

            HStack {
                VerticalSlider(slideable: light,
                               onSliderChangeAction: onSliderChangeAction,
                               onSliderReleaseAction: onSliderReleaseAction,
                               onTapAction: onTapAction)
                    .frame(width: sliderWidth, height: sliderHeight, alignment: .center)
            }
        }
    }
}
