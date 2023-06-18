//
//  DetailedHeaterView.swift
//  IntelliNest
//
//  Created by Tobias on 2022-06-22.
//

import SwiftUI

struct DetailedHeaterView: View {
    @Binding var heater: HeaterEntity
    let fanModeSelectedCallback: HeaterFanModeClosure
    let horizontalModeSelectedCallback: HeaterHorizontalModeClosure
    let verticalModeSelectedCallback: HeaterVerticalModeClosure

    var body: some View {
        VStack {
            Text("\(heater.heaterName)")
                .font(.title)
                .padding([.top, .bottom])
                .foregroundColor(.white)

            Text("Fläkt")
                .font(.title2)
                .foregroundColor(.white)
            FanModeView(heater: heater,
                        mode: heater.fanMode,
                        fanModeSelectedCallback: fanModeSelectedCallback)
                .padding(.bottom)

            Text("Horisontellt läge")
                .font(.title2)
                .foregroundColor(.white)
            HorizontalModeView(heater: heater,
                               mode: heater.vaneHorizontal,
                               leftVaneTitle: heater.leftVaneTitle,
                               rightVaneTitle: heater.rightVaneTitle,
                               horizontalModeSelectedCallback: horizontalModeSelectedCallback)
                .padding(.bottom)

            Text("Vertikalt läge")
                .font(.title2)
                .foregroundColor(.white)
            HeaterVerticalPositionView(heater: heater,
                                       mode: heater.vaneVertical,
                                       verticalModeSelectedCallback: verticalModeSelectedCallback)
            Spacer()
        }
        .padding()
        .background(bodyColor)
    }
}

struct DetailedHeaterView_Previews: PreviewProvider {
    static var previews: some View {
        let heater = HeaterEntity(entityId: EntityId.heaterCorridor, state: "22")
        DetailedHeaterView(heater: .constant(heater),
                           fanModeSelectedCallback: { _, _ in },
                           horizontalModeSelectedCallback: { _, _ in },
                           verticalModeSelectedCallback: { _, _ in })
    }
}
