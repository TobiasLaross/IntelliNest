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
        ZStack {
            VStack {
                Text("Bilen är **\(viewModel.lynkDoorLock.stateToString())** på \(viewModel.address.state)")
                    .foregroundColor(.white)
                    .padding([.top, .horizontal])
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(viewModel.addressUpdatedAtDescription)
                    .font(.buttonFontExtraSmall)
                    .foregroundColor(.white)
                    .padding(.bottom)
                HStack {
                    Spacer()
                    VStack {
                        BatteryView(level: Int(viewModel.battery.inputNumber.rounded()),
                                    isCharging: viewModel.isCharging,
                                    degreeRotation: 90,
                                    width: 50,
                                    height: 90)
                        Text("\(viewModel.batteryDistance.state)km")
                            .font(.buttonFontSmall)
                            .foregroundColor(.white)
                            .padding(.top, -32)
                        if viewModel.isCharging {
                            Text(viewModel.chargerStateDescription)
                                .font(.buttonFontExtraSmall)
                                .foregroundColor(.white)
                                .padding(.top, -25)
                        }
                        Text(viewModel.batteryUpdatedAtDescription)
                            .font(.buttonFontExtraSmall)
                            .foregroundColor(.white)
                            .padding(.top, -20)
                    }
                    Spacer()
                        .frame(width: 90)
                    VStack {
                        FuelView(level: Int(viewModel.fuel.inputNumber.rounded()),
                                 degreeRotation: 90,
                                 width: 50,
                                 height: 90)
                        Text("\(viewModel.fuelDistance.state)km")
                            .font(.buttonFontSmall)
                            .foregroundColor(.white)
                            .padding(.top, -27)
                        Text(viewModel.fuelUpdatedAtDescription)
                            .font(.buttonFontExtraSmall)
                            .foregroundColor(.white)
                            .padding(.top, -23)
                    }
                    Spacer()
                }

                Spacer()
                    .frame(height: 20)
                HStack {
                    VStack(alignment: .trailing) {
                        Text("Bilen \(String(format: "%.1f", viewModel.interiorTemperature.state.roundedWithOneDecimal))°C")
                            .foregroundColor(.white)
                        Text("Ute \(String(format: "%.1f", viewModel.exteriorTemperature.state.roundedWithOneDecimal))°C")
                            .foregroundColor(.white)
                        Text(viewModel.climateUpdatedAtDescription)
                            .font(.buttonFontExtraSmall)
                            .foregroundColor(.white)
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
                                          Alert(title: Text("Starta motorn?"),
                                                message: Text(""),
                                                primaryButton: .destructive(Text("Ja")) {
                                                    viewModel.startEngine()
                                                },
                                                secondaryButton: .cancel())
                                      }
                }
                .padding([.horizontal, .top], 32)

                Spacer()
                    .frame(height: 50)

                LynkMiscView(viewModel: viewModel)
                Spacer()

                Divider()
                    .padding(.vertical)
                Text("Senast uppdaterad: \(viewModel.lastUpdated)")
                    .font(.buttonFontMedium)
                    .italic()
                    .foregroundColor(.white)
                    .padding(.bottom)
            }
            if viewModel.isShowingHeaterOptions {
                LynkHeaterOptionsView(viewModel: viewModel)
            }
        }
    }
}

struct Lynk_Previews: PreviewProvider {
    static var previews: some View {
        LynkView(viewModel: PreviewProviderUtil.lynkViewModel)
            .backgroundModifier()
    }
}
