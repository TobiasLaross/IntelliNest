//
//  Navigator.swift
//  IntelliNest
//
//  Created by Tobias on 2023-04-29.
//

import Foundation
import ShipBookSDK
import SwiftUI
import WidgetKit

@MainActor
class Navigator: ObservableObject {
    @ObservedObject var urlCreator = URLCreator()
    @Published var navigationPath = [Destination]()
    @Published var errorBannerTitle: String? {
        didSet {
            if errorBannerTitle != nil {
                errorBannerDismissTask?.cancel()
                errorBannerDismissTask = Task { @MainActor in
                    do {
                        try await Task.sleep(seconds: 6)
                        errorBannerTitle = nil
                        errorBannerMessage = nil
                    } catch {}
                }
            } else {
                errorBannerDismissTask?.cancel()
                errorBannerDismissTask = nil
            }
        }
    }

    @Published var errorBannerMessage: String?

    var currentDestination: Destination {
        navigationPath.last ?? .home
    }

    private var homeCoordinates: Coordinates?
    private var webhookID: String?
    private var isAppInForeground = true
    private var errorBannerDismissTask: Task<Void, Error>?
    private lazy var geoFenceManager = GeofenceManager(didEnterHomeAction: { [weak self] in
                                                           self?.didEnterHome()
                                                       },
                                                       didExitHomeAction: { [weak self] in
                                                           self?.didExitHome()
                                                       })

    lazy var webSocketService = WebSocketService(reloadConnectionAction: { [weak self] in
                                                     Task { [weak self] in
                                                         await self?.urlCreator.updateConnectionState(ignoreLocalSSID: true)
                                                     }
                                                 },
                                                 setErrorBannerText: { [weak self] title, message in
                                                     self?.setErrorBannerText(title: title, message: message)
                                                 })
    lazy var restAPIService = RestAPIService(urlCreator: urlCreator,
                                             setErrorBannerText: { [weak self] title, message in
                                                 self?.setErrorBannerText(title: title, message: message)
                                             })
    lazy var yaleApiService = YaleApiService(hassAPIService: restAPIService)
    lazy var homeViewModel = HomeViewModel(restAPIService: restAPIService,
                                           yaleApiService: yaleApiService,
                                           urlCreator: urlCreator,
                                           showHeatersAction: { [weak self] in
                                               self?.push(.heaters)
                                           },
                                           showLynkAction: { [weak self] in
                                               self?.push(.lynk)
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
    lazy var electricityViewModel = ElectricityViewModel(sonnenBattery: SonnenEntity(entityID: .sonnenBattery),
                                                         restAPIService: restAPIService,
                                                         websocketService: webSocketService)
    lazy var camerasViewModel = CamerasViewModel(urlCreator: urlCreator, websocketService: webSocketService, apiService: restAPIService)
    lazy var heatersViewModel = HeatersViewModel(restAPIService: restAPIService,
                                                 showHeaterDetails: { [weak self] heaterID in
                                                     if heaterID == .heaterCorridor {
                                                         self?.push(.corridorHeaterDetails)
                                                     } else {
                                                         self?.push(.playroomHeaterDetails)
                                                     }
                                                 })
    lazy var lynkViewModel = LynkViewModel(restAPIService: restAPIService,
                                           showClimateSchedulingAction: { [weak self] in
                                               self?.push(.eniroClimateSchedule)
                                           })
    lazy var eniroClimateScheduleViewModel = EniroClimateScheduleViewModel(apiService: restAPIService)
    lazy var roborockViewModel = RoborockViewModel(restAPIService: restAPIService)
    lazy var lightsViewModel = LightsViewModel(restAPIService: restAPIService)

    init() {
        homeCoordinates = UserDefaults.standard.value(forKey: StorageKeys.homeCoordinates.rawValue) as? Coordinates
        urlCreator.delegate = self
        webSocketService.delegate = self
        if UserDefaults.shared.value(forKey: StorageKeys.sarahPills.rawValue) == nil {
            UserDefaults.shared.setValue(Date.distantPast, forKey: StorageKeys.sarahPills.rawValue)
        }

        if let homeCoordinates {
            geoFenceManager.configureGeoFence(homeCoordinates: homeCoordinates)
        }

        WidgetCenter.shared.reloadAllTimelines()

        Task {
            await urlCreator.updateConnectionState()
        }

        if let webhookID = UserDefaults.standard.string(forKey: StorageKeys.webhookID.rawValue) {
            self.webhookID = webhookID
        }

        handlePushNotificationPermissions()
    }

    func pop() {
        navigationPath.removeLast()
        camerasViewModel.setIsActiveScreen(currentDestination == .cameras)
        electricityViewModel.isViewActive = currentDestination == .electricity
        lynkViewModel.isViewActive = currentDestination == .lynk
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
            case .heaters:
                showHeatersView()
            case .lynk:
                showLynkView()
            case .corridorHeaterDetails:
                showHeaterDetailsView(heaterID: .heaterCorridor)
            case .playroomHeaterDetails:
                showHeaterDetailsView(heaterID: .heaterPlayroom)
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
                async let updateConnectionStateTask = Task { await urlCreator.updateConnectionState() }
                async let reloadCurrentModelTask = Task { await reloadCurrentModel() }

                await updateConnectionStateTask.value
                await reloadCurrentModelTask.value

                camerasViewModel.setIsActiveScreen(destination == .cameras)
                electricityViewModel.isViewActive = destination == .electricity
                lynkViewModel.isViewActive = destination == .lynk
            }
        }
    }

