//
//  HomeViewModel.swift
//  IntelliNest
//
//  Created by Tobias on 2022-08-20.
//

import CoreLocation
import Foundation
import ShipBookSDK
import SwiftUI
import UIKit
import WidgetKit

class HomeViewModel: ObservableObject {
    @Published var sideDoor = YaleLock(id: .sideDoor)
    @Published var frontDoor = YaleLock(id: .frontDoor)
    @Published var storageLock = LockEntity(entityId: .storageLock)
    @Published var allLights = LightEntity(entityId: .allLights)
    @Published var coffeeMachine = SwitchEntity(entityId: .coffeeMachine)
    @Published var sarahsIphone = Entity(entityId: .hittaSarahsIphone)
    @Published var shouldShowCoffeeMachineScheduling = false
    @Published var coffeeMachineStartTime = Entity(entityId: .coffeeMachineStartTime)
    @Published var coffeeMachineStartTimeEnabled = Entity(entityId: .coffeeMachineStartTimeEnabled)
    @Published var nordPool = NordPoolEntity(entityId: .nordPool)
    @Published var sonnenBattery = SonnenEntity(entityID: .sonnenBattery)
    @Published var pulsePower = Entity(entityId: .pulsePower)
    @Published var tibberPrice = Entity(entityId: .tibberPrice)
    @Published var pulseConsumptionToday = Entity(entityId: .pulseConsumptionToday)
    @Published var washerCompletionTime = Entity(entityId: .washerCompletionTime)
    @Published var washerState = Entity(entityId: .washerState)
    @Published var dryerCompletionTime = Entity(entityId: .dryerCompletionTime)
    @Published var dryerState = Entity(entityId: .dryerState)
    @Published var easeeCharger = Entity(entityId: .easeeCharger)
    @Published var generalWasteDate = Entity(entityId: .generalWasteDate)
    @Published var plasticWasteDate = Entity(entityId: .plasticWasteDate)
    @Published var isSarahsPillsTaken: Bool

    @Published var noLocationAccess = false

    var isReloading = false
    let entityIDs: [EntityId] = [.hittaSarahsIphone, .coffeeMachine, .storageLock, .coffeeMachineStartTime, .coffeeMachineStartTimeEnabled,
                                 .sonnenBattery, .pulsePower, .tibberPrice, .pulseConsumptionToday, .washerCompletionTime,
                                 .dryerCompletionTime, .washerState, .dryerState, .easeeCharger,
                                 .generalWasteDate, .plasticWasteDate]

    private var websocketService: WebSocketService
    private let locationManager = CLLocationManager()
    let yaleApiService: YaleApiService
    var urlCreator: URLCreator
    let showHeatersAction: MainActorVoidClosure
    let showEniroAction: MainActorVoidClosure
    let showRoborockAction: MainActorVoidClosure
    let showPowerGridAction: MainActorVoidClosure
    let showCamerasAction: MainActorVoidClosure
    let showLightsAction: MainActorVoidClosure
    private(set) var toolbarReloadAction: MainActorAsyncVoidClosure

    init(websocketService: WebSocketService,
         yaleApiService: YaleApiService,
         urlCreator: URLCreator,
         showHeatersAction: @escaping MainActorVoidClosure,
         showEniroAction: @escaping MainActorVoidClosure,
         showRoborockAction: @escaping MainActorVoidClosure,
         showPowerGridAction: @escaping MainActorVoidClosure,
         showCamerasAction: @escaping MainActorVoidClosure,
         showLightsAction: @escaping MainActorVoidClosure,
         toolbarReloadAction: @escaping MainActorAsyncVoidClosure) {
        self.websocketService = websocketService
        self.yaleApiService = yaleApiService
        self.urlCreator = urlCreator
        self.showHeatersAction = showHeatersAction
        self.showEniroAction = showEniroAction
        self.showRoborockAction = showRoborockAction
        self.showPowerGridAction = showPowerGridAction
        self.showCamerasAction = showCamerasAction
        self.showLightsAction = showLightsAction
        self.toolbarReloadAction = toolbarReloadAction

        let lastTakenPillsDate = UserDefaults.shared.value(forKey: StorageKeys.sarahPills.rawValue) as? Date
        isSarahsPillsTaken = Calendar.current.isDateInToday(lastTakenPillsDate ?? .distantPast)
    }

    @MainActor
    func reload() async {
        if !isReloading {
            isReloading = true
            async let tmpSideDoorState = await reload(lockID: sideDoor.id)
            async let tmpFrontDoorState = await reload(lockID: frontDoor.id)

            (sideDoor.lockState, frontDoor.lockState) = await(tmpSideDoorState, tmpFrontDoorState)
            isReloading = false
        }
    }

    func toggle(light: LightEntity) {
        let action: Action = light.isActive ? .turnOff : .turnOn
        websocketService.updateLights(lightIDs: [light.entityId], action: action, brightness: light.brightness)
    }

    func turnOffLight(_ light: LightEntity) {
        websocketService.updateLights(lightIDs: [light.entityId], action: .turnOff, brightness: 0)
    }

    func toggleStateForSarahsIphone() {
        let action: Action = sarahsIphone.isActive ? .turnOff : .turnOn
        websocketService.updateEntity(entityID: .hittaSarahsIphone, domain: .script, action: action)
    }

