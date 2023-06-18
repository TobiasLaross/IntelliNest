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
    let reloadLights: MainActorAsyncVoidClosure
    let onTap: LightClosure
    let onSliderRelease: LightClosure
    let sliderWidth: CGFloat
    let sliderHeight: CGFloat
    let bulbTitleSize: CGFloat
    let roomTitleSize: CGFloat

    var body: some View {
        VStack {
            VStack {
                Text(roomName)
                    .font(.system(size: roomTitleSize))
                BulbButton(light: $lightGroup,
                           reloadLights: reloadLights,
                           onTap: onTap)
            }

            HStack {
                VStack {
                    VerticalSlider(light: $light1,
                                   onSliderRelease: onSliderRelease,
                                   onTap: onTap)
                        .frame(width: sliderWidth, height: sliderHeight, alignment: .center)
                    Text(light1Name)
                        .font(.system(size: bulbTitleSize))
                }

                VStack {
                    VerticalSlider(light: $light2,
                                   onSliderRelease: onSliderRelease,
                                   onTap: onTap)
                        .frame(width: sliderWidth, height: sliderHeight, alignment: .center)
                    Text(light2Name)
                        .font(.system(size: bulbTitleSize))
                }
            }
        }
    }
}
