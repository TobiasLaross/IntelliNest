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

enum WebsocketConnectionInfo {
    case unknown
    case waitingForPong
}

@MainActor
class Navigator: ObservableObject {
    @ObservedObject var urlCreator = URLCreator()
    @Published var navigationPath = [Destination]() { didSet {
        updateActiveView()
    }}
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
    @Published var websocketConnectionInfo: WebsocketConnectionInfo = .unknown

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
                                                 },
                                                 setConnectionInfo: { [weak self] info in
                                                     Task { @MainActor in
                                                         self?.websocketConnectionInfo = info
                                                     }
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
        homeCoordinates = UserDefaults.standard.value(forKey: StorageKeys.homeCoordinatesDual.rawValue) as? Coordinates
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
            await heatersViewModel.reload()
        }

        if let webhookID = UserDefaults.standard.string(forKey: StorageKeys.webhookID.rawValue) {
            self.webhookID = webhookID
        }

        handlePushNotificationPermissions()
    }

    func pop() {
        navigationPath.removeLast()
        updateActiveView()
    }

    func show(destination: Destination) -> some View {
        Group {
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

                updateActiveView()
            }
        }
    }

    func showLynkHeaterOptions() {
        lynkViewModel.isShowingHeaterOptions = true
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
            await lynkViewModel.reload(forceReload: true)
        case .eniroClimateSchedule:
            await eniroClimateScheduleViewModel.reload()
        case .roborock, .cameras, .lights, .playroomHeaterDetails, .corridorHeaterDetails:
            break
        }
    }

    func didEnterForeground() {
        isAppInForeground = true
        webSocketService.didEnterForeground()
        updateActiveView()
        Task {
            await reloadConnection()
            await reload(for: currentDestination)
        }
    }

    func didResignForeground() {
        isAppInForeground = false
        electricityViewModel.isViewActive = false
        homeViewModel.resetExpectedLockStates()
        lynkViewModel.lynkDoorLock.expectedState = .unknown
        webSocketService.didResignForeground()
    }

    @MainActor
    func reloadCurrentModel() async {
        await reloadConnection()
        await reload(for: currentDestination)
        webSocketService.sendPing(shouldExpectPong: false)
    }

    func setHomeCoordinates(_ homeCoordinates: Coordinates) {
        if self.homeCoordinates != homeCoordinates {
            geoFenceManager.configureGeoFence(homeCoordinates: homeCoordinates)
            self.homeCoordinates = homeCoordinates
            UserDefaults.standard.setCoordinates(homeCoordinates, forKey: StorageKeys.homeCoordinatesDual)
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
            DetailedHeaterView(viewModel: heatersViewModel, selectedHeater: .corridor)
        } else {
            DetailedHeaterView(viewModel: heatersViewModel, selectedHeater: .playroom)
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
        Task {
            let lastEnteredHomeTime = UserDefaults.shared.value(forKey: StorageKeys.enteredHomeTime.rawValue) as? Date
            UserDefaults.shared.setValue(Date.now, forKey: StorageKeys.enteredHomeTime.rawValue)
            guard let currentUserAwayEntityID = UserManager.currentUserAwayEntityID else {
                Log.warning("Geofence utan användare: \(UserManager.currentUser)")
                return
            }
            do {
                if let lastEnteredHomeTime, Date.now.timeIntervalSince(lastEnteredHomeTime) < 10 * 60 {
                    let userIsAway = try await restAPIService.get(entityId: currentUserAwayEntityID, entityType: Entity.self)
                    guard userIsAway.isActive else {
                        Log.debug("Geofence användare redan hemma")
                        return
                    }
                }
            } catch {
                Log.error("Failed to fetch user away status for \(currentUserAwayEntityID)")
            }

            NotificationService.sendNotification(title: "Välkommen hem",
                                                 message: "",
                                                 identifier: "Geofence-did-enter-home")
            updateYaleLocks(with: .unlock)
            restAPIService.update(entityID: currentUserAwayEntityID, domain: .inputBoolean, action: .turnOff)
        }
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
            _ = await (tmpFrontDoorSuccess, tmpSideDoorSuccess)
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

    func updateActiveView() {
        camerasViewModel.setIsActiveScreen(currentDestination == .cameras)
        electricityViewModel.isViewActive = currentDestination == .electricity
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

private extension UserManager {
    static var currentUserAwayEntityID: EntityId? {
        switch currentUser {
        case .sarah:
            .sarahIsAway
        case .tobias:
            .tobiasIsAway
        default:
            nil
        }
    }
}
