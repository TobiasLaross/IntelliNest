//
//  Navigator.swift
//  IntelliNest
//
//  Created by Tobias on 2023-04-29.
//

import Foundation
import SwiftUI

class Navigator {
    @ObservedObject var urlCreator = URLCreator()
    var currentDestination: Destination = .home
    var webSocketService = WebSocketService()
    lazy var hassApiService = HassApiService(urlCreator: urlCreator)
    lazy var yaleApiService = YaleApiService(hassApiService: hassApiService)
    lazy var homeViewModel = HomeViewModel(hassApiService: hassApiService,
                                           yaleApiService: yaleApiService,
                                           toolbarReloadAction: reloadCurrentModel,
                                           appearedAction: setCurrentDestination)
    lazy var camerasViewModel = CamerasViewModel(urlCreator: urlCreator, websocketService: webSocketService, apiService: hassApiService)
    lazy var heatersViewModel = HeatersViewModel(apiService: hassApiService, appearedAction: setCurrentDestination)
    lazy var eniroViewModel = EniroViewModel(apiService: hassApiService, appearedAction: setCurrentDestination)
    lazy var eniroClimateScheduleViewModel = EniroClimateScheduleViewModel(apiService: hassApiService,
                                                                           appearedAction: setCurrentDestination)
    lazy var roborockViewModel = RoborockViewModel(apiService: hassApiService, appearedAction: setCurrentDestination)
    lazy var lightsViewModel = LightsViewModel(websocketService: webSocketService, appearedAction: setCurrentDestination)

    init() {
        urlCreator.delegate = self
        webSocketService.delegate = self
        Task { @MainActor in
            await urlCreator.updateConnectionState()
        }
    }

    func background() -> some View {
        Group {
            Rectangle()
                .foregroundColor(topGrayColor)
                .ignoresSafeArea()
            Rectangle()
                .foregroundColor(bodyColor)
                .edgesIgnoringSafeArea(.bottom)
        }
    }

    func show(destination: Destination) -> some View {
        setCurrentDestination(destination)
        return ZStack {
            background()
            switch destination {
            case .cameras:
                showCamerasView()
            case .home:
                Text("Home navigation not implemented")
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
    }

    func startKiaHeater() {
        Task {
            await hassApiService.callScript(entityId: .eniroClimateControl)
        }
    }

    @MainActor
    func reload(for destination: Destination) async {
        switch destination {
        case .home:
            await homeViewModel.reload()
        case .heaters:
            await heatersViewModel.reload()
        case .eniro:
            await eniroViewModel.reload()
        case .eniroClimateSchedule:
            await eniroClimateScheduleViewModel.reload()
        case .roborock:
            await roborockViewModel.reload()
        case .cameras:
            break
        case .lights:
            break
        }
    }

    func didEnterForeground() {
        webSocketService.connect()
        Task {
            await reloadCurrentModel()
        }
    }

    @MainActor
    func reloadCurrentModel() async {
        await updateConnectionState()
        await reload(for: currentDestination)
    }

    @MainActor
    func updateConnectionState() async {
        await urlCreator.updateConnectionState()
    }

    private func showCamerasView() -> CamerasView {
        CamerasView(viewModel: self.camerasViewModel)
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

    private func setCurrentDestination(_ destination: Destination) {
        if currentDestination != destination {
            currentDestination = destination
            Task { @MainActor in
                async let updateConnectionStateTask = Task { await updateConnectionState() }
                async let reloadCurrentModelTask = Task { await reloadCurrentModel() }

                await updateConnectionStateTask.value
                await reloadCurrentModelTask.value

                camerasViewModel.setIsActiveScreen(destination == .cameras)
            }
        }
    }
}