    func lynkStartClimate() {
        restAPIService.callScript(scriptID: .lynkStartClimate)
    }

    func snoozeWashingMachine() {
        Task {
            await restAPIService.setState(for: .snoozeWashingMachine, in: .inputBoolean, using: .turnOn)
        }
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
        case .lynk:
            await lynkViewModel.reload()
        case .eniroClimateSchedule:
            await eniroClimateScheduleViewModel.reload()
        case .roborock, .cameras, .lights, .playroomHeaterDetails, .corridorHeaterDetails:
            break
        }
    }

    func didEnterForeground() {
        isAppInForeground = true
        electricityViewModel.isViewActive = currentDestination == .electricity
        lynkViewModel.isViewActive = currentDestination == .lynk
        Task {
            await reloadConnection()
            await reload(for: currentDestination)
        }
    }

    func didResignForeground() {
        isAppInForeground = false
        electricityViewModel.isViewActive = false
        lynkViewModel.isViewActive = false
        homeViewModel.resetExpectedLockStates()
        lynkViewModel.lynkDoorLock.expectedState = .unknown
        webSocketService.isExpectingTextResponse = false
        webSocketService.disconnect()
    }

    @MainActor
    func reloadCurrentModel() async {
        await reloadConnection()
        await reload(for: currentDestination)
    }

    func setHomeCoordinates(_ homeCoordinates: Coordinates) {
        if self.homeCoordinates != homeCoordinates {
            geoFenceManager.configureGeoFence(homeCoordinates: homeCoordinates, oldCoordinates: self.homeCoordinates)
            self.homeCoordinates = homeCoordinates
            UserDefaults.standard.setCoordinates(homeCoordinates, forKey: StorageKeys.homeCoordinates)
        }
    }

    @MainActor
    func reloadConnection(ignoreLocalSSID _: Bool = false) async {
        await urlCreator.updateConnectionState(ignoreLocalSSID: false)
    }
}

private extension Navigator {
    func showCamerasView() -> CamerasView {
        // swiftformat:disable all
        CamerasView(viewModel: self.camerasViewModel)
        // swiftformat:enable all
    }

    func showElectricityView() -> ElectricityView {
        ElectricityView(viewModel: electricityViewModel)
    }

    func showHomeView() -> HomeView {
        HomeView(viewModel: homeViewModel)
    }

    func showHeatersView() -> HeatersView {
        HeatersView(viewModel: heatersViewModel)
    }

    func showLynkView() -> LynkView {
        LynkView(viewModel: lynkViewModel)
    }

    func showHeaterDetailsView(heaterID: EntityId) -> DetailedHeaterView {
        if heaterID == .heaterCorridor {
            DetailedHeaterView(heater: heatersViewModel.heaterCorridor,
                               fanMode: heatersViewModel.heaterCorridor.fanMode,
                               horizontalMode: heatersViewModel.heaterCorridor.vaneHorizontal,
                               verticalMode: heatersViewModel.heaterCorridor.vaneVertical,
                               fanModeSelectedCallback: heatersViewModel.setFanMode,
                               horizontalModeSelectedCallback: heatersViewModel.horizontalModeSelectedCallback,
                               verticalModeSelectedCallback: heatersViewModel.verticalModeSelectedCallback)
        } else {
            DetailedHeaterView(heater: heatersViewModel.heaterPlayroom,
                               fanMode: heatersViewModel.heaterPlayroom.fanMode,
                               horizontalMode: heatersViewModel.heaterPlayroom.vaneHorizontal,
                               verticalMode: heatersViewModel.heaterPlayroom.vaneVertical,
                               fanModeSelectedCallback: heatersViewModel.setFanMode,
                               horizontalModeSelectedCallback: heatersViewModel.horizontalModeSelectedCallback,
                               verticalModeSelectedCallback: heatersViewModel.verticalModeSelectedCallback)
        }
    }

