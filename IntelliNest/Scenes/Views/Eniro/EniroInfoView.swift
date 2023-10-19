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
        let forceChargingButton = SwitchButton(entity: $viewModel.forceCharging,
                                               buttonTitle: "Tvinga laddning",
                                               activeImageName: "powerplug",
                                               defaultImageName: "powerplug",
                                               buttonImageSize: 20)
        VStack {
            Text("Bilen är \(viewModel.doorLock.stateToString()) på: \(viewModel.getAddress())")
                .foregroundColor(.white)
            Spacer()
                .frame(height: 20)
            HStack {
                BatteryView(level: Int(viewModel.batteryLevel.state) ?? 100,
                            isCharging: viewModel.isCharging.isActive, degreeRotation: 90)
                    .padding(.trailing, 30)

                Button {
                    viewModel.toggleForceCharging()
                } label: {
                    HassCircleButtonLabelOld(dashboardButton: AnyView(forceChargingButton))
                }

                DashboardButtonView(text: "Elpris:\n\(viewModel.nordPool.price) öre",
                                    isActive: false,
                                    icon: nil,
                                    isLoading: false,
                                    isCircle: true,
                                    action: viewModel.showNordPoolPrices)
                    .padding(.horizontal)
            }
        }
    }
}
