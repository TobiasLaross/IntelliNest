import Foundation
import ShipBookSDK
import SwiftUI

@MainActor
class LynkViewModel: ObservableObject {
    // Lynk
    @Published var lynkClimateHeating = Entity(entityId: .lynkClimateHeating)
    @Published var isEngineRunning = Entity(entityId: .lynkEngineRunning)
    @Published var lynkInteriorTemperature = Entity(entityId: .lynkTemperatureInterior)
    @Published var lynkExteriorTemperature = Entity(entityId: .lynkTemperatureExterior)
    @Published var lynkBattery = InputNumberEntity(entityId: .lynkBattery)
    @Published var lynkBatteryDistance = Entity(entityId: .lynkBatteryDistance)
    @Published var fuel = InputNumberEntity(entityId: .lynkFuel)
    @Published var fuelDistance = Entity(entityId: .lynkFuelDistance)
    @Published var lynkDoorLock = LockEntity(entityId: .lynkDoorLock)
    @Published var address = Entity(entityId: .lynkAddress)
    @Published var lynkChargerState = Entity(entityId: .lynkChargeState)
    @Published var lynkChargerConnectionStatus = Entity(entityId: .lynkChargerConnectionStatus)
    @Published var lynkTimeUntilCharged = Entity(entityId: .lynkTimeUntilCharged)

    @Published var lynkCarUpdatedAt = Entity(entityId: .lynkCarUpdatedAt)
    @Published var lynkClimateUpdatedAt = Entity(entityId: .lynkClimateUpdatedAt)
    @Published var doorLockUpdatedAt = Entity(entityId: .lynkDoorLockUpdatedAt)
    @Published var batteryUpdatedAt = Entity(entityId: .lynkBatteryUpdatedAt)
    @Published var fuelUpdatedAt = Entity(entityId: .lynkFuelUpdatedAt)
    @Published var addressUpdatedAt = Entity(entityId: .lynkAddressUpdatedAt)
    @Published var chargerUpdatedAt = Entity(entityId: .lynkChargerUpdatedAt)
    @Published var lynkAirConditionInitiatedTime: Date?

    // Leaf
    @Published var leafClimateTimer = Entity(entityId: .leafACTimer)
    @Published var leafBattery = InputNumberEntity(entityId: .leafBattery)
    @Published var leafRangeAC = Entity(entityId: .leafRangeAC)
    @Published var isLeafCharging = Entity(entityId: .leafCharging)
    @Published var isLeafPluggedIn = Entity(entityId: .leafPluggedIn)
    @Published var leafLastPoll = Entity(entityId: .leafLastPoll)
    @Published var leafAirConditionInitiatedTime: Date?

    @Published var engineInitiatedTime: Date?
    @Published var isShowingHeaterOptions = false

    let entityIDs: [EntityId] = [
        .lynkClimateHeating, .lynkEngineRunning, .lynkTemperatureInterior,
        .lynkTemperatureExterior, .lynkBattery, .lynkBatteryDistance, .lynkFuel, .lynkFuelDistance,
        .lynkDoorLock, .lynkAddress, .lynkCarUpdatedAt, .lynkChargeState,
        .lynkChargerConnectionStatus, .lynkTimeUntilCharged, .lynkClimateUpdatedAt, .lynkDoorLockUpdatedAt,
        .lynkBatteryUpdatedAt, .lynkFuelUpdatedAt, .lynkAddressUpdatedAt,
        .lynkChargerUpdatedAt, .leafACTimer, .leafBattery, .leafRangeAC, .leafCharging, .leafPluggedIn,
        .leafLastPoll
    ]
    var isReloading = false
    var isLynkFlashing = false

    var restAPIService: RestAPIService
    private let repeatReloadAction: IntClosure
    let showClimateSchedulingAction: MainActorVoidClosure

    init(restAPIService: RestAPIService,
         repeatReloadAction: @escaping IntClosure,
         showClimateSchedulingAction: @escaping MainActorVoidClosure) {
        self.restAPIService = restAPIService
        self.repeatReloadAction = repeatReloadAction
        self.showClimateSchedulingAction = showClimateSchedulingAction
    }

    func forceUpdateLynk() {
        restAPIService.callService(serviceID: .lynkReload, domain: .lynkco)
        UserDefaults.shared.setValue(Date.now, forKey: StorageKeys.lynkReloadTime.rawValue)
    }

    func forceUpdateLeaf() {
        restAPIService.callService(serviceID: .leafUpdate, domain: .leaf)
        UserDefaults.shared.setValue(Date.now, forKey: StorageKeys.leafReloadTime.rawValue)
    }

    func reload() async {
        guard !isReloading else {
            return
        }

        isReloading = true
        var shouldSleep = false
        let lastReloadTime = UserDefaults.shared.value(forKey: StorageKeys.lynkReloadTime.rawValue) as? Date
        if (lastReloadTime?.addingTimeInterval(60 * 60) ?? Date.distantPast) < Date.now {
            forceUpdateLynk()
            await reloadEntities()
            shouldSleep = true
        }

        let lastLeafReloadTime = UserDefaults.shared.value(forKey: StorageKeys.leafReloadTime.rawValue) as? Date
        if (lastLeafReloadTime?.addingTimeInterval(60 * 60) ?? Date.distantPast) < Date.now {
            forceUpdateLeaf()
            await reloadEntities()
            shouldSleep = true
        }

        if shouldSleep {
            try? await Task.sleep(seconds: 5)
        }
        await reloadEntities()
        isReloading = false
    }

