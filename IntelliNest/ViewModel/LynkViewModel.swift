//
//  LynkViewModel.swift
//  IntelliNest
//
//  Created by Tobias on 2022-08-24.
//

import Foundation
import ShipBookSDK
import SwiftUI

@MainActor
class LynkViewModel: ObservableObject {
    @Published var forceCharging = Entity(entityId: .eniroForceCharge)
    @Published var climateHeating = Entity(entityId: .lynkClimateHeating)
    @Published var easeeIsEnabled = Entity(entityId: .easeeIsEnabled)
    @Published var lynkDoorLock = LockEntity(entityId: .lynkDoorLock)
    @Published var limitPickerEntity: InputNumberEntity?

    var lynkUpdateTask: Task<Void, Error>?
    let entityIDs: [EntityId] = [.eniroForceCharge, .lynkClimateHeating, .lynkDoorLock, .easeeIsEnabled]
    var isReloading = false
    var airConditionInitiatedTime: Date?
    var isEaseeCharging: Bool {
        easeeIsEnabled.isActive
    }

    var isViewActive = false {
        didSet {
            if isViewActive {
                updateLynkContinously()
            }
        }
    }

    var climateTitle: String {
        isAirConditionActive || isAirConditionLoading ? "Stäng av" : "Starta"
    }

    var isAirConditionActive: Bool {
        climateHeating.isActive
    }

    var isLynkUnlocked: Bool {
        lynkDoorLock.lockState == .unlocked
    }

    var isAirConditionLoading: Bool {
        !isAirConditionActive && (airConditionInitiatedTime?.addingTimeInterval(5 * 60) ?? Date.distantPast) > Date()
    }

    var doorLockTitle: String {
        isLynkUnlocked ? "Lås dörrarna" : "Lås upp dörrarna"
    }

    var doorLockIcon: Image {
        isLynkUnlocked ? .init(systemImageName: .unlocked) : .init(systemImageName: .locked)
    }

    var chargingTitle: String {
        isEaseeCharging ? "Pausa Easee" : "Starta Easee"
    }

    var chargingIcon: Image {
        isEaseeCharging ? .init(systemImageName: .xmarkCircle) : .init(systemImageName: .boltCar)
    }

    var lastUpdated: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM HH:mm"
        // return formatter.string(from: "00:00")
        return "00:00"
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

    func reload() async {
        restAPIService.callService(serviceID: .lynkReload, domain: .lynkco)
    }

    func reload(entityID: EntityId, state: String, lastChanged: Date? = nil) {
        switch entityID {
        case .eniroForceCharge:
            forceCharging.state = state
        case .lynkClimateHeating:
            climateHeating.state = state
        case .lynkDoorLock:
            lynkDoorLock.state = state
        case .easeeIsEnabled:
            easeeIsEnabled.state = state
        default:
            Log.error("EniroViewModel doesn't reload entityID: \(entityID)")
        }
    }

    func toggleClimate() {
        if isAirConditionActive {
            stopClimate()
        } else {
            startClimate()
        }
    }

    func toggleEaseeCharging() {
        restAPIService.callScript(scriptID: .easeeToggle)
    }

    func toggleDoorLock() {
        if isLynkUnlocked {
            lockDoors()
        } else {
            unlockDoors()
        }
    }

    func lockDoors() {
        restAPIService.callService(serviceID: .lynkLockDoors, domain: .lynkco)
    }

    func unlockDoors() {
        restAPIService.callService(serviceID: .lynkUnlockDoors, domain: .lynkco)
    }

    func toggleState(for entity: Entity) {
        let action: Action = entity.isActive ? .turnOff : .turnOn
        restAPIService.update(entityID: entity.entityId, domain: .inputBoolean, action: action)
    }
}

private extension LynkViewModel {
    func startClimate() {
        airConditionInitiatedTime = Date()
        restAPIService.callScript(scriptID: .lynkStartClimate)
    }

    func stopClimate() {
        airConditionInitiatedTime = nil
        restAPIService.callScript(scriptID: .lynkStopClimate)
    }

    func updateLynkContinously() {
        lynkUpdateTask?.cancel()
        lynkUpdateTask = Task {
            while isViewActive {
                try? await Task.sleep(seconds: 5)
                await reload()
            }
        }
    }
}
