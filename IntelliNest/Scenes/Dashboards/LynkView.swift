//
//  LynkView.swift
//  IntelliNest
//
//  Created by Tobias on 2022-02-03.
//

import SwiftUI

struct LynkView: View {
    @ObservedObject var viewModel: LynkViewModel
    @State var isEngineAlertVisible = false

    var body: some View {
        VStack {
            Spacer()
                .frame(height: 50)
            Text("Bilen är **\(viewModel.lynkDoorLock.stateToString())** på \(viewModel.address.state)")
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding()
            Text("Batteri: \(viewModel.battery.inputNumber.toPercent) - \(viewModel.batteryDistance.state)km")
            Text("Bensin: \(viewModel.fuel.state)l - \(viewModel.fuelDistance.state)km")

            Spacer()
                .frame(height: 150)
            HStack {
                VStack(alignment: .trailing) {
                    Text("Bilen \(String(format: "%.1f", viewModel.interiorTemperature.state.roundedWithOneDecimal))°C")
                    Text("Ute \(String(format: "%.1f", viewModel.exteriorTemperature.state.roundedWithOneDecimal))°C")
                }
                .padding(.trailing, 16)
                ServiceButtonView(buttonTitle: viewModel.climateTitle,
                                  isActive: viewModel.isAirConditionActive,
                                  activeColor: viewModel.climateIconColor,
                                  buttonSize: 90,
                                  icon: .init(systemImageName: .thermometer),
                                  iconWidth: 25,
                                  iconHeight: 35,
                                  isLoading: viewModel.isAirConditionLoading,
                                  action: viewModel.toggleClimate)
                Spacer()
                ServiceButtonView(buttonTitle: viewModel.engineTitle,
                                  isActive: viewModel.isEngineRunning.isActive,
                                  buttonSize: 75,
                                  icon: .init(systemImageName: .engineFilled),
                                  iconWidth: 35,
                                  iconHeight: 25,
                                  isLoading: viewModel.isEngineLoading,
                                  action: {
                                      if viewModel.isEngineRunning.isActive {
                                          viewModel.stopEngine()
                                      } else {
                                          isEngineAlertVisible = true
                                      }
                                  })
                                  .alert(isPresented: $isEngineAlertVisible) {
                                      Alert(title: Text("Start motorn"),
                                            message: Text(""),
                                            primaryButton: .destructive(Text("Ja")) {
                                                viewModel.startEngine()
                                            },
                                            secondaryButton: .cancel())
                                  }
            }
            .padding([.horizontal, .top], 32)

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

struct Eniro_Previews: PreviewProvider {
    static var previews: some View {
        LynkView(viewModel: LynkViewModel(restAPIService: PreviewProviderUtil.restAPIService,
                                          showClimateSchedulingAction: {}))
            .backgroundModifier()
    }
}
