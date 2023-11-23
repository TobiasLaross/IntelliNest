//
//  HomeViewModel.swift
//  IntelliNest
//
//  Created by Tobias on 2022-08-20.
//

import Foundation
import ShipBookSDK
import SwiftUI
import UIKit

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
    @Published var solarPower = Entity(entityId: .solarPower)
    @Published var pulsePower = Entity(entityId: .pulsePower)
    @Published var tibberPrice = Entity(entityId: .tibberPrice)
    @Published var pulseConsumptionToday = Entity(entityId: .pulseConsumptionToday)
    @Published var washerCompletionTime = Entity(entityId: .washerCompletionTime)
    @Published var washerState = Entity(entityId: .washerState)
    @Published var dryerCompletionTime = Entity(entityId: .dryerCompletionTime)
    @Published var dryerState = Entity(entityId: .dryerState)
    @Published var easeeCharger = Entity(entityId: .easeeCharger)

    @Published var shouldShowNordpoolPrices = false

    var isReloading = false
    let entityIDs: [EntityId] = [.hittaSarahsIphone, .coffeeMachine, .storageLock, .coffeeMachineStartTime, .coffeeMachineStartTimeEnabled,
                                 .solarPower, .pulsePower, .tibberPrice, .pulseConsumptionToday, .washerCompletionTime,
                                 .dryerCompletionTime, .washerState, .dryerState, .easeeCharger]

    private var websocketService: WebSocketService
    let yaleApiService: YaleApiService
    var urlCreator: URLCreator
    private(set) var toolbarReloadAction: MainActorAsyncVoidClosure
    let appearedAction: DestinationClosure

    init(websocketService: WebSocketService,
         yaleApiService: YaleApiService,
         urlCreator: URLCreator,
         toolbarReloadAction: @escaping MainActorAsyncVoidClosure,
         appearedAction: @escaping DestinationClosure) {
        self.websocketService = websocketService
        self.yaleApiService = yaleApiService
        self.urlCreator = urlCreator
        self.toolbarReloadAction = toolbarReloadAction
        self.appearedAction = appearedAction
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

    func toggleStateForSarahsIphone() {
        let action: Action = sarahsIphone.isActive ? .turnOff : .turnOn
        websocketService.updateEntity(entityID: .hittaSarahsIphone, domain: .script, action: action)
    }

    func showNordPoolPrices() {
        shouldShowNordpoolPrices = true
    }

    func toggleCoffeeMachine() {
        let action: Action = coffeeMachine.isActive ? .turnOff : .turnOn
        websocketService.updateEntity(entityID: .coffeeMachine, domain: .switchDomain, action: action)
    }

    func showCoffeeMachineScheduling() {
        if !coffeeMachineStartTimeEnabled.isActive {
            let calendar = Calendar.current
            let now = Date()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "HH:mm:ss"
            if let newDate = calendar.date(byAdding: .minute, value: 15, to: now) {
                let formattedDate = dateFormatter.string(from: newDate)
                coffeeMachineStartTime.state = formattedDate
                updateDateTimeEntity(entity: coffeeMachineStartTime)
            }

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
        case .solarPower:
            solarPower.state = state
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
        default:
            Log.error("HomeViewModel doesn't reload entityID: \(entityID)")
        }
    }

    func reloadNordPoolEntity(nordPoolEntity: NordPoolEntity) {
        nordPool = nordPoolEntity
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

    private func reload(lockID: LockID) async -> LockState {
        do {
            return try await yaleApiService.getLockState(lockID: lockID)
        } catch {
            Log.error("Failed to load \(lockID) with error: \(error)")
            return .unknown
        }
    }
}
