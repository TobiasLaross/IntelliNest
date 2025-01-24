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
    @Published var navigationPath = [Destination]() {
        didSet {
            updateActiveView()
            if navigationPath.isEmpty {
                Task {
                    await homeViewModel.reload()
                    await homeViewModel.reloadYaleLocks()
                }
            }
        }
    }

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
    private var repeatReloadTask: Task<Void, Error>?
    private var continousReloadTask: Task<Void, Error>?
    private var shouldSkipContinousReload = false

    var currentDestination: Destination {
        navigationPath.last ?? .home
    }

    private var homeCoordinates: Coordinates?
    private var isAppInForeground = true
    private var errorBannerDismissTask: Task<Void, Error>?
    private lazy var geoFenceManager = GeofenceManager(didEnterHomeAction: { [weak self] in
                                                           self?.didEnterHome()
                                                       },
                                                       didExitHomeAction: { [weak self] in
                                                           self?.didExitHome()
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
                                           showLightsAction: { [weak self] in
                                               self?.push(.lights)
                                           },
                                           repeatReloadAction: { [weak self] times in
                                               self?.repeatReload(times: times)
                                           },
                                           toolbarReloadAction: toolbarReload)
    lazy var electricityViewModel = ElectricityViewModel(sonnenBattery: SonnenEntity(entityID: .sonnenBattery),
                                                         restAPIService: restAPIService)
    lazy var heatersViewModel = HeatersViewModel(restAPIService: restAPIService,
                                                 showHeaterDetails: { [weak self] heaterID in
                                                     if heaterID == .heaterCorridor {
                                                         self?.push(.corridorHeaterDetails)
                                                     } else {
                                                         self?.push(.playroomHeaterDetails)
                                                     }
                                                 })
    lazy var lynkViewModel = LynkViewModel(restAPIService: restAPIService,
                                           repeatReloadAction: { [weak self] times in
                                               self?.repeatReload(times: times)
                                           }, showClimateSchedulingAction: { [weak self] in
                                               self?.push(.eniroClimateSchedule)
                                           })
    lazy var eniroClimateScheduleViewModel = EniroClimateScheduleViewModel(apiService: restAPIService)
    lazy var roborockViewModel = RoborockViewModel(restAPIService: restAPIService,
                                                   repeatReloadAction: { [weak self] times in
                                                       self?.repeatReload(times: times)
                                                   })

    lazy var lightsViewModel = LightsViewModel(restAPIService: restAPIService,
                                               repeatReloadAction: { [weak self] times in
                                                   self?.repeatReload(times: times)
                                               })

    init() {
        if UserDefaults.shared.value(forKey: StorageKeys.sarahPills.rawValue) == nil {
            UserDefaults.shared.setValue(Date.distantPast, forKey: StorageKeys.sarahPills.rawValue)
        }

        WidgetCenter.shared.reloadAllTimelines()

        Task {
            await urlCreator.updateConnectionState()
            await heatersViewModel.reload()
            await reloadHomeCoordinates()
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
            case .electricity:
                showElectricityView()
            case .home:
                Text("Not implemented show for home")
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

                await reloadCurrentModel()
            }
            updateActiveView()
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
        shouldSkipContinousReload = true
        switch destination {
        case .home:
            homeViewModel.checkLocationAccess()
            await homeViewModel.reload()
            await homeViewModel.reloadYaleLocks()
        case .electricity:
            await electricityViewModel.reload()
        case .heaters, .playroomHeaterDetails, .corridorHeaterDetails:
            await heatersViewModel.reload()
        case .lynk:
            await lynkViewModel.reload()
        case .eniroClimateSchedule:
            await eniroClimateScheduleViewModel.reload()
        case .lights:
            await lightsViewModel.reload()
        case .roborock:
            await roborockViewModel.reload()
        }
    }

    func didEnterForeground() {
        isAppInForeground = true
        updateActiveView()
        Task {
            await reloadConnection()
            await reload(for: currentDestination)
            if currentDestination != .electricity {
                await reload(for: .electricity)
            }
        }
    }

    func didResignForeground() {
        isAppInForeground = false
        electricityViewModel.isViewActive = false
        homeViewModel.resetExpectedLockStates()
        repeatReloadTask?.cancel()
        continousReloadTask?.cancel()
        lynkViewModel.lynkDoorLock.expectedState = .unknown
    }

    @MainActor
    func toolbarReload() async {
        if currentDestination == .lynk {
            lynkViewModel.forceUpdate()
            try? await Task.sleep(seconds: 2)
            repeatReload(times: 6)
        } else {
            await reloadCurrentModel()
        }
    }

    @MainActor
    func reloadCurrentModel() async {
        await reloadConnection()
        await reload(for: currentDestination)
    }

    func reloadHomeCoordinates() async {
        homeCoordinates = UserDefaults.standard.value(forKey: StorageKeys.homeCoordinatesDual.rawValue) as? Coordinates
        do {
            let homeLocation = try await restAPIService.reload(entityId: .homeLocation, entityType: HomeLocationEntity.self)
            let homeCoordinates = Coordinates(longitude: homeLocation.longitude, latitude: homeLocation.latitude)
            if self.homeCoordinates != homeCoordinates {
                geoFenceManager.configureGeoFence(homeCoordinates: homeCoordinates)
                self.homeCoordinates = homeCoordinates
                UserDefaults.standard.setCoordinates(homeCoordinates, forKey: StorageKeys.homeCoordinatesDual)
            }
        } catch {
            Log.error("Failed to load home coordinates: \(error)")
        }

        if let homeCoordinates {
            geoFenceManager.configureGeoFence(homeCoordinates: homeCoordinates)
        }
    }

    @MainActor
    func reloadConnection(ignoreLocalSSID _: Bool = false) async {
        await urlCreator.updateConnectionState(ignoreLocalSSID: false)
    }
}

private extension Navigator {
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

    func repeatReload(times: Int) {
        repeatReloadTask?.cancel()
        repeatReloadTask = Task {
            do {
                try await Task.sleep(seconds: 0.3)
                for _ in 0 ..< times {
                    if currentDestination == .home {
                        shouldSkipContinousReload = true
                        await homeViewModel.reload()
                    } else {
                        await reload(for: currentDestination)
                    }

                    try await Task.sleep(seconds: times > 5 ? 1.0 : 0.5)
                }
            } catch {
                // Restarted
            }
        }
    }

    func restartContinousReloadTask() {
        continousReloadTask?.cancel()
        continousReloadTask = Task {
            do {
                while true {
                    try await Task.sleep(seconds: 5)
                    if !shouldSkipContinousReload {
                        await reload(for: currentDestination)
                    }

                    shouldSkipContinousReload = false
                }
            } catch {
                // Cancelled
            }
        }
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
