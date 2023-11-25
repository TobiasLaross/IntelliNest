//
//  Home.swift
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
                HomeNavigationButtonsView(viewModel: viewModel)
                    .padding(.bottom, 20)
                HomeServiceButtonsView(viewModel: viewModel)
                Spacer(minLength: 40)
            }

            if viewModel.shouldShowCoffeeMachineScheduling {
                CoffeeMachineSchedulingView(isVisible: $viewModel.shouldShowCoffeeMachineScheduling,
                                            title: viewModel.coffeeMachine.title,
                                            coffeeMachineStartTime: $viewModel.coffeeMachineStartTime,
                                            coffeeMachineStartTimeEnabled: viewModel.coffeeMachineStartTimeEnabled,
                                            setCoffeeMachineStartTime: viewModel.updateDateTimeEntity,
                                            toggleStartTimeEnabledAction: viewModel.toggleCoffeeMachineStarTimeEnabled)
            } else if viewModel.shouldShowNordpoolPrices {
                NordPoolHistoryView(isVisible: $viewModel.shouldShowNordpoolPrices,
                                    nordPool: viewModel.nordPool)
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
            viewModel.appearedAction(.home)
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
                            .font(.circleButtonFontMedium)
                            .foregroundStyle(.red)
                            .padding()
                    }
                }
                Text(viewModel.dynamicInfoText)
                    .font(.circleButtonFontMedium)
                    .padding(.leading, 20)
                    .lineLimit(6)
            }
            Spacer()
            VStack(spacing: 8) {
                CircleButtonView(buttonTitle: viewModel.tibberPrice.state.toOre(),
                                 customFont: .circleButtonFontLarge,
                                 buttonSize: 60,
                                 icon: nil,
                                 action: viewModel.showNordPoolPrices)
                Text("""
                Husets effekt: ***\(viewModel.pulsePower.state.toKW())***
                Producerar: ***\(viewModel.solarPower.state.toKW())***
                Förbrukat idag: ***\(viewModel.pulseConsumptionToday.state.toKWh())***
                """)
                .font(.circleButtonFontMedium)
            }
            .padding(.trailing, 20)
        }
        .foregroundStyle(.white)
    }
}

private struct HomeNavigationButtonsView: View {
    @ObservedObject var viewModel: HomeViewModel
    let buttonSize = 90.0
    let heatersButton = NavButton(buttonTitle: "", image: Image(imageName: .aircondition))
    let carButton = NavButton(buttonTitle: "", image: Image(systemName: "car.fill"))

    let roborockButton = NavButton(buttonTitle: "",
                                   image: Image("roborocks7"),
                                   buttonImageWidth: 50,
                                   buttonImageHeight: 50)
    let cctvButton = NavButton(buttonTitle: "",
                               image: Image(systemName: "video.fill"),
                               buttonImageWidth: 45,
                               buttonImageHeight: 30)

    var body: some View {
        let lightsButton = NavButton(buttonTitle: "",
                                     image: Image(systemName: "lightbulb.fill"),
                                     buttonImageWidth: 30,
                                     buttonImageHeight: 50,
                                     isActive: viewModel.allLights.isActive)
        VStack {
            HStack(spacing: 20) {
                NavigationLink(value: Destination.heaters,
                               label: { HassButtonLabel(button: AnyView(heatersButton)) })

                NavigationLink(value: Destination.eniro,
                               label: { HassButtonLabel(button: AnyView(carButton)) })

                NavigationLink(value: Destination.roborock,
                               label: { HassButtonLabel(button: AnyView(roborockButton)) })
            }
            HStack {
                NavigationLink(value: Destination.cameras,
                               label: { HassButtonLabel(button: AnyView(cctvButton)) })

                NavigationLink(value: Destination.lights,
                               label: { HassButtonLabel(button: AnyView(lightsButton)) })
                    .contextMenu {
                        Button {
                            viewModel.toggle(light: viewModel.allLights)
                        } label: {
                            Text("Toggla lampor")
                        }
                    }
            }
        }
    }
}

private struct HomeServiceButtonsView: View {
    @ObservedObject var viewModel: HomeViewModel
    @State private var isShowingAlert = false
    let buttonSize = 90.0

    var body: some View {
        VStack {
            HStack {
                CircleButtonView(buttonTitle: "\(viewModel.frontDoor.actionText) framdörren",
                                 customFont: .circleButtonFontSmall,
                                 isActive: viewModel.frontDoor.isActive,
                                 buttonSize: buttonSize,
                                 icon: viewModel.frontDoor.image,
                                 iconWidth: viewModel.frontDoor.isActive ? 30 : 20,
                                 iconHeight: 30,
                                 isLoading: viewModel.frontDoor.isLoading,
                                 action: viewModel.toggleStateForFrontDoor)
                    .disabled(viewModel.frontDoor.isLoading)
                CircleButtonView(buttonTitle: "\(viewModel.sideDoor.actionText) sidodörren",
                                 customFont: .circleButtonFontSmall,
                                 isActive: viewModel.sideDoor.isActive,
                                 buttonSize: buttonSize,
                                 icon: viewModel.sideDoor.image,
                                 iconWidth: viewModel.sideDoor.isActive ? 30 : 20,
                                 iconHeight: 30,
                                 isLoading: viewModel.sideDoor.isLoading,
                                 action: viewModel.toggleStateForSideDoor)
                    .disabled(viewModel.sideDoor.isLoading)
                CircleButtonView(buttonTitle: "\(viewModel.storageLock.actionText) förrådet",
                                 customFont: .circleButtonFontSmall,
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
                CircleButtonView(buttonTitle: viewModel.coffeeMachine.title,
                                 customFont: .circleButtonFontSmall,
                                 isActive: viewModel.coffeeMachine.isActive,
                                 activeColor: viewModel.coffeeMachine.activeColor,
                                 buttonSize: buttonSize,
                                 icon: viewModel.coffeeMachine.image,
                                 iconWidth: 25,
                                 iconHeight: 35,
                                 indicatorIcon: viewModel.coffeeMachineStartTimeEnabled.timerEnabledIcon,
                                 action: viewModel.toggleCoffeeMachine)
                    .contextMenu {
                        Button(action: {
                            viewModel.showCoffeeMachineScheduling()
                        }, label: {
                            Text("Schemalägg nästa start")
                        })
                    }
                if UserManager.currentUser == .tobias {
                    CircleButtonView(buttonTitle: "Hitta Sarah's iPhone?",
                                     customFont: .circleButtonFontSmall,
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
                                             secondaryButton: .cancel())
                                     }
                }
            }
        }
    }
}

struct Home_Previews: PreviewProvider {
    static var previews: some View {
        let hassApiService = HassApiService(urlCreator: URLCreator())
        let viewModel = HomeViewModel(websocketService: .init(),
                                      yaleApiService: YaleApiService(hassApiService: hassApiService),
                                      urlCreator: URLCreator(),
                                      toolbarReloadAction: {},
                                      appearedAction: { _ in })

        VStack {
            HomeView(viewModel: viewModel)
                .backgroundModifier()
        }
    }
}
