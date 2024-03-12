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
    @Published var lynkDoorLock = LockEntity(entityId: .lynkDoorLock)
    @Published var limitPickerEntity: InputNumberEntity?

    var lynkUpdateTask: Task<Void, Error>?
    let entityIDs: [EntityId] = [.eniroForceCharge, .lynkClimateHeating]
    var isReloading = false
    var isViewActive = false {
        didSet {
            if isViewActive {
                updateLynkContinously()
            }
        }
    }

    var isAirConditionActive: Bool {
        climateHeating.state == "on"
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

    func reload(entityID: EntityId, state: String) {
        switch entityID {
        case .eniroForceCharge:
            forceCharging.state = state
        case .lynkClimateHeating:
            climateHeating.state = state
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

    func update() {}

    func startCharging() {}

    func stopCharging() {}

    func lock() {}

    func unlock() {}

    func toggleState(for entity: Entity) {
        let action: Action = entity.isActive ? .turnOff : .turnOn
        restAPIService.update(entityID: entity.entityId, domain: .inputBoolean, action: action)
    }
}

private extension LynkViewModel {
    func startClimate() {
        restAPIService.callScript(scriptID: .lynkStartClimate)
    }

    func stopClimate() {
        // restAPIService.callScript(scriptID: .eniroTurnOffStartClimate)
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
