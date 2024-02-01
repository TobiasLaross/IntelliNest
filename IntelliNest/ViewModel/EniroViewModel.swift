//
//  EniroViewModel.swift
//  IntelliNest
//
//  Created by Tobias on 2022-08-24.
//

import Foundation
import ShipBookSDK
import SwiftUI

@MainActor
class EniroViewModel: ObservableObject {
    @Published var doorLock = LockEntity(entityId: .eniroDoorLock)
    @Published var climateTemperature = InputNumberEntity(entityId: .eniroClimateTemperature)
    @Published var climateHeating = Entity(entityId: .eniroClimateHeating)
    @Published var climateDefrost = Entity(entityId: .eniroClimateDefrost)
    @Published var forceCharging = Entity(entityId: .eniroForceCharge)
    @Published var eniroChargingACLimit = InputNumberEntity(entityId: .eniroACChargingLimit)
    @Published var eniroChargingDCLimit = InputNumberEntity(entityId: .eniroDCChargingLimit)
    @Published var batteryLevel = Entity(entityId: .eniroBatteryLevel)
    @Published var isCharging = Entity(entityId: .eniroIsCharging)
    @Published var eniroBackWindowHeater = Entity(entityId: .eniroBackWindowHeater)
    @Published var eniroAirConditioner = Entity(entityId: .eniroAirConditioner)
    @Published var eniroDefroster = Entity(entityId: .eniroDefroster)
    @Published var eniroEngine = Entity(entityId: .eniroEngine)
    @Published var eniroLastUpdate = Entity(entityId: .eniroLastUpdate)
    @Published var eniroGeoLocation = EniroGeoEntity(entityId: .eniroGeoLocation)
    @Published var climateControlScript = Entity(entityId: .eniroClimateControl)

    let entityIDs: [EntityId] = [.eniroDoorLock, .eniroClimateTemperature, .eniroClimateHeating, .eniroClimateDefrost, .eniroForceCharge,
                                 .eniroACChargingLimit, .eniroDCChargingLimit, .eniroBatteryLevel, .eniroIsCharging, .eniroBackWindowHeater,
                                 .eniroAirConditioner, .eniroDefroster, .eniroEngine, .eniroLastUpdate, .eniroGeoLocation,
                                 .eniroClimateControl]
    @Published var lastUpdateInitialDate: Date = .distantPast.addingTimeInterval(3600)
    @Published var updateIsloading = false
    @Published var limitPickerEntity: InputNumberEntity?
    var isReloading = false
    var recentlyUpdated: Bool {
        -eniroLastUpdate.date.timeIntervalSinceNow < 15 * 60
    }

    var isAirConditionActive: Bool {
        (eniroAirConditioner.isActive && recentlyUpdated && eniroAirConditioner.recentlyUpdated()) || climateControlScript.isActive
    }

