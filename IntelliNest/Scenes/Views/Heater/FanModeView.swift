//
//  FanModeView.swift
//  IntelliNest
//
//  Created by Tobias on 2022-06-22.
//

import SwiftUI

struct FanModeView: View {
    var fanMode: HeaterFanMode
    var fanModeSelectedCallback: FanModeClosure

    var body: some View {
        HStack {
            FanModeButtonView(fanMode: .auto,
                              selectedFanMode: fanMode,
                              image: .init(imageName: .refresh),
                              fanModeSelectedCallback: fanModeSelectedCallback)
            FanModeButtonView(fanMode: .one, selectedFanMode: fanMode, fanModeSelectedCallback: fanModeSelectedCallback)
            FanModeButtonView(fanMode: .two, selectedFanMode: fanMode, fanModeSelectedCallback: fanModeSelectedCallback)
            FanModeButtonView(fanMode: .three, selectedFanMode: fanMode, fanModeSelectedCallback: fanModeSelectedCallback)
            FanModeButtonView(fanMode: .four, selectedFanMode: fanMode, fanModeSelectedCallback: fanModeSelectedCallback)
            FanModeButtonView(fanMode: .five, selectedFanMode: fanMode, fanModeSelectedCallback: fanModeSelectedCallback)
        }
    }
}

struct FanModeView_Previews: PreviewProvider {
    static var previews: some View {
        FanModeView(fanMode: .auto, fanModeSelectedCallback: { _ in })
    }
}
