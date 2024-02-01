//
//  ElectricityViewModel.swift
//  IntelliNest
//
//  Created by Tobias on 2023-12-14.
//

import Foundation
import ShipBookSDK

@MainActor
class ElectricityViewModel: ObservableObject {
    @Published var sonnenBattery: SonnenEntity
    @Published var nordPool = NordPoolEntity(entityId: .nordPool)
    @Published var pulsePower = Entity(entityId: .pulsePower)
    @Published var tibberCostToday = Entity(entityId: .tibberCostToday)
    @Published var pulseConsumptionToday = Entity(entityId: .pulseConsumptionToday)
    @Published var sonnenAutomationEnabled = Entity(entityId: .sonnenAutomation)
    @Published var isShowingSonnenSettings = false

    var sonnenUpdateTask: Task<Void, Error>?
    var isViewActive = false {
        didSet {
            if isViewActive {
                updateSonnenContinously()
            }
        }
    }

    let entityIDs: [EntityId] = [.sonnenBattery, .pulsePower, .tibberCostToday, .pulseConsumptionToday, .sonnenAutomation]

    var restAPIService: RestAPIService

    init(sonnenBattery: SonnenEntity, restAPIService: RestAPIService) {
        self.sonnenBattery = sonnenBattery
        self.restAPIService = restAPIService
    }

    func reload(entityID: EntityId, state: String) {
        switch entityID {
        case .pulsePower:
            pulsePower.state = state
            if let power = Double(state) {
                sonnenBattery.update(gridPower: power)
            }
        case .tibberCostToday:
            tibberCostToday.state = state
        case .pulseConsumptionToday:
            pulseConsumptionToday.state = state
        case .sonnenAutomation:
            sonnenAutomationEnabled.state = state
        default:
            Log.error("HomeViewModel doesn't reload entityID: \(entityID)")
        }
    }

    func reloadNordPoolEntity(nordPoolEntity: NordPoolEntity) {
        nordPool = nordPoolEntity
    }

    func reloadSonnenBattery(_ sonnenEntity: SonnenEntity) {
        sonnenBattery.update(from: sonnenEntity)
    }

    func reloadSonnenStatusBattery(_ sonnenStatusEntity: SonnenStatusEntity) {
        sonnenBattery.update(from: sonnenStatusEntity)
    }

    func updateSonnenContinously() {
        sonnenUpdateTask?.cancel()
        sonnenUpdateTask = Task {
            while isViewActive {
                restAPIService.callService(serviceID: .updateEntity, domain: .homeassistant,
                                           json: [.entityID: EntityId.sonnenBattery.rawValue])
                restAPIService.callService(serviceID: .updateEntity, domain: .homeassistant,
                                           json: [.entityID: EntityId.sonnenBatteryStatus.rawValue])
                try? await Task.sleep(seconds: 1)
            }
        }
    }

    func charge(watt: Int) {
        guard watt <= 10000 && watt >= 0 else {
            return
        }

        restAPIService.callService(serviceID: .sonnenCharge, domain: .restCommand, json: [.watt: watt])
    }

    func discharge(watt: Int) {
        guard watt <= 10000 && watt >= 0 else {
            return
        }

        restAPIService.callService(serviceID: .sonnenDischarge, domain: .restCommand, json: [.watt: watt])
    }

    func setSonnenOperationMode(_ mode: SonnenOperationModes) {
        guard mode != .unknown else {
            return
        }

        restAPIService.callService(serviceID: .sonnenOperationMode, domain: .restCommand, json: [.operationMode: mode.rawValue])
    }

    func setSonnenAutomationEnabled(_ isEnabled: Bool) {
        let action: Action = isEnabled ? .turnOn : .turnOff
        restAPIService.update(entityID: EntityId.sonnenAutomation, domain: .automation, action: action)
    }
}