    private func reloadEntities() async {
        for entityID in entityIDs {
            do {
                let state = try await restAPIService.reloadState(entityID: entityID)
                reload(entityID: entityID, state: state)
            } catch {
                Log.error("Failed to reload entity: \(entityID): \(error)")
            }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func reload(entityID: EntityId, state: String, lastChanged: Date? = nil) {
        switch entityID {
        case .lynkClimateHeating:
            lynkClimateHeating.state = state
            if let lastChanged {
                lynkClimateHeating.lastChanged = lastChanged
            }
        case .lynkDoorLock:
            lynkDoorLock.state = state
        case .lynkEngineRunning:
            isEngineRunning.state = state
            if let lastChanged {
                isEngineRunning.lastChanged = lastChanged
            }
        case .lynkTemperatureInterior:
            lynkInteriorTemperature.state = state
            if let lastChanged {
                lynkInteriorTemperature.lastChanged = lastChanged
            }
        case .lynkTemperatureExterior:
            lynkExteriorTemperature.state = state
            if let lastChanged {
                lynkExteriorTemperature.lastChanged = lastChanged
            }
        case .lynkBattery:
            lynkBattery.state = state
        case .lynkBatteryDistance:
            lynkBatteryDistance.state = state
        case .lynkFuel:
            fuel.state = state
        case .lynkFuelDistance:
            fuelDistance.state = state
        case .lynkAddress:
            address.state = state
        case .lynkChargeState:
            lynkChargerState.state = state
        case .lynkChargerConnectionStatus:
            lynkChargerConnectionStatus.state = state
        case .lynkTimeUntilCharged:
            lynkTimeUntilCharged.state = state
        case .lynkCarUpdatedAt:
            lynkCarUpdatedAt.state = state
        case .lynkClimateUpdatedAt:
            lynkClimateUpdatedAt.state = state
        case .lynkDoorLockUpdatedAt:
            doorLockUpdatedAt.state = state
        case .lynkBatteryUpdatedAt:
            batteryUpdatedAt.state = state
        case .lynkFuelUpdatedAt:
            fuelUpdatedAt.state = state
        case .lynkAddressUpdatedAt:
            addressUpdatedAt.state = state
        case .lynkChargerUpdatedAt:
            chargerUpdatedAt.state = state
        case .leafACTimer:
            leafClimateTimer.state = state
            if let lastChanged {
                leafClimateTimer.lastChanged = lastChanged
            }
        case .leafBattery:
            leafBattery.state = state
        case .leafRangeAC:
            leafRangeAC.state = state
        case .leafCharging:
            isLeafCharging.state = state
        case .leafPluggedIn:
            isLeafPluggedIn.state = state
        case .leafLastPoll:
            leafLastPoll.state = state
        default:
            Log.error("LynkViewModel doesn't reload entityID: \(entityID)")
        }
    }

    func toggleLynkClimate() {
        if isLynkAirConditionActive {
            stopLynkClimate()
        } else {
            startLynkClimate()
        }
    }

    func toggleDoorLock() {
        if isLynkUnlocked {
            lockDoors()
        } else {
            unlockDoors()
        }
    }

    func lockDoors() {
        lynkDoorLock.expectedState = .locked
        restAPIService.callService(serviceID: .lynkLockDoors, domain: .lynkco)
    }

    func unlockDoors() {
        lynkDoorLock.expectedState = .unlocked
        restAPIService.callService(serviceID: .lynkUnlockDoors, domain: .lynkco)
    }

    func startFlashLights() {
        isLynkFlashing = true
        restAPIService.callService(serviceID: .lynkFlashStart, domain: .lynkco)
    }

    func stopFlashLights() {
        isLynkFlashing = false
        restAPIService.callService(serviceID: .lynkFlashStop, domain: .lynkco)
    }

    func startEngine() {
        engineInitiatedTime = Date()
        restAPIService.callScript(scriptID: .lynkStartEngine)
        isShowingHeaterOptions = false
    }

    func stopEngine() {
        engineInitiatedTime = nil
        restAPIService.callScript(scriptID: .lynkStopEngine)
    }

    func toggleState(for entity: Entity) {
        let action: Action = entity.isActive ? .turnOff : .turnOn
        restAPIService.update(entityID: entity.entityId, domain: .inputBoolean, action: action)
    }

    func startLynkClimate() {
        lynkAirConditionInitiatedTime = Date()
        restAPIService.callScript(scriptID: .lynkStartClimate)
        isShowingHeaterOptions = false
    }

    func stopLynkClimate() {
        lynkAirConditionInitiatedTime = nil
        restAPIService.callScript(scriptID: .lynkStopClimate)
    }

    func toggleLeafClimate() {
        if isLeafAirConditionActive {
            stopLeafClimate()
        } else {
            startLeafClimate()
        }
    }

    func startLeafClimate() {
        leafAirConditionInitiatedTime = Date()
        restAPIService.callService(serviceID: .leafStartClimate, domain: .leaf)
        isShowingHeaterOptions = false
    }

    func stopLeafClimate() {
        leafAirConditionInitiatedTime = nil
        restAPIService.callService(serviceID: .leafStopClimate, domain: .leaf)
    }
}
