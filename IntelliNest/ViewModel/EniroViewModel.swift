//
//  EniroViewModel.swift
//  IntelliNest
//
//  Created by Tobias on 2022-08-24.
//

import Foundation
import ShipBookSDK
import SwiftUI

// swiftlint:disable type_body_length
class EniroViewModel: HassAPIViewModelProtocol {
    @Published var doorLock = LockEntity(entityId: EntityId.eniroDoorLock)
    @Published var climateTemperature = InputNumberEntity(entityId: EntityId.eniroClimateTemperature)
    @Published var climateHeating = Entity(entityId: EntityId.eniroClimateHeating)
    @Published var climateDefrost = Entity(entityId: EntityId.eniroClimateDefrost)
    @Published var forceCharging = Entity(entityId: EntityId.eniroForceCharge)
    @Published var eniroChargingACLimit = InputNumberEntity(entityId: EntityId.eniroACChargingLimit)
    @Published var eniroChargingDCLimit = InputNumberEntity(entityId: EntityId.eniroDCChargingLimit)
    @Published var batteryLevel = Entity(entityId: EntityId.eniroBatteryLevel)
    @Published var isCharging = Entity(entityId: EntityId.eniroIsCharging)
    @Published var eniroBackWindowHeater = Entity(entityId: EntityId.eniroBackWindowHeater)
    @Published var eniroAirConditioner = Entity(entityId: EntityId.eniroAirConditioner)
    @Published var eniroDefroster = Entity(entityId: EntityId.eniroDefroster)
    @Published var eniroEngine = Entity(entityId: EntityId.eniroEngine)
    @Published var eniroLastUpdate = Entity(entityId: EntityId.eniroLastUpdate)
    @Published var eniroGeoLocation = EniroGeoEntity(entityId: EntityId.eniroGeoLocation)
    @Published var nordPool = NordPoolEntity(entityId: .nordPool)
    @Published var lastUpdateInitialDate: Date = .distantPast.addingTimeInterval(3600)
    @Published var shouldShowNordpoolPrices = false
    @Published var updateIsloading = false
    @Published var forceUpdateIsLoading = false
    @Published var limitPickerEntity: InputNumberEntity?
    @Published var startedAircondition = false
    var isReloading = false
    var recentlyUpdated: Bool {
        -eniroLastUpdate.date.timeIntervalSinceNow < 15 * 60
    }

    var isAirConditionActive: Bool {
        eniroAirConditioner.isActive && recentlyUpdated && eniroAirConditioner.recentlyUpdated()
    }

    var failedStartingAirCondition: Bool {
        !eniroAirConditioner.isActive &&
            recentlyUpdated &&
            startedAircondition &&
            !forceUpdateIsLoading
    }

    var climateIconColor: Color {
        isAirConditionActive ? .yellow : failedStartingAirCondition ? .red : .white
    }

    var apiService: HassApiService
    let appearedAction: DestinationClosure
    init(apiService: HassApiService, appearedAction: @escaping DestinationClosure) {
        self.apiService = apiService
        self.appearedAction = appearedAction
    }

    func setStateForLock(action: Action) {
        if action == .lock {
            doorLock.expectedState = .locked
        } else if action == .unlock {
            doorLock.expectedState = .unlocked
        } else {
            return
        }

        Task { @MainActor in
            await apiService.setStateFor(lock: doorLock, action: action)
            await reloadLockWithExpectedPendingUpdate(lock: doorLock)
        }
    }

    func toggleForceCharging() {
        toggleState(for: forceCharging)
    }

    func startClimate() {
        Task { @MainActor in
            var data = [JSONKey: Any]()
            data[.duration] = 10
            data[.climate] = true
            data[.temperature] = climateTemperature.inputNumber
            data[.defrost] = climateDefrost.isActive
            data[.heating] = climateHeating.isActive ? "1" : "0"
            data[.flseat] = climateHeating.isActive ? "1" : "0"

            var json = [JSONKey: Any]()
            json[.data] = data
            await apiService.sendPostRequest(json: data,
                                             domain: .kiaUvo,
                                             action: .kiaStartClimate)
            startedAircondition = true
            try await Task.sleep(seconds: 0.2)
            await update(timeout: 40, isMainUpdater: true)
        }
    }

