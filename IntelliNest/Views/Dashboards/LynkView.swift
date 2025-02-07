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
    @State private var isFlashLightAlertVisible = false

    var body: some View {
        ZStack {
            VStack {
                INText(
                    "Lynken är **\(viewModel.lynkDoorLock.stateToString())** på \(viewModel.address.state)",
                    font: .title3,
                    lineLimit: 1,
                    minimumScaleFactor: 0.5
                )
                .padding(.horizontal)
                INText(viewModel.lynkLastUpdated, font: .buttonFontExtraSmall)
                    .padding(.bottom)
                HStack {
                    Spacer()
                    VStack {
                        BatteryView(level: Int(viewModel.lynkBattery.inputNumber.rounded()),
                                    isCharging: viewModel.isCharging,
                                    degreeRotation: 90,
                                    width: 50,
                                    height: 90)
                        INText("\(viewModel.lynkBatteryDistance.state)km", font: .buttonFontSmall)
                            .padding(.top, -32)
                        if viewModel.isCharging {
                            Text(viewModel.chargerStateDescription)
                                .font(.buttonFontExtraSmall)
                                .foregroundColor(.white)
                                .padding(.top, -25)
                        }
                    }
                    Spacer()
                        .frame(width: 90)
                    VStack {
                        FuelView(level: Int(viewModel.fuel.inputNumber.rounded()),
                                 degreeRotation: 90,
                                 width: 50,
                                 height: 90)
                        INText("\(viewModel.fuelDistance.state)km", font: .buttonFontSmall)
                            .padding(.top, -27)
                    }
                    Spacer()
                }

                Spacer()
                    .frame(height: 20)
                VStack {
                    HStack {
                        ServiceButtonView(buttonTitle: viewModel.lynkClimateTitle,
                                          isActive: viewModel.isLynkAirConditionActive,
                                          buttonSize: viewModel.buttonSize,
                                          icon: .init(systemImageName: .thermometer),
                                          iconWidth: 25,
                                          iconHeight: 35,
                                          isLoading: viewModel.isLynkAirConditionLoading,
                                          action: viewModel.toggleLynkClimate)
                        ServiceButtonView(buttonTitle: viewModel.engineTitle,
                                          isActive: viewModel.isEngineRunning.isActive,
                                          buttonSize: viewModel.buttonSize,
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
                        ServiceButtonView(buttonTitle: viewModel.doorLockTitle,
                                          isActive: viewModel.isLynkUnlocked,
                                          buttonSize: viewModel.buttonSize,
                                          icon: viewModel.doorLockIcon,
                                          iconWidth: viewModel.isLynkUnlocked ? 30 : 20,
                                          iconHeight: 30,
                                          isLoading: viewModel.lynkDoorLock.isLoading,
                                          action: viewModel.toggleDoorLock)
                            .disabled(viewModel.lynkDoorLock.isLoading)
                            .contextMenu {
                                Button(action: viewModel.lockDoors, label: {
                                    Text("Lås")
                                })
                                Button(action: viewModel.unlockDoors, label: {
                                    Text("Lås upp")
                                })
                            }

                        ServiceButtonView(buttonTitle: viewModel.flashLightTitle,
                                          isActive: viewModel.isLynkFlashing,
                                          buttonSize: viewModel.buttonSize,
                                          icon: viewModel.flashLightIcon,
                                          iconWidth: 30,
                                          iconHeight: 30,
                                          action: {
                                              if !viewModel.isLynkFlashing {
                                                  isFlashLightAlertVisible = true
                                              } else {
                                                  viewModel.stopFlashLights()
                                              }
                                          })
                                          .alert(isPresented: $isFlashLightAlertVisible) {
                                              Alert(
                                                  title: Text("Starta lampor"),
                                                  message: Text(""),
                                                  primaryButton: .destructive(Text("Ja")) {
                                                      viewModel.startFlashLights()
                                                  },
                                                  secondaryButton: .cancel()
                                              )
                                          }
                                          .disabled(viewModel.lynkDoorLock.isLoading)
                                          .contextMenu {
                                              Button(action: viewModel.startFlashLights, label: {
                                                  Text("Starta lamporna")
                                              })
                                              Button(action: viewModel.stopFlashLights, label: {
                                                  Text("Stäng av lamporna")
                                              })
                                          }
                    }
                    HStack {
                        INText("Bilen \(String(format: "%.1f", viewModel.lynkInteriorTemperature.state.roundedWithOneDecimal))°C",
                               font: .footnote)
                            .padding(.trailing, 16)
                        INText("Ute \(String(format: "%.1f", viewModel.lynkExteriorTemperature.state.roundedWithOneDecimal))°C",
                               font: .footnote)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 16)

                Spacer()

                Divider()
                    .padding(.vertical)
                LeafView(viewModel: viewModel)
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
