//
//  Navigator.swift
//  IntelliNest
//
//  Created by Tobias on 2023-04-29.
//

import Foundation
import SwiftUI
import WidgetKit

@MainActor
class Navigator: ObservableObject {
    @ObservedObject var urlCreator = URLCreator()
    @Published var navigationPath = [Destination]()

    var currentDestination: Destination {
        navigationPath.last ?? .home
    }

    var reloadedConnectionDate = Date.distantPast

    lazy var webSocketService = WebSocketService(reloadConnectionAction: { [weak self] in
        self?.reloadConnection()
    })
    lazy var hassApiService = HassApiService(urlCreator: urlCreator)
    lazy var yaleApiService = YaleApiService(hassApiService: hassApiService)
    lazy var homeViewModel = HomeViewModel(websocketService: webSocketService,
                                           yaleApiService: yaleApiService,
                                           urlCreator: urlCreator,
                                           showHeatersAction: { [weak self] in
                                               self?.push(.heaters)
                                           },
                                           showEniroAction: { [weak self] in
                                               self?.push(.eniro)
                                           },
                                           showRoborockAction: { [weak self] in
                                               self?.push(.roborock)
                                           },
                                           showPowerGridAction: { [weak self] in
                                               self?.push(.electricity)
                                           },
                                           showCamerasAction: { [weak self] in
                                               self?.push(.cameras)
                                           },
                                           showLightsAction: { [weak self] in
                                               self?.push(.lights)
                                           },
                                           toolbarReloadAction: reloadCurrentModel)
    lazy var camerasViewModel = CamerasViewModel(urlCreator: urlCreator, websocketService: webSocketService, apiService: hassApiService)
    lazy var electricityViewModel = ElectricityViewModel(sonnenBattery: SonnenEntity(entityID: .sonnenBattery),
                                                         websocketService: webSocketService)
    lazy var heatersViewModel = HeatersViewModel(websocketService: webSocketService,
                                                 apiService: hassApiService)
    lazy var eniroViewModel = EniroViewModel(websocketService: webSocketService,
                                             showClimateSchedulingAction: { [weak self] in
                                                 self?.push(.eniroClimateSchedule)
                                             })
    lazy var eniroClimateScheduleViewModel = EniroClimateScheduleViewModel(apiService: hassApiService)
    lazy var roborockViewModel = RoborockViewModel(websocketService: webSocketService)
    lazy var lightsViewModel = LightsViewModel(websocketService: webSocketService)

    init() {
        urlCreator.delegate = self
        webSocketService.delegate = self
        if UserDefaults.shared.value(forKey: StorageKeys.sarahPills.rawValue) == nil {
            UserDefaults.shared.setValue(Date.distantPast, forKey: StorageKeys.sarahPills.rawValue)
        }

        WidgetCenter.shared.reloadAllTimelines()

        Task {
            await urlCreator.updateConnectionState()
        }
    }

    func background() -> some View {
        Group {
            Rectangle()
                .foregroundStyle(Color.topGrayColor)
                .ignoresSafeArea()
            Rectangle()
                .foregroundColor(bodyColor)
                .edgesIgnoringSafeArea(.bottom)
        }
    }

    func pop() {
        navigationPath.removeLast()
    }

    func show(destination: Destination) -> some View {
        return Group {
            switch destination {
            case .cameras:
                showCamerasView()
            case .electricity:
                showElectricityView()
            case .home:
                Text("Not implemented for home")
//                showHomeView()
            case .heaters:
                showHeatersView()
            case .eniro:
                showEniroView()
            case .eniroClimateSchedule:
                showEniroClimateScheduleView()
            case .roborock:
                showRoborockView()
            case .lights:
                showLightsView()
            }
        }
        .backgroundModifier()
    }

    func push(_ destination: Destination) {
        if currentDestination != destination {
            Task {
                if destination == .home {
                    navigationPath = []
                } else {
                    navigationPath.append(destination)
                }
                async let updateConnectionStateTask = Task { await updateConnectionState() }
                async let reloadCurrentModelTask = Task { await reloadCurrentModel() }

                await updateConnectionStateTask.value
                await reloadCurrentModelTask.value

                camerasViewModel.setIsActiveScreen(destination == .cameras)
                electricityViewModel.isViewActive = destination == .electricity
            }
        }
    }

    func startKiaHeater() {
        webSocketService.callScript(scriptID: .eniroStartClimate)
    }

    @MainActor
    func reload(for destination: Destination) async {
        switch destination {
        case .home:
            homeViewModel.checkLocationAccess()
            await homeViewModel.reload()
        case .electricity:
            break
        case .heaters:
            await heatersViewModel.reload()
        case .eniro:
            break
        case .eniroClimateSchedule:
            await eniroClimateScheduleViewModel.reload()
        case .roborock:
            break
        case .cameras:
            break
        case .lights:
            break
        }
    }

    func didEnterForeground() {
        electricityViewModel.isViewActive = currentDestination == .electricity
        Task {
            await reloadCurrentModel()
        }
    }

    func didResignForeground() {
        electricityViewModel.isViewActive = false
    }

    @MainActor
    func reloadCurrentModel() async {
        await updateConnectionState()
        webSocketService.connect()
        webSocketService.sendGetStatesRequest()
        await reload(for: currentDestination)
    }

    @MainActor
    func updateConnectionState() async {
        await urlCreator.updateConnectionState()
    }

    private func showCamerasView() -> CamerasView {
        CamerasView(viewModel: self.camerasViewModel)
    }

    private func showElectricityView() -> ElectricityView {
        ElectricityView(viewModel: electricityViewModel)
    }

    private func showHomeView() -> HomeView {
        HomeView(viewModel: homeViewModel)
    }

    private func showHeatersView() -> HeatersView {
        HeatersView(viewModel: heatersViewModel)
    }

    private func showEniroView() -> EniroView {
        EniroView(viewModel: eniroViewModel)
    }

    private func showEniroClimateScheduleView() -> EniroClimateScheduleView {
        EniroClimateScheduleView(viewModel: eniroClimateScheduleViewModel)
    }

    private func showRoborockView() -> RoborockView {
        RoborockView(viewModel: roborockViewModel)
    }

    private func showLightsView() -> LightsView {
        LightsView(viewModel: lightsViewModel)
    }

    @MainActor
    private func reloadConnection() {
        if reloadedConnectionDate.timeIntervalSinceNow < -1 {
            reloadedConnectionDate = Date()
            Task {
                await reloadCurrentModel()
            }
        }
    }
}

extension View {
    func backgroundModifier() -> some View {
        background(
            Group {
                Rectangle()
                    .foregroundStyle(Color.topGrayColor)
                    .ignoresSafeArea()
                Rectangle()
                    .foregroundColor(bodyColor)
                    .edgesIgnoringSafeArea(.bottom)
            }
        )
    }
}
