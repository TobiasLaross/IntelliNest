//
//  LynkView.swift
//  IntelliNest
//
//  Created by Tobias on 2022-02-03.
//

import SwiftUI

struct LynkView: View {
    @ObservedObject var viewModel: LynkViewModel

    var body: some View {
        ZStack {
            VStack {
                HStack {
                    VStack {
                        Text("Bilen \(String(format: "%.1f", viewModel.interiorTemperature.state.roundedWithOneDecimal))°C")
                        Text("Ute \(String(format: "%.1f", viewModel.exteriorTemperature.state.roundedWithOneDecimal))°C")
                    }
                    ServiceButtonView(buttonTitle: viewModel.climateTitle,
                                      isActive: viewModel.isAirConditionActive,
                                      activeColor: viewModel.climateIconColor,
                                      buttonSize: 90,
                                      icon: .init(systemImageName: .thermometer),
                                      iconWidth: 25,
                                      iconHeight: 35,
                                      isLoading: viewModel.isAirConditionLoading,
                                      action: viewModel.toggleClimate)
                }
                .padding(.top, 32)

                Spacer()
                    .frame(height: 50)
                Text("Bilen är **\(viewModel.lynkDoorLock.stateToString())** på \(viewModel.address.state)")
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding()

                Spacer()

                LynkMiscView(viewModel: viewModel)
                Spacer()

                Divider()
                    .padding(.top)
                Text("Senast uppdaterad: \(viewModel.lastUpdated)")
                    .font(Font.system(size: 12).italic())
                    .foregroundColor(.white)
                    .padding(.bottom)
            }
        }
    }
}

struct Eniro_Previews: PreviewProvider {
    static var previews: some View {
        LynkView(viewModel: LynkViewModel(restAPIService: PreviewProviderUtil.restAPIService,
                                          showClimateSchedulingAction: {}))
            .backgroundModifier()
    }
}