    func showEniroClimateScheduleView() -> EniroClimateScheduleView {
        EniroClimateScheduleView(viewModel: eniroClimateScheduleViewModel)
    }

    func showRoborockView() -> RoborockView {
        RoborockView(viewModel: roborockViewModel)
    }

    func showLightsView() -> LightsView {
        LightsView(viewModel: lightsViewModel)
    }

    func didEnterHome() {
        updateYaleLocks(with: .unlock)
        guard UserManager.currentUser == .sarah || UserManager.currentUser == .tobias else {
            Log.warning("Geofence utan användare: \(UserManager.currentUser)")
            return
        }
        let entityID: EntityId = UserManager.currentUser == .sarah ? .sarahIsAway : .tobiasIsAway
        restAPIService.update(entityID: entityID, domain: .inputBoolean, action: .turnOff)
    }

    func didExitHome() {
        updateYaleLocks(with: .lock)
        guard UserManager.currentUser == .sarah || UserManager.currentUser == .tobias else {
            Log.warning("Geofence utan användare: \(UserManager.currentUser)")
            return
        }
        let entityID: EntityId = UserManager.currentUser == .sarah ? .sarahIsAway : .tobiasIsAway
        restAPIService.update(entityID: entityID, domain: .inputBoolean, action: .turnOn)
    }

    func updateYaleLocks(with action: Action) {
        Task {
            async let tmpFrontDoorSuccess = yaleApiService.setLockState(lockID: .frontDoor, action: action)
            async let tmpSideDoorSuccess = yaleApiService.setLockState(lockID: .sideDoor, action: action)
            let (frontDoorSuccess, sideDoorSuccess) = await(tmpFrontDoorSuccess, tmpSideDoorSuccess)
            if !frontDoorSuccess || !sideDoorSuccess {
                var errorMessage = "Lyckades inte låsa".appending(action == .unlock ? " upp" : "")
                if !frontDoorSuccess && !sideDoorSuccess {
                    errorMessage.append(frontDoorSuccess ? "" : " varken fram- eller sidodörren")
                } else if !frontDoorSuccess {
                    errorMessage.append(frontDoorSuccess ? "" : " framdörren.")
                } else if !sideDoorSuccess {
                    errorMessage.append(sideDoorSuccess ? "" : " sidodörren.")
                }

                if UserManager.currentUser == .tobias {
                    NotificationService.sendNotification(title: "Geofence",
                                                         message: errorMessage,
                                                         identifier: "Geofence-yale-failure")
                }
            }
        }
    }

    func setErrorBannerText(title: String, message: String) {
        if isAppInForeground {
            Task { @MainActor in
                errorBannerTitle = title
                errorBannerMessage = message
            }
        }
    }

    func handlePushNotificationPermissions() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert]) { [weak self] granted, error in
                if granted {
                    Task { @MainActor in
                        UIApplication.shared.registerForRemoteNotifications()
                        if let webhookID = UserDefaults.standard.string(forKey: StorageKeys.webhookID.rawValue) {
                            self?.webhookID = webhookID
                        }

                        try? await Task.sleep(seconds: 1.5)

                        if let apnsToken = UserDefaults.standard.string(forKey: StorageKeys.apnsToken.rawValue) {
                            self?.registerAPNSToken(apnsToken)
                        }
                    }
                } else if let error {
                    Log.error("Failed to requestAuthorization for push, \(error.localizedDescription)")
                }
            }
    }

    func registerAPNSToken(_ apnsToken: String) {
        let user = UserManager.currentUser
        #if DEBUG
            if user == .tobias {
                restAPIService.registerAPNSToken(apnsToken)
            }
        #else
            if user == .sarah || user == .tobias {
                restAPIService.registerAPNSToken(apnsToken)
            }
        #endif
    }
}