    func toggleCoffeeMachine() {
        let action: Action = coffeeMachine.isActive ? .turnOff : .turnOn
        websocketService.updateEntity(entityID: .coffeeMachine, domain: .switchDomain, action: action)
    }

    func showCoffeeMachineScheduling() {
        if !coffeeMachineStartTimeEnabled.isActive {
            toggleCoffeeMachineStarTimeEnabled()
        }

        shouldShowCoffeeMachineScheduling = true
    }

    func updateDateTimeEntity(entity: Entity) {
        websocketService.updateDateTimeEntity(entity: entity)
    }

    func toggleCoffeeMachineStarTimeEnabled() {
        let action: Action = coffeeMachineStartTimeEnabled.isActive ? .turnOff : .turnOn
        websocketService.updateEntity(entityID: .coffeeMachineStartTimeEnabled, domain: .inputBoolean, action: action)
    }

    func toggleStateForStorageLock() {
        let action: Action = storageLock.lockState == .unlocked ? .lock : .unlock
        storageLock.expectedState = action == .lock ? .locked : .unlocked
        websocketService.updateEntity(entityID: .storageLock, domain: .lock, action: action)
    }

    func lockStorage() {
        let action: Action = .lock
        storageLock.expectedState = .locked
        websocketService.updateEntity(entityID: .storageLock, domain: .lock, action: action)
    }

    func unlockStorage() {
        let action: Action = .unlock
        storageLock.expectedState = .unlocked
        websocketService.updateEntity(entityID: .storageLock, domain: .lock, action: action)
    }

    func checkLocationAccess() {
        Task { @MainActor in
            let status = locationManager.authorizationStatus
            noLocationAccess = status != .authorizedWhenInUse && status != .authorizedAlways
        }
    }

    func openLocationSettings() {
        Task { @MainActor in
            guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                return
            }

            if UIApplication.shared.canOpenURL(settingsUrl) {
                UIApplication.shared.open(settingsUrl, options: [:], completionHandler: nil)
            }
        }
    }

    // swiftlint:disable cyclomatic_complexity
    func reload(entityID: EntityId, state: String, lastChanged: Date? = nil) {
        switch entityID {
        case .allLights:
            allLights.state = state
        case .hittaSarahsIphone:
            sarahsIphone.state = state
        case .coffeeMachine:
            coffeeMachine.state = state
            if let lastChanged {
                coffeeMachine.lastChanged = lastChanged
            }
        case .storageLock:
            storageLock.state = state
        case .coffeeMachineStartTime:
            coffeeMachineStartTime.state = state
        case .coffeeMachineStartTimeEnabled:
            coffeeMachineStartTimeEnabled.state = state
        case .pulsePower:
            pulsePower.state = state
        case .tibberPrice:
            tibberPrice.state = state
        case .pulseConsumptionToday:
            pulseConsumptionToday.state = state
        case .washerCompletionTime:
            washerCompletionTime.state = state
        case .washerState:
            washerState.state = state
        case .dryerCompletionTime:
            dryerCompletionTime.state = state
        case .dryerState:
            dryerState.state = state
        case .easeeCharger:
            easeeCharger.state = state
        case .generalWasteDate:
            generalWasteDate.state = state
        case .plasticWasteDate:
            plasticWasteDate.state = state
        default:
            Log.error("HomeViewModel doesn't reload entityID: \(entityID)")
        }
    }

    @MainActor
    func reloadNordPoolEntity(nordPoolEntity: NordPoolEntity) {
        nordPool = nordPoolEntity
    }

    @MainActor
    func reloadSonnenBattery(_ sonnenEntity: SonnenEntity) {
        sonnenBattery.update(from: sonnenEntity)
    }

    @MainActor
    func reloadSonnenStatusBattery(_ sonnenStatusEntity: SonnenStatusEntity) {
        sonnenBattery.update(from: sonnenStatusEntity)
    }

    @MainActor
    func reloadLockUntilExpectedState(lockID: LockID) async {
        var isLoading = true
        var count = 0
        while isLoading == true {
            try? await Task.sleep(seconds: 0.3)
            if lockID == .frontDoor {
                frontDoor.lockState = await reload(lockID: frontDoor.id)
                isLoading = frontDoor.isLoading
            } else if lockID == .sideDoor {
                sideDoor.lockState = await reload(lockID: sideDoor.id)
                isLoading = sideDoor.isLoading
            } else {
                Log.error("Tried to reload unhandled lock: \(lockID)")
                isLoading = false
            }
            count += 1
            if count > 25 {
                isLoading = false
                break
            }
        }
    }

    @MainActor
    func sarahDidTakePills() {
        UserDefaults.shared.setValue(Date(), forKey: StorageKeys.sarahPills.rawValue)
        WidgetCenter.shared.reloadAllTimelines()
        isSarahsPillsTaken = true
    }

    private func reload(lockID: LockID) async -> LockState {
        do {
            return try await yaleApiService.getLockState(lockID: lockID)
        } catch {
            Log.error("Failed to load \(lockID) with error: \(error)")
            return .unknown
        }
    }
}
