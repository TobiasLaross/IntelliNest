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

@MainActor
class HomeViewModel: ObservableObject, Reloadable {
    @Published var sideDoor = YaleLock(id: .sideDoor)
    @Published var frontDoor = YaleLock(id: .frontDoor)
    @Published var storageLock = LockEntity(entityId: .storageLock)
    @Published var allLights = LightEntity(entityId: .allLights)
    @Published var coffeeMachine = SwitchEntity(entityId: .coffeeMachine)
    @Published var sarahsIphone = Entity(entityId: .hittaSarahsIphone)
    @Published var shouldShowCoffeeMachineScheduling = false
    @Published var coffeeMachineStartTime = Entity(entityId: .coffeeMachineStartTime)
    @Published var coffeeMachineStartTimeEnabled = Entity(entityId: .coffeeMachineStartTimeEnabled)
    @Published var pulsePower = Entity(entityId: .pulsePower)
    @Published var tibberPrice = Entity(entityId: .tibberPrice)
    @Published var pulseConsumptionToday = Entity(entityId: .pulseConsumptionToday)
    @Published var solarProductionToday = Entity(entityId: .solarProductionToday)
    @Published var washerCompletionTime = Entity(entityId: .washerCompletionTime)
    @Published var washerState = Entity(entityId: .washerState)
    @Published var dryerCompletionTime = Entity(entityId: .dryerCompletionTime)
    @Published var dryerState = Entity(entityId: .dryerState)
    @Published var easeePower = Entity(entityId: .easeePower)
    @Published var easeeNoCurrentReason = Entity(entityId: .easeeNoCurrentReason)
    @Published var easeeStatus = Entity(entityId: .easeeStatus)
    @Published var generalWasteDate = Entity(entityId: .generalWasteDate)
    @Published var plasticWasteDate = Entity(entityId: .plasticWasteDate)
    @Published var gardenWasteDate = Entity(entityId: .gardenWasteDate)

    @Published var noLocationAccess = false

    var isReloading = false
    let entityIDs: [EntityId] = [
        .hittaSarahsIphone, .coffeeMachine, .storageLock, .coffeeMachineStartTime, .coffeeMachineStartTimeEnabled,
        .pulsePower, .tibberPrice, .pulseConsumptionToday, .washerCompletionTime,
        .solarProductionToday, .dryerCompletionTime, .washerState, .dryerState, .easeePower, .easeeNoCurrentReason,
        .easeeStatus, .generalWasteDate, .plasticWasteDate, .gardenWasteDate, .allLights
    ]

    var isEaseeCharging: Bool {
        easeeStatus.state.lowercased() == "charging"
    }

    var isEaseeAwaitingSchedule: Bool {
        easeeNoCurrentReason.state.lowercased() == "pending_schedule" || easeeStatus.state.lowercased() == "awaiting_start"
    }

    var chargingIcon: Image {
        isEaseeAwaitingSchedule ? .init(systemImageName: .evChargerSlash) : .init(systemImageName: .evCharger)
    }

    private var restAPIService: RestAPIService
    private let locationManager = CLLocationManager()
    let yaleApiService: YaleApiService
    var urlCreator: URLCreator
    let showHeatersAction: MainActorVoidClosure
    let showLynkAction: MainActorVoidClosure
    let showRoborockAction: MainActorVoidClosure
    let showPowerGridAction: MainActorVoidClosure
    let showLightsAction: MainActorVoidClosure
    private(set) var toolbarReloadAction: MainActorAsyncVoidClosure

    init(restAPIService: RestAPIService,
         yaleApiService: YaleApiService,
         urlCreator: URLCreator,
         showHeatersAction: @escaping MainActorVoidClosure,
         showLynkAction: @escaping MainActorVoidClosure,
         showRoborockAction: @escaping MainActorVoidClosure,
         showPowerGridAction: @escaping MainActorVoidClosure,
         showLightsAction: @escaping MainActorVoidClosure,
         toolbarReloadAction: @escaping MainActorAsyncVoidClosure) {
        self.restAPIService = restAPIService
        self.yaleApiService = yaleApiService
        self.urlCreator = urlCreator
        self.showHeatersAction = showHeatersAction
        self.showLynkAction = showLynkAction
        self.showRoborockAction = showRoborockAction
        self.showPowerGridAction = showPowerGridAction
        self.showLightsAction = showLightsAction
        self.toolbarReloadAction = toolbarReloadAction
    }

    func reload() async {
        await withReloadGuard {
            let service = self.restAPIService
            await withTaskGroup(of: (EntityId, Entity)?.self) { group in
                for entityID in self.entityIDs {
                    group.addTask {
                        do {
                            let entity = try await service.reloadState(entityID: entityID)
                            return (entityID, entity)
                        } catch {
                            Log.error("Failed to reload entity: \(entityID): \(error)")
                            return nil
                        }
                    }
                }

                for await result in group {
                    if let (entityID, entity) = result {
                        self.reload(entityID: entityID, state: entity.state, lastChanged: entity.lastChanged)
                    }
                }
            }
        }
    }

