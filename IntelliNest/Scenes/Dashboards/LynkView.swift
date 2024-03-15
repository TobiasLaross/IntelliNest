//
//  LynkView.swift
//  IntelliNest
//
//  Created by Tobias on 2022-02-03.
//

import SwiftUI

struct LynkView: View {
    @ObservedObject var viewModel: LynkViewModel
    @State private var isShowingAlert = false

    var body: some View {
        ZStack {
            VStack {
                HStack(spacing: 16) {
                    ServiceButtonView(buttonTitle: viewModel.climateTitle,
                                      isActive: viewModel.isAirConditionActive,
                                      activeColor: viewModel.climateIconColor,
                                      buttonSize: 90,
                                      icon: .init(systemImageName: .thermometer),
                                      iconWidth: 25,
                                      iconHeight: 35,
                                      isLoading: viewModel.isAirConditionLoading,
                                      action: viewModel.toggleClimate)

                    ServiceButtonView(buttonTitle: viewModel.doorLockTitle,
                                      isActive: viewModel.isLynkUnlocked,
                                      buttonSize: 90,
                                      icon: viewModel.doorLockIcon,
                                      iconWidth: viewModel.isLynkUnlocked ? 30 : 20,
                                      iconHeight: 30,
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
                                      buttonSize: 90,
                                      icon: viewModel.flashLightIcon,
                                      iconWidth: 30,
                                      iconHeight: 30,
                                      action: {
                                          if !viewModel.isLynkFlashing {
                                              isShowingAlert = true
                                          } else {
                                              viewModel.stopFlashLights()
                                          }
                                      })
                                      .alert(isPresented: $isShowingAlert) {
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
                .padding(.top, 72)
                .padding(.bottom, 32)

                Text("Bilen är **\(viewModel.lynkDoorLock.stateToString())**")
                    .foregroundColor(.white)

                Spacer()

                ServiceButtonView(buttonTitle: viewModel.chargingTitle,
                                  isActive: viewModel.isEaseeCharging,
                                  buttonSize: 90,
                                  icon: viewModel.chargingIcon,
                                  imageSize: 40,
                                  action: viewModel.toggleEaseeCharging)
                    .padding(.bottom, 64)
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
