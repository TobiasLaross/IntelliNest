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

class HomeViewModel: HassViewModelProtocol {
    @Published var sideDoor = YaleLock(id: .sideDoor)
    @Published var frontDoor = YaleLock(id: .frontDoor)
    @Published var storageLock = LockEntity(entityId: EntityId.forradet)
    @Published var allLights = LightEntity(entityId: EntityId.allaLampor)
    @Published var coffeeMachine = Entity(entityId: EntityId.kaffemaskinen)
    @Published var sarahsIphone = Entity(entityId: EntityId.hittaSarahsIphone)

    var isReloading = false
    var urlCreator: URLCreator {
        hassApiService.urlCreator
    }

    var sarahIphoneimage: Image {
        if sarahsIphone.isActive {
            return Image(systemImageName: .iPhoneActive)
        } else {
            return Image(systemImageName: .iPhone)
        }
    }

    let hassApiService: HassApiService
    let yaleApiService: YaleApiService
    private(set) var toolbarReloadAction: MainActorAsyncVoidClosure
    let appearedAction: DestinationClosure
    init(hassApiService: HassApiService,
         yaleApiService: YaleApiService,
         toolbarReloadAction: @escaping MainActorAsyncVoidClosure,
         appearedAction: @escaping DestinationClosure) {
        self.hassApiService = hassApiService
        self.yaleApiService = yaleApiService
        self.toolbarReloadAction = toolbarReloadAction
        self.appearedAction = appearedAction
    }

    @MainActor
    func reload() async {
        if !isReloading {
            isReloading = true
            async let tmpSideDoorState = await reload(lockID: sideDoor.id)
            async let tmpFrontDoorState = await reload(lockID: frontDoor.id)
            async let tmpStorageLock = await reload(entity: storageLock)
            async let tmpAllLights = await reload(entity: allLights)
            async let tmpCoffeeMachine = await reload(entity: coffeeMachine)
            async let tmpSarahsIphone = await reload(entity: sarahsIphone)

            (allLights, coffeeMachine, sarahsIphone) = await(tmpAllLights, tmpCoffeeMachine, tmpSarahsIphone)
            sideDoor.lockState = await tmpSideDoorState
            frontDoor.lockState = await tmpFrontDoorState
            storageLock.state = await tmpStorageLock.state
            isReloading = false
        }
    }

    func reloadSarahsIPhoneWhileActive() {
        Task { @MainActor in
            while sarahsIphone.isActive {
                try await Task.sleep(seconds: 0.25)
                sarahsIphone = await self.reload(entity: sarahsIphone)
            }
        }
    }

    func toggle(light: LightEntity) {
        Task { @MainActor in
            var action = Action.turnOn
            if light.isActive {
                action = .turnOff
            }

            await hassApiService.setState(light: light, action: action)
            await hassApiService.setState(light: light, action: action)
            await reloadUntilLightIsUpdated(light: light)
        }
    }

    func toggleStateForSarahsIphone() {
        Task {
            let action: Action = sarahsIphone.isActive ? .turnOff : .turnOn
            await hassApiService.setState(for: sarahsIphone.entityId, in: .script, using: action)
        }
    }

    func toggleCoffeeMachine() {
        Task { @MainActor in
            let action: Action = coffeeMachine.isActive ? .turnOff : .turnOn
            await hassApiService.setState(for: coffeeMachine.entityId, in: .switchDomain, using: action)
            coffeeMachine = await hassApiService.reloadUntilUpdated(hassEntity: coffeeMachine, entityType: Entity.self)
        }
    }

    func turnOnCameraIr() {
        Task {
            await hassApiService.setState(for: .cameraVinceLight, in: .light, using: .turnOn)
        }
    }

    func turnOffCameraIr() {
        Task {
            await hassApiService.setState(for: .cameraVinceLight, in: .light, using: .turnOff)
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
            } else if lockID == .storageDoor {
                storageLock.state = await reload(entity: storageLock).state
                print("storageLock \(storageLock.state) \(storageLock.lockState.rawValue), \(storageLock.expectedState)")
                isLoading = storageLock.isLoading
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
    private func reloadUntilLightIsUpdated(light: LightEntity) async {
        var updatedLight: LightEntity
        var count = 0
        repeat {
            try? await Task.sleep(seconds: 0.1)
            await updatedLight = reload(entity: light)
            if light.state != updatedLight.state || light.brightness == updatedLight.brightness {
                break
            }
            count += 1
        } while count < 10

        await reload()
    }

    private func reload<T: EntityProtocol>(entity: T) async -> T {
        return await hassApiService.reload(hassEntity: entity, entityType: T.self)
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
