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
    let reloadLights: MainActorAsyncVoidClosure
    let onTap: LightClosure
    let onSliderRelease: LightClosure
    let roomTitleSize: CGFloat
    let sliderWidth: CGFloat
    let sliderHeight: CGFloat

    var body: some View {
        VStack {
            VStack {
                Text(roomName)
                    .font(.system(size: roomTitleSize))
                BulbButton(light: $light, reloadLights: reloadLights, onTap: onTap)
            }

            HStack {
                VerticalSlider(light: $light, onSliderRelease: onSliderRelease, onTap: onTap)
                    .frame(width: sliderWidth, height: sliderHeight, alignment: .center)
            }
        }
    }
}
