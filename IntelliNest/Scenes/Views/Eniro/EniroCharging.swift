//
//  EniroCharging.swift
//  IntelliNest
//
//  Created by Tobias on 2022-09-24.
//

import SwiftUI

struct Charging: View {
    @ObservedObject var viewModel: EniroViewModel

    var body: some View {
        let startChargeButton = ServiceButton(buttonTitle: "Starta laddning", imageName: "bolt.car")
        let stopChargeButton = ServiceButton(buttonTitle: "Avbryt laddning", imageName: "xmark.circle")

        HStack {
            Button {
                viewModel.startCharging()
            } label: {
                HassCircleButtonLabelOld(dashboardButton: AnyView(startChargeButton))
            }

            Button {
                viewModel.stopCharging()
            } label: {
                HassCircleButtonLabelOld(dashboardButton: AnyView(stopChargeButton))
            }
        }
    }
}
