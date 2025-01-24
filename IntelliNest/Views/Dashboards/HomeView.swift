//
//  HomeView.swift
//  IntelliNest
//
//  Created by Tobias on 2022-02-01.
//

import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        ZStack {
            VStack {
                HouseInfoView(viewModel: viewModel)
                    .padding(.vertical, 50)
                NavigationButtonsView(viewModel: viewModel)
                    .padding(.bottom, 40)
                ServiceButtonsView(viewModel: viewModel)
                Spacer(minLength: 40)
            }

            if viewModel.shouldShowCoffeeMachineScheduling {
                CoffeeMachineSchedulingView(isVisible: $viewModel.shouldShowCoffeeMachineScheduling,
                                            title: viewModel.coffeeMachine.title,
                                            coffeeMachineStartTime: $viewModel.coffeeMachineStartTime,
                                            coffeeMachineStartTimeEnabled: viewModel.coffeeMachineStartTimeEnabled,
                                            setCoffeeMachineStartTime: viewModel.updateDateTimeEntity,
                                            toggleStartTimeEnabledAction: viewModel.toggleCoffeeMachineStarTimeEnabled)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ToolBarConnectionStateView(urlCreator: viewModel.urlCreator)
            }
            ToolbarItem(placement: .principal) {
                ToolbarTitleView(destination: .home)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                ToolbarReloadButtonView(destination: .home, reloadAction: viewModel.toolbarReloadAction)
            }
        }
        .onAppear {
            viewModel.checkLocationAccess()
        }
    }
}

private struct HouseInfoView: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        HStack(alignment: .bottom) {
            VStack {
                if viewModel.noLocationAccess {
                    Button {
                        viewModel.openLocationSettings()
                    } label: {
                        Text("Go to settings and add location access")
                            .font(.buttonFontMedium)
                            .foregroundStyle(.red)
                            .padding()
                    }
                }
                Text(viewModel.dynamicInfoText)
                    .font(.buttonFontMedium)
                    .padding(.leading, 20)
                    .lineLimit(6)
            }
            Spacer()
            VStack {
                Text("""
                Elnät: ***\(viewModel.pulsePower.state.toKW)***
                Pris: ***\(viewModel.tibberPrice.state.toOre)***
                Producerat idag: ***\(viewModel.solarProducdtionToday.state.toKWh)***
                Köpt idag: ***\(viewModel.pulseConsumptionToday.state.toKWh)***
                """)
                .font(.buttonFontMedium)
            }
            .padding(.trailing, 20)
        }
        .foregroundStyle(.white)
    }
}

private struct NavigationButtonsView: View {
    @ObservedObject var viewModel: HomeViewModel

    let buttonSize = 90.0
    var body: some View {
        VStack {
            HStack(spacing: 15) {
                NavigationButtonView(buttonTitle: "", image: Image(imageName: .aircondition), action: viewModel.showHeatersAction)
                NavigationButtonView(buttonTitle: "Lynk", image: Image(systemName: "car.fill"), action: viewModel.showLynkAction)
                NavigationButtonView(
                    buttonTitle: "Leaf",
                    image: Image(systemName: "car.2.fill"),
                    buttonImageWidth: 40,
                    action: viewModel.showLeafAction
                )
            }
            HStack(spacing: 15) {
                NavigationButtonView(image: Image(imageName: .powerGrid),
                                     buttonImageWidth: 45,
                                     buttonImageHeight: 50,
                                     action: viewModel.showPowerGridAction)

                NavigationButtonView(image: Image(systemName: "lightbulb.fill"),
                                     buttonImageWidth: 30,
                                     buttonImageHeight: 50,
                                     isActive: viewModel.allLights.isActive,
                                     action: viewModel.showLightsAction)
                    .contextMenu {
                        Button {
                            viewModel.turnOffAllLights()
                        } label: {
                            Text("Släck alla lampor")
                        }
                    }
                NavigationButtonView(buttonTitle: "",
                                     image: Image("roborocks7"),
                                     buttonImageWidth: 50,
                                     buttonImageHeight: 50,
                                     action: viewModel.showRoborockAction)
            }
        }
    }
}

private struct ServiceButtonsView: View {
    @ObservedObject var viewModel: HomeViewModel
    @State private var isShowingAlert = false
    let buttonSize = 90.0

