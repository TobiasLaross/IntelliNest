//
//  DualBulbRoomView.swift
//  IntelliNest
//
//  Created by Tobias on 2022-07-07.
//

import SwiftUI

struct DualBulbRoomView: View {
    let roomName: String
    @Binding var lightGroup: LightEntity
    @Binding var light1: LightEntity
    @Binding var light2: LightEntity
    let light1Name: String
    let light2Name: String
    let onTapAction: AsyncSlideableClosure
    let onSliderChangeAction: SlideableIntClosure
    let onSliderReleaseAction: AsyncSlideableClosure
    let sliderWidth: CGFloat
    let sliderHeight: CGFloat
    let bulbTitleSize: CGFloat
    let roomTitleSize: CGFloat

    var body: some View {
        VStack {
            VStack {
                Text(roomName)
                    .font(.system(size: roomTitleSize))
                BulbButton(light: lightGroup, onTapAction: onTapAction)
            }

            HStack {
                VStack {
                    VerticalSlider(slideable: light1,
                                   onSliderChangeAction: onSliderChangeAction,
                                   onSliderReleaseAction: onSliderReleaseAction,
                                   onTapAction: onTapAction)
                        .frame(width: sliderWidth, height: sliderHeight, alignment: .center)
                    Text(light1Name)
                        .font(.system(size: bulbTitleSize))
                }

                VStack {
                    VerticalSlider(slideable: light2,
                                   onSliderChangeAction: onSliderChangeAction,
                                   onSliderReleaseAction: onSliderReleaseAction,
                                   onTapAction: onTapAction)
                        .frame(width: sliderWidth, height: sliderHeight, alignment: .center)
                    Text(light2Name)
                        .font(.system(size: bulbTitleSize))
                }
            }
        }
    }
}
