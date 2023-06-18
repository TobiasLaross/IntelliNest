//
//  EniroChargingLimitView.swift
//  IntelliNest
//
//  Created by Tobias on 2023-02-19.
//

import SwiftUI

struct EniroChargingLimitView: View {
    @ObservedObject var viewModel: EniroViewModel
    let iconWidth = 35.0
    let iconHeight = 35.0

    var body: some View {
        HStack {
            HStack {
                DashboardButtonView(text: "\(viewModel.eniroChargingACLimit.state)%",
                                    icon: Image(imageName: .evPlugType2),
                                    iconWidth: iconWidth,
                                    iconHeight: iconHeight,
                                    isLoading: viewModel.eniroChargingACLimit.isLoading,
                                    isCircle: true,
                                    action: viewModel.showACLimitPicker)
            }

            HStack {
                DashboardButtonView(text: "\(viewModel.eniroChargingDCLimit.state)%",
                                    icon: Image(imageName: .evPlugCCS2),
                                    iconWidth: iconWidth,
                                    iconHeight: iconHeight,
                                    isLoading: viewModel.eniroChargingDCLimit.isLoading,
                                    isCircle: true,
                                    action: viewModel.showDCLimitPicker)
            }
        }
    }
}

struct EniroChargingLimitView_Previews: PreviewProvider {
    static var previews: some View {
        EniroChargingLimitView(viewModel: .init(apiService: HassApiService(urlCreator: URLCreator()), appearedAction: { _ in }))
    }
}
