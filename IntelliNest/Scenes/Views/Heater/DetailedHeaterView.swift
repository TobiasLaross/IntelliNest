//
//  DetailedHeaterView.swift
//  IntelliNest
//
//  Created by Tobias on 2022-06-22.
//

import SwiftUI

struct DetailedHeaterView: View {
    var heater: HeaterEntity
    var fanMode: HeaterFanMode
    var horizontalMode: HeaterHorizontalMode
    var verticalMode: HeaterVerticalMode
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
            FanModeView(fanMode: fanMode,
                        fanModeSelectedCallback: { fanMode in
                            fanModeSelectedCallback(heater, fanMode)
                        })
                        .padding(.bottom)

            Text("Horisontellt läge")
                .font(.title2)
                .foregroundColor(.white)
            HorizontalModeView(mode: horizontalMode,
                               leftVaneTitle: heater.leftVaneTitle,
                               rightVaneTitle: heater.rightVaneTitle,
                               horizontalModeSelectedCallback: { horizontalMode in
                                   horizontalModeSelectedCallback(heater, horizontalMode)
                               })
                               .padding(.bottom)

            Text("Vertikalt läge")
                .font(.title2)
                .foregroundColor(.white)
            VerticalPositionView(mode: verticalMode,
                                 verticalModeSelectedCallback: { verticalMode in
                                     verticalModeSelectedCallback(heater, verticalMode)
                                 })
            Spacer()
        }
        .padding()
        .background(bodyColor)
    }
}

struct DetailedHeaterView_Previews: PreviewProvider {
    static var previews: some View {
        let heater = HeaterEntity(entityId: EntityId.heaterCorridor, state: "22")
        DetailedHeaterView(heater: heater,
                           fanMode: .auto,
                           horizontalMode: .auto,
                           verticalMode: .auto,
                           fanModeSelectedCallback: { _, _ in },
                           horizontalModeSelectedCallback: { _, _ in },
                           verticalModeSelectedCallback: { _, _ in })
    }
}
