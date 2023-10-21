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

class HomeViewModel: HassAPIViewModelProtocol {
    @Published var sideDoor = YaleLock(id: .sideDoor)
    @Published var frontDoor = YaleLock(id: .frontDoor)
    @Published var storageLock = LockEntity(entityId: .storageLock)
    @Published var allLights = LightEntity(entityId: .allLights)
    @Published var coffeeMachine = SwitchEntity(entityId: .coffeeMachine)
    @Published var sarahsIphone = Entity(entityId: .hittaSarahsIphone)
    @Published var shouldShowCoffeeMachineScheduling = false
    @Published var coffeeMachineStartTime = Entity(entityId: .coffeeMachineStartTime)
    @Published var coffeeMachineStartTimeEnabled = Entity(entityId: .coffeeMachineStartTimeEnabled)

    var isReloading = false
    let entityIDs: [EntityId] = [.hittaSarahsIphone, .coffeeMachine, .storageLock, .coffeeMachineStartTime, .coffeeMachineStartTimeEnabled]

    var sarahIphoneimage: Image {
        if sarahsIphone.isActive {
            return Image(systemImageName: .iPhoneActive)
        } else {
            return Image(systemImageName: .iPhone)
        }
    }

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

    func lock(lockEntity: inout LockEntity) {
        let action: Action = .lock
        storageLock.expectedState = .locked
        websocketService.updateEntity(entityID: .storageLock, domain: .lock, action: action)
    }

    func unlock(lockEntity: inout LockEntity) {
        let action: Action = .unlock
        storageLock.expectedState = .unlocked
        websocketService.updateEntity(entityID: .storageLock, domain: .lock, action: action)
    }

    func reload(entityID: EntityId, state: String) {
        switch entityID {
        case .allLights:
            allLights.state = state
        case .hittaSarahsIphone:
            sarahsIphone.state = state
        case .coffeeMachine:
            coffeeMachine.state = state
        case .storageLock:
            storageLock.state = state
        case .coffeeMachineStartTime:
            coffeeMachineStartTime.state = state
        case .coffeeMachineStartTimeEnabled:
            coffeeMachineStartTimeEnabled.state = state
        default:
            Log.error("HomeViewModel doesn't reload entityID: \(entityID)")
        }
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
