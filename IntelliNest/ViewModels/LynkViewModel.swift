import Foundation
import ShipBookSDK
import SwiftUI

@MainActor
class LynkViewModel: ObservableObject, Reloadable {
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

    @Published var engineInitiatedTime: Date?
    @Published var isShowingHeaterOptions = false

    let entityIDs: [EntityId] = [
        .lynkClimateHeating, .lynkEngineRunning, .lynkTemperatureInterior,
        .lynkTemperatureExterior, .lynkBattery, .lynkBatteryDistance, .lynkFuel, .lynkFuelDistance,
        .lynkDoorLock, .lynkAddress, .lynkCarUpdatedAt, .lynkChargeState,
        .lynkChargerConnectionStatus, .lynkTimeUntilCharged, .lynkClimateUpdatedAt, .lynkDoorLockUpdatedAt,
        .lynkBatteryUpdatedAt, .lynkFuelUpdatedAt, .lynkAddressUpdatedAt,
        .lynkChargerUpdatedAt
    ]
    var isReloading = false
    var isLynkFlashing = false

    private let restAPIService: RestAPIService

    init(restAPIService: RestAPIService) {
        self.restAPIService = restAPIService
    }

    func forceUpdateLynk() {
        restAPIService.callService(serviceID: .lynkReload, domain: .lynkco)
        UserDefaults.shared.setValue(Date.now, forKey: StorageKeys.lynkReloadTime.rawValue)
    }

    func reload() async {
        await withReloadGuard {
            var shouldSleep = false
            let lastReloadTime = UserDefaults.shared.value(forKey: StorageKeys.lynkReloadTime.rawValue) as? Date
            if (lastReloadTime?.addingTimeInterval(60 * 60) ?? Date.distantPast) < Date.now {
                self.forceUpdateLynk()
                await self.reloadEntities()
                shouldSleep = true
            }

            if shouldSleep {
                try? await Task.sleep(seconds: 5)
            }
            await self.reloadEntities()
        }
    }

    private func reloadEntities() async {
        let service = restAPIService
        await withTaskGroup(of: (EntityId, Entity)?.self) { group in
            for entityID in entityIDs {
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

    private lazy var entityKeyPaths: [EntityId: ReferenceWritableKeyPath<LynkViewModel, Entity>] = [
        .lynkClimateHeating: \.lynkClimateHeating,
        .lynkEngineRunning: \.isEngineRunning,
        .lynkTemperatureInterior: \.lynkInteriorTemperature,
        .lynkTemperatureExterior: \.lynkExteriorTemperature,
        .lynkBatteryDistance: \.lynkBatteryDistance,
        .lynkFuelDistance: \.fuelDistance,
        .lynkAddress: \.address,
        .lynkChargeState: \.lynkChargerState,
        .lynkChargerConnectionStatus: \.lynkChargerConnectionStatus,
        .lynkTimeUntilCharged: \.lynkTimeUntilCharged,
        .lynkCarUpdatedAt: \.lynkCarUpdatedAt,
        .lynkClimateUpdatedAt: \.lynkClimateUpdatedAt,
        .lynkDoorLockUpdatedAt: \.doorLockUpdatedAt,
        .lynkBatteryUpdatedAt: \.batteryUpdatedAt,
        .lynkFuelUpdatedAt: \.fuelUpdatedAt,
        .lynkAddressUpdatedAt: \.addressUpdatedAt,
        .lynkChargerUpdatedAt: \.chargerUpdatedAt
    ]

    private lazy var lastChangedKeyPaths: [EntityId: ReferenceWritableKeyPath<LynkViewModel, Entity>] = [
        .lynkClimateHeating: \.lynkClimateHeating,
        .lynkEngineRunning: \.isEngineRunning,
        .lynkTemperatureInterior: \.lynkInteriorTemperature,
        .lynkTemperatureExterior: \.lynkExteriorTemperature
    ]

    func reload(entityID: EntityId, state: String, lastChanged: Date? = nil) {
        if let keyPath = entityKeyPaths[entityID] {
            self[keyPath: keyPath].state = state
            if let lastChanged, let lastChangedKeyPath = lastChangedKeyPaths[entityID] {
                self[keyPath: lastChangedKeyPath].lastChanged = lastChanged
            }
        } else if entityID == .lynkDoorLock {
            lynkDoorLock.state = state
        } else if entityID == .lynkBattery {
            lynkBattery.state = state
        } else if entityID == .lynkFuel {
            fuel.state = state
        } else {
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

}
