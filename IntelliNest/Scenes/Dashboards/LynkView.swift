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
                    ServiceButtonView(buttonTitle: viewModel.climateTitle,
                                      isActive: viewModel.isAirConditionActive,
                                      activeColor: viewModel.climateIconColor,
                                      buttonSize: 90,
                                      icon: .init(systemImageName: .thermometer),
                                      iconWidth: 25,
                                      iconHeight: 35,
                                      isLoading: false,
                                      action: viewModel.toggleClimate)
                        .padding(.trailing, 32)

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