    func lastUpdated() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM HH:mm"
        return formatter.string(from: eniroLastUpdate.date)
    }

    func toggleState<T: EntityProtocol>(for entity: T) {
        Task {
            let toggleAction = entity.isActive ? Action.turnOff : Action.turnOn
            await apiService.setStateFor(entity: entity, domain: .inputBoolean, action: toggleAction)
            await reloadAfterSleep()
        }
    }

    func initialReloadTask() {
        Task {
            await self.reload()
            try await Task.sleep(seconds: 0.5)
            await self.update(timeout: 1, isMainUpdater: false)
        }
    }

    @MainActor
    func reload() async {
        if !isReloading {
            isReloading = true
            async let tmpDoorLock = await reload(entity: doorLock)
            async let tmpClimateTemperature = await reload(entity: climateTemperature)
            async let tmpClimateHeating = await reload(entity: climateHeating)
            async let tmpClimateDefrost = await reload(entity: climateDefrost)
            async let tmpForceCharging = await reload(entity: forceCharging)
            async let tmpBatteryLevel = await reload(entity: batteryLevel)
            async let tmpEniroChargingACLimit = await reload(entity: eniroChargingACLimit)
            async let tmpEniroChargingDCLimit = await reload(entity: eniroChargingDCLimit)
            async let tmpIsCharging = await reload(entity: isCharging)
            async let tmpEniroBackWindowHeater = await reload(entity: eniroBackWindowHeater)
            async let tmpEniroAirConditioner = await reload(entity: eniroAirConditioner)
            async let tmpEniroDefroster = await reload(entity: eniroDefroster)
            async let tmpEniroEngine = await reload(entity: eniroEngine)
            async let tmpEniroLastUpdate = await reload(entity: eniroLastUpdate)
            async let tmpEniroGeoLocation = await reload(entity: eniroGeoLocation)
            async let tmpNordPool = await reload(entity: nordPool)
            doorLock = await tmpDoorLock
            climateTemperature = await tmpClimateTemperature
            climateHeating = await tmpClimateHeating
            climateDefrost = await tmpClimateDefrost
            forceCharging = await tmpForceCharging
            batteryLevel = await tmpBatteryLevel
            eniroChargingACLimit = await tmpEniroChargingACLimit
            eniroChargingDCLimit = await tmpEniroChargingDCLimit
            isCharging = await tmpIsCharging
            eniroBackWindowHeater = await tmpEniroBackWindowHeater
            eniroAirConditioner = await tmpEniroAirConditioner
            eniroDefroster = await tmpEniroDefroster
            eniroEngine = await tmpEniroEngine
            eniroLastUpdate = await tmpEniroLastUpdate
            eniroGeoLocation = await tmpEniroGeoLocation
            nordPool = await tmpNordPool
            isReloading = false
        }
    }

    @MainActor
    private func reloadAfterSleep() async {
        do {
            try await Task.sleep(seconds: 0.15)
        } catch {
            Log.error("Failed to sleep in reloadAfterSleep")
        }
        await reload()
    }

    @MainActor
    private func reloadLockWithExpectedPendingUpdate(lock: LockEntity) async {
        do {
            var counter = 0
            try await Task.sleep(seconds: 0.1)
            while lock.shouldReload() && counter < 40 {
                counter += 1
                let updatedLock = await reloadActive(lock: lock, expectedState: lock.expectedState)

                DispatchQueue.main.async {
                    self.doorLock = updatedLock
                }

                if lock.shouldReload() {
                    try await Task.sleep(seconds: 0.5)
                }
            }
        } catch {
            Log.error("Failed to sleep in reloadLockWithExpectedPendingUpdate")
        }
    }

    private func reloadActive(lock: LockEntity, expectedState: LockState) async -> LockEntity {
        var updatedLock = await reload(entity: lock)
        if lock.isLoading && updatedLock.state != expectedState.rawValue && expectedState != .unknown {
            updatedLock.expectedState = expectedState
        }

        return updatedLock
    }

    private func reload<T: EntityProtocol>(entity: T) async -> T {
        return await apiService.reload(hassEntity: entity, entityType: T.self)
    }

    func numberSelectedCallback(_: EntityId, temperature: Double) {
        Task {
            var json = [JSONKey: Any]()
            json[JSONKey.entityID] = EntityId.eniroClimateTemperature.rawValue
            json[JSONKey.inputNumberValue] = String(temperature)
            await apiService.sendPostRequest(json: json, domain: .inputNumber, action: .setValue)
        }
    }

    func updateTask() {
        Task {
            await self.update(timeout: 5, isMainUpdater: true)
        }
    }

    @MainActor
    func update(timeout: Int, isMainUpdater: Bool) async {
        do {
            updateIsloading = true
            if isMainUpdater {
                lastUpdateInitialDate = eniroLastUpdate.date
            }
            var json = [JSONKey: Any]()
            json[.deviceID] = DeviceID.eniro.rawValue
            await apiService.sendPostRequest(json: json,
                                             domain: Domain.kiaUvo,
                                             action: Action.kiaUpdate)
            let clock = ContinuousClock()
            let result = try await clock.measure {
                var count = 0
                while lastUpdateInitialDate == eniroLastUpdate.date {
                    try await Task.sleep(seconds: 1)
                    await self.reload()
                    count += 1
                    if count > timeout {
                        break
                    } else if count % 3 == 0 {
                        await apiService.sendPostRequest(json: json,
                                                         domain: Domain.kiaUvo,
                                                         action: Action.kiaUpdate)
                    }
                }
            }
            if isMainUpdater && lastUpdateInitialDate != eniroLastUpdate.date {
                Log.info("Fetching update from car took: \(result)")
            } else if isMainUpdater {
                Log.info("Did not get updated data from car")
            }
        } catch {
            Log.error("Error while fetching update from car: \(error)")
        }

        if isMainUpdater {
            lastUpdateInitialDate = .distantPast.addingTimeInterval(3600)
        }
        updateIsloading = false
    }

    func initiateForceUpdate() {
        Task { @MainActor in
            do {
                forceUpdateIsLoading = true
                lastUpdateInitialDate = eniroLastUpdate.date
                var json = [JSONKey: Any]()
                json[.deviceID] = DeviceID.eniro.rawValue
                await apiService.sendPostRequest(json: json,
                                                 domain: Domain.kiaUvo,
                                                 action: Action.kiaForceUpdate)
                let clock = ContinuousClock()
                let result = try await clock.measure {
                    var count = 0
                    try await Task.sleep(seconds: 0.5)
                    while lastUpdateInitialDate == eniroLastUpdate.date {
                        await update(timeout: 5, isMainUpdater: false)
                        count += 1
                        if count > 5 {
                            break
                        }

                        try await Task.sleep(seconds: 1)
                    }
                }

                if lastUpdateInitialDate == eniroLastUpdate.date {
                    Log.info("Did not get updated data from car when force updating")
                } else {
                    Log.info("Force updating car took: \(result)")
                }
            } catch {
                Log.error("Failed to force update car: \(error)")
            }
            lastUpdateInitialDate = .distantPast.addingTimeInterval(3600)
            forceUpdateIsLoading = false
        }
    }

    func startCharging() {
        Task {
            await apiService.sendPostRequest(json: [:], domain: Domain.kiaUvo, action: Action.kiaStartCharge)
        }
    }

    func stopCharging() {
        Task {
            await apiService.sendPostRequest(json: [:], domain: Domain.kiaUvo, action: Action.kiaStopCharge)
        }
    }

    func unlock() {
        Task {
            doorLock.expectedState = .unlocked
            var json = [JSONKey: Any]()
            json[.entityID] = EntityId.eniroDoorLock.rawValue
            await apiService.sendPostRequest(json: json, domain: .kiaUvo, action: .unlock)
        }
    }

    func lock() {
        Task {
            doorLock.expectedState = .locked
            var json = [JSONKey: Any]()
            json[.entityID] = EntityId.eniroDoorLock.rawValue
            await apiService.sendPostRequest(json: json, domain: .kiaUvo, action: .lock)
        }
    }

    func getAddress() -> String {
        return eniroGeoLocation.address
    }

    func showNordPoolPrices() {
        shouldShowNordpoolPrices = true
    }

    func showACLimitPicker() {
        showLimitPicker(limitEntity: eniroChargingACLimit)
    }

    func showDCLimitPicker() {
        showLimitPicker(limitEntity: eniroChargingDCLimit)
    }

    func saveChargerLimit(entityID: EntityId,
                          newLimit: Double) {
        Task { @MainActor in
            if limitPickerEntity?.inputNumber != newLimit {
                var json = [JSONKey: Any]()
                json[.deviceID] = DeviceID.eniro.rawValue
                if entityID == .eniroACChargingLimit {
                    json[.acLimit] = newLimit
                    json[.dcLimit] = eniroChargingDCLimit.inputNumber
                } else if entityID == .eniroDCChargingLimit {
                    json[.dcLimit] = newLimit
                    json[.acLimit] = eniroChargingACLimit.inputNumber
                }

                await apiService.sendPostRequest(json: json,
                                                 domain: .kiaUvo,
                                                 action: .kiaLimitCharger)

                Task { @MainActor in
                    if entityID == .eniroACChargingLimit {
                        eniroChargingACLimit.isLoading = true
                        eniroChargingACLimit = await apiService.reloadUntilUpdated(hassEntity: eniroChargingACLimit,
                                                                                   entityType: InputNumberEntity.self)
                    } else if entityID == .eniroDCChargingLimit {
                        eniroChargingDCLimit.isLoading = true
                        eniroChargingDCLimit = await apiService.reloadUntilUpdated(hassEntity: eniroChargingDCLimit,
                                                                                   entityType: InputNumberEntity.self)
                    }
                }
            }

            limitPickerEntity = nil
        }
    }

    private func showLimitPicker(limitEntity: InputNumberEntity) {
        Task { @MainActor in
            limitPickerEntity = limitEntity
        }
    }
}

// swiftlint:enable type_body_length