    var body: some View {
        VStack {
            HStack {
                ServiceButtonView(buttonTitle: "\(viewModel.frontDoor.actionText) framdörren",
                                  customFont: .buttonFontSmall,
                                  isActive: viewModel.frontDoor.isActive,
                                  buttonSize: buttonSize,
                                  icon: viewModel.frontDoor.image,
                                  iconWidth: viewModel.frontDoor.isActive ? 30 : 20,
                                  iconHeight: 30,
                                  isLoading: viewModel.frontDoor.isLoading,
                                  action: viewModel.toggleStateForFrontDoor)
                    .disabled(viewModel.frontDoor.isLoading)
                ServiceButtonView(buttonTitle: "\(viewModel.sideDoor.actionText) sidodörren",
                                  customFont: .buttonFontSmall,
                                  isActive: viewModel.sideDoor.isActive,
                                  buttonSize: buttonSize,
                                  icon: viewModel.sideDoor.image,
                                  iconWidth: viewModel.sideDoor.isActive ? 30 : 20,
                                  iconHeight: 30,
                                  isLoading: viewModel.sideDoor.isLoading,
                                  action: viewModel.toggleStateForSideDoor)
                    .disabled(viewModel.sideDoor.isLoading)
                ServiceButtonView(buttonTitle: "\(viewModel.storageLock.actionText) förrådet",
                                  customFont: .buttonFontSmall,
                                  isActive: viewModel.storageLock.isActive,
                                  buttonSize: buttonSize,
                                  icon: viewModel.storageLock.image,
                                  iconWidth: viewModel.storageLock.isActive ? 30 : 20,
                                  iconHeight: 30,
                                  isLoading: viewModel.storageLock.isLoading,
                                  action: viewModel.toggleStateForStorageLock)
                    .disabled(viewModel.storageLock.isLoading)
                    .contextMenu {
                        Button(action: viewModel.lockStorage, label: {
                            Text("Lås")
                        })
                        Button(action: viewModel.unlockStorage, label: {
                            Text("Lås upp")
                        })
                    }
            }

            HStack {
                ServiceButtonView(buttonTitle: viewModel.coffeeMachine.title,
                                  customFont: .buttonFontSmall,
                                  isActive: viewModel.coffeeMachine.isActive,
                                  activeColor: viewModel.coffeeMachine.activeColor,
                                  buttonSize: buttonSize,
                                  icon: viewModel.coffeeMachine.image,
                                  iconWidth: 25,
                                  iconHeight: 35,
                                  indicatorIcon: viewModel.coffeeMachineStartTimeEnabled.timerEnabledIcon,
                                  action: viewModel.toggleCoffeeMachine)
                    .contextMenu {
                        Button(action: viewModel.showCoffeeMachineScheduling,
                               label: {
                                   Text("Schemalägg nästa start")
                               })
                    }
                if UserManager.currentUser == .tobias {
                    ServiceButtonView(buttonTitle: "Hitta Sarah's iPhone?",
                                      customFont: .buttonFontSmall,
                                      isActive: viewModel.sarahsIphone.isActive,
                                      buttonSize: buttonSize,
                                      icon: viewModel.sarahIphoneimage,
                                      iconWidth: viewModel.sarahsIphone.isActive ? 40 : 20,
                                      iconHeight: 30,
                                      action: {
                                          isShowingAlert = true
                                      })
                                      .alert(isPresented: $isShowingAlert) {
                                          Alert(
                                              title: Text("Hitta Sarah's iPhone?"),
                                              message: Text(""),
                                              primaryButton: .destructive(
                                                  Text(viewModel.sarahsIphone.state == "on" ? "Hittad" : "Hitta")) {
                                                      viewModel.toggleStateForSarahsIphone()
                                                  },
                                              secondaryButton: .cancel()
                                          )
                                      }
                } else if UserManager.currentUser == .sarah && !viewModel.isSarahsPillsTaken {
                    ServiceButtonView(buttonTitle: "Tagit medicin",
                                      customFont: .buttonFontSmall,
                                      buttonSize: buttonSize,
                                      icon: .init(systemImageName: .pills),
                                      iconWidth: 30,
                                      iconHeight: 30,
                                      action: {
                                          viewModel.sarahDidTakePills()
                                      })
                }
            }
        }
    }
}

struct Home_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = HomeViewModel(restAPIService: PreviewProviderUtil.restAPIService,
                                      yaleApiService: YaleApiService(hassAPIService: PreviewProviderUtil.restAPIService),
                                      urlCreator: PreviewProviderUtil.urlCreator,
                                      showHeatersAction: {},
                                      showLynkAction: {},
                                      showLeafAction: {},
                                      showRoborockAction: {},
                                      showPowerGridAction: {},
                                      showLightsAction: {},
                                      repeatReloadAction: { _ in },
                                      toolbarReloadAction: {})

        HomeView(viewModel: viewModel)
            .backgroundModifier()
    }
}
