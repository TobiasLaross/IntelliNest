//
//  EniroInfoView.swift
//  IntelliNest
//
//  Created by Tobias on 2022-09-19.
//

import SwiftUI

struct EniroInfoView: View {
    @ObservedObject var viewModel: EniroViewModel

    var body: some View {
        VStack {
            Text("Bilen är **\(viewModel.doorLock.stateToString())** på: \(viewModel.getAddress())")
                .foregroundColor(.white)
            Spacer()
                .frame(height: 20)
            HStack {
                BatteryView(level: Int(viewModel.batteryLevel.state) ?? 100,
                            isCharging: viewModel.isCharging.isActive, degreeRotation: 90)
                    .padding(.trailing, 30)

                CircleButtonView(buttonTitle: "Smart laddning",
                                 isActive: !viewModel.forceCharging.isActive,
                                 icon: .init(systemImageName: .powerplug),
                                 iconWidth: 25,
                                 iconHeight: 20,
                                 isLoading: false,
                                 action: viewModel.toggleForceCharging)
            }
        }
    }
}