    func reloadYaleLocks() async {
        sideDoor.lockState = await reload(lockID: sideDoor.id)
        frontDoor.lockState = await reload(lockID: frontDoor.id)
    }

    func turnOffAllLights() {
        restAPIService.update(lightIDs: [.allLights], action: .turnOff, brightness: 0, reloadTimes: 4)
    }

    func toggleStateForSarahsIphone() {
        let action: Action = sarahsIphone.isActive ? .turnOff : .turnOn
        restAPIService.update(entityID: .hittaSarahsIphone, domain: .script, action: action, reloadTimes: 7)
    }

    func toggleCoffeeMachine() {
        let action: Action = coffeeMachine.isActive ? .turnOff : .turnOn
        restAPIService.update(entityID: .coffeeMachine, domain: .switchDomain, action: action, reloadTimes: 2)
    }

    func toggleEaseeCharging() {
        restAPIService.callScript(scriptID: .easeeToggle, reloadTimes: 2)
    }

    func showCoffeeMachineScheduling() {
        Task { @MainActor in
            if !coffeeMachineStartTimeEnabled.isActive {
                toggleCoffeeMachineStarTimeEnabled()
            }

            shouldShowCoffeeMachineScheduling = true
        }
    }

    func updateDateTimeEntity(entity: Entity) {
        restAPIService.update(dateEntityID: entity.entityId, date: entity.date)
    }

    func toggleCoffeeMachineStarTimeEnabled() {
        let action: Action = coffeeMachineStartTimeEnabled.isActive ? .turnOff : .turnOn
        restAPIService.update(entityID: .coffeeMachineStartTimeEnabled, domain: .inputBoolean, action: action, reloadTimes: 2)
    }

    func toggleStateForStorageLock() {
        let action: Action = storageLock.lockState == .unlocked ? .lock : .unlock
        storageLock.expectedState = action == .lock ? .locked : .unlocked
        restAPIService.update(entityID: .storageLock, domain: .lock, action: action, reloadTimes: 6)
    }

    func lockStorage() {
        storageLock.expectedState = .locked
        restAPIService.update(entityID: .storageLock, domain: .lock, action: .lock, reloadTimes: 6)
    }

    func unlockStorage() {
        storageLock.expectedState = .unlocked
        restAPIService.update(entityID: .storageLock, domain: .lock, action: .unlock, reloadTimes: 6)
    }

    func resetExpectedLockStates() {
        storageLock.expectedState = .unknown
        frontDoor.expectedState = .unknown
        sideDoor.expectedState = .unknown
    }

    func checkLocationAccess() {
        Task { @MainActor in
            noLocationAccess = locationManager.authorizationStatus != .authorizedAlways
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

    private lazy var entityKeyPaths: [EntityId: ReferenceWritableKeyPath<HomeViewModel, Entity>] = [
        .hittaSarahsIphone: \.sarahsIphone,
        .coffeeMachineStartTime: \.coffeeMachineStartTime,
        .coffeeMachineStartTimeEnabled: \.coffeeMachineStartTimeEnabled,
        .pulsePower: \.pulsePower,
        .tibberPrice: \.tibberPrice,
        .pulseConsumptionToday: \.pulseConsumptionToday,
        .solarProductionToday: \.solarProductionToday,
        .washerCompletionTime: \.washerCompletionTime,
        .washerState: \.washerState,
        .dryerCompletionTime: \.dryerCompletionTime,
        .dryerState: \.dryerState,
        .easeePower: \.easeePower,
        .easeeNoCurrentReason: \.easeeNoCurrentReason,
        .easeeStatus: \.easeeStatus,
        .generalWasteDate: \.generalWasteDate,
        .plasticWasteDate: \.plasticWasteDate,
        .gardenWasteDate: \.gardenWasteDate
    ]

    func reload(entityID: EntityId, state: String, lastChanged: Date? = nil) {
        if let keyPath = entityKeyPaths[entityID] {
            self[keyPath: keyPath].state = state
        } else if entityID == .allLights {
            allLights.state = state
        } else if entityID == .coffeeMachine {
            coffeeMachine.state = state
            if let lastChanged {
                coffeeMachine.lastChanged = lastChanged
            }
        } else if entityID == .storageLock {
            storageLock.state = state
        } else {
            Log.error("HomeViewModel doesn't reload entityID: \(entityID)")
        }
    }

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

    private func reload(lockID: LockID) async -> LockState {
        do {
            return try await yaleApiService.getLockState(lockID: lockID)
        } catch {
            Log.error("Failed to load \(lockID) with error: \(error)")
            return .unknown
        }
    }
}
