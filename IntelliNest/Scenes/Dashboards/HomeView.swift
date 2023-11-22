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
        let heatersButton = NavButton(buttonTitle: "Värmepumpar", image: Image(imageName: .aircondition))
        let carButton = NavButton(buttonTitle: "E-Niro", image: Image(systemName: "car.fill"))

        let roborockButton = NavButton(buttonTitle: "Roborock",
                                       image: Image("roborocks7"),
                                       buttonImageWidth: 50,
                                       buttonImageHeight: 50)
        let cctvButton = NavButton(buttonTitle: "Kameror",
                                   image: Image(systemName: "video.fill"),
                                   buttonImageWidth: 50,
                                   buttonImageHeight: 35)
        let lightsButton = NavButton(buttonTitle: "Lampor",
                                     image: Image(systemName: "lightbulb.fill"),
                                     buttonImageWidth: 30,
                                     buttonImageHeight: 50,
                                     isActive: viewModel.allLights.isActive)
        ZStack {
            VStack {
                HouseInfoView(viewModel: viewModel)
                    .padding(.vertical, 20)
                LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), alignment: .center, spacing: 10) {
                    NavigationLink(value: Destination.heaters,
                                   label: { HassButtonLabel(button: AnyView(heatersButton)) })

                    NavigationLink(value: Destination.eniro,
                                   label: { HassButtonLabel(button: AnyView(carButton)) })

                    CoffeeMachineButtonView(viewModel: viewModel)
                    SideDoorButtonView(viewModel: viewModel)
                    FrontDoorButtonView(viewModel: viewModel)
                    StorageDoorButtonView(viewModel: viewModel)

                    if UserManager.currentUser == .tobias {
                        SarahsIphoneButton(viewModel: viewModel)
                    }

                    NavigationLink(value: Destination.roborock,
                                   label: { HassButtonLabel(button: AnyView(roborockButton)) })
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
                .padding(.horizontal, 20)
                Spacer(minLength: 50)
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
        }
    }
}

private struct SarahsIphoneButton: View {
    @ObservedObject var viewModel: HomeViewModel
    @State private var isShowingAlert = false

    var body: some View {
        DashboardButtonView(text: "Hitta Sarah's iPhone?",
                            isActive: viewModel.sarahsIphone.isActive,
                            icon: viewModel.sarahIphoneimage,
                            iconWidth: viewModel.sarahsIphone.isActive ? 60 : 25,
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

private struct HouseInfoView: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                CircleButtonView(buttonTitle: viewModel.tibberPrice.state.toOre(),
                                 customFont: .circleButtonFontLarge,
                                 icon: nil,
                                 buttonSize: 60,
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
    }
}

private struct CoffeeMachineButtonView: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        DashboardButtonView(text: viewModel.coffeeMachine.title,
                            isActive: viewModel.coffeeMachine.isActive,
                            activeColor: viewModel.coffeeMachine.activeColor,
                            icon: viewModel.coffeeMachine.image,
                            iconWidth: 30,
                            indicatorIcon: viewModel.coffeeMachineStartTimeEnabled.timerEnabledIcon,
                            action: viewModel.toggleCoffeeMachine)
            .contextMenu {
                Button(action: {
                    viewModel.showCoffeeMachineScheduling()
                }, label: {
                    Text("Schemalägg nästa start")
                })
            }
    }
}

private struct SideDoorButtonView: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        DashboardButtonView(text: "\(viewModel.sideDoor.actionText) sidodörren",
                            isActive: viewModel.sideDoor.isActive,
                            icon: viewModel.sideDoor.image,
                            iconWidth: viewModel.sideDoor.isActive ? 40 : 30,
                            isLoading: viewModel.sideDoor.isLoading,
                            action: viewModel.toggleStateForSideDoor)
            .disabled(viewModel.sideDoor.isLoading)
    }
}

private struct FrontDoorButtonView: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        DashboardButtonView(text: "\(viewModel.frontDoor.actionText) framdörren",
                            isActive: viewModel.frontDoor.isActive,
                            icon: viewModel.frontDoor.image,
                            iconWidth: viewModel.frontDoor.isActive ? 40 : 30,
                            isLoading: viewModel.frontDoor.isLoading,
                            action: viewModel.toggleStateForFrontDoor)
            .disabled(viewModel.frontDoor.isLoading)
    }
}

private struct StorageDoorButtonView: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        DashboardButtonView(text: "\(viewModel.storageLock.actionText) förrådet",
                            isActive: viewModel.storageLock.isActive,
                            icon: viewModel.storageLock.image,
                            iconWidth: viewModel.storageLock.isActive ? 40 : 30,
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
            HouseInfoView(viewModel: viewModel)
        }
    }
}