    var lastUpdated: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM HH:mm"
        return formatter.string(from: eniroLastUpdate.date)
    }

    var climateIconColor: Color {
        isAirConditionActive ? .yellow : .white
    }

    var restAPIService: RestAPIService
    let showClimateSchedulingAction: MainActorVoidClosure

    init(restAPIService: RestAPIService, showClimateSchedulingAction: @escaping MainActorVoidClosure) {
        self.restAPIService = restAPIService
        self.showClimateSchedulingAction = showClimateSchedulingAction
    }

    // swiftlint:disable cyclomatic_complexity
    func reload(entityID: EntityId, state: String) {
        switch entityID {
        case .eniroDoorLock:
            doorLock.state = state
        case .eniroClimateTemperature:
            climateTemperature.state = state
        case .eniroClimateHeating:
            climateHeating.state = state
        case .eniroClimateDefrost:
            climateDefrost.state = state
        case .eniroForceCharge:
            forceCharging.state = state
        case .eniroACChargingLimit:
            eniroChargingACLimit.state = state
        case .eniroDCChargingLimit:
            eniroChargingDCLimit.state = state
        case .eniroBatteryLevel:
            batteryLevel.state = state
        case .eniroIsCharging:
            isCharging.state = state
        case .eniroBackWindowHeater:
            eniroBackWindowHeater.state = state
        case .eniroAirConditioner:
            eniroAirConditioner.state = state
        case .eniroDefroster:
            eniroDefroster.state = state
        case .eniroEngine:
            eniroEngine.state = state
        case .eniroLastUpdate:
            eniroLastUpdate.state = state
        case .eniroGeoLocation:
            eniroGeoLocation.state = state
        case .eniroClimateControl:
            climateControlScript.state = state
        default:
            Log.error("EniroViewModel doesn't reload entityID: \(entityID)")
        }
    }

    func reloadGeoEntity(geoEntity: EniroGeoEntity) {
        eniroGeoLocation = geoEntity
    }

    func toggleForceCharging() {
        let action: Action = forceCharging.isActive ? .turnOff : .turnOn
        restAPIService.update(entityID: forceCharging.entityId, domain: .inputBoolean, action: action)
    }

    func toggleClimate() {
        if isAirConditionActive {
            stopClimate()
        } else {
            startClimate()
        }
    }

    func toggleState(for entity: Entity) {
        let action: Action = entity.isActive ? .turnOff : .turnOn
        restAPIService.update(entityID: entity.entityId, domain: .inputBoolean, action: action)
    }

    private func startClimate() {
        restAPIService.callScript(scriptID: .eniroStartClimate)
    }

    private func stopClimate() {
        restAPIService.callScript(scriptID: .eniroTurnOffStartClimate)
    }

    func numberSelectedCallback(_: EntityId, temperature: Double) {
        restAPIService.update(numberEntityID: .eniroClimateTemperature, number: temperature)
    }

    func update() {
        restAPIService.callService(serviceID: .kiaUpdate, domain: .kiaUvo, json: [.deviceID: DeviceID.eniro.rawValue])
    }

    func initiateForceUpdate() {
        lastUpdateInitialDate = eniroLastUpdate.date
        restAPIService.callService(serviceID: .kiaForceUpdate, domain: .kiaUvo, json: [.deviceID: DeviceID.eniro.rawValue])
    }

    func startCharging() {
        restAPIService.callService(serviceID: .kiaStartCharge, domain: .kiaUvo, json: [.deviceID: DeviceID.eniro.rawValue])
        updateAfterShortDelay()
    }

    func stopCharging() {
        restAPIService.callService(serviceID: .kiaStopCharge, domain: .kiaUvo, json: [.deviceID: DeviceID.eniro.rawValue])
        updateAfterShortDelay()
    }

    func unlock() {
        doorLock.expectedState = .unlocked
        restAPIService.callService(serviceID: .kiaUnlock, domain: .kiaUvo, json: [.deviceID: DeviceID.eniro.rawValue])
        updateAfterShortDelay()
    }

    func lock() {
        doorLock.expectedState = .locked
        restAPIService.callService(serviceID: .kiaLock, domain: .kiaUvo, json: [.deviceID: DeviceID.eniro.rawValue])
        updateAfterShortDelay()
    }

    func getAddress() -> String {
        eniroGeoLocation.address
    }

    func showACLimitPicker() {
        showLimitPicker(limitEntity: eniroChargingACLimit)
    }

    func showDCLimitPicker() {
        showLimitPicker(limitEntity: eniroChargingDCLimit)
    }

    func saveChargerLimit(entityID: EntityId, newLimit: Double) {
        if limitPickerEntity?.inputNumber != newLimit {
            var json: [JSONKey: Any] = [.deviceID: DeviceID.eniro.rawValue]
            json[.acLimit] = entityID == .eniroACChargingLimit ? newLimit : eniroChargingACLimit.inputNumber
            json[.dcLimit] = entityID == .eniroDCChargingLimit ? newLimit : eniroChargingDCLimit.inputNumber
            restAPIService.callService(serviceID: .kiaChargeLimit, domain: .kiaUvo, json: json)
            updateAfterShortDelay()
        }

        limitPickerEntity = nil
    }

    private func showLimitPicker(limitEntity: InputNumberEntity) {
        limitPickerEntity = limitEntity
    }

    private func updateAfterShortDelay() {
        Task {
            try await Task.sleep(seconds: 0.8)
            update()
        }
    }
}
