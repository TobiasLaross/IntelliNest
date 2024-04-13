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

    var gridPower: String {
        let pulsePower = pulsePower.state
        let sonnenPower = -1 * Double(sonnenBattery.gridPower)
        if abs(Double(pulsePower) ?? 0) < 0.05 && sonnenPower < 0 {
            return sonnenBattery.gridPower.toKW
        } else {
            return sonnenPower.toKW
        }
    }

    let entityIDs: [EntityId] = [.sonnenBattery, .pulsePower, .tibberCostToday, .pulseConsumptionToday, .sonnenAutomation]

    var restAPIService: RestAPIService
    var websocketService: WebSocketService

    init(sonnenBattery: SonnenEntity, restAPIService: RestAPIService, websocketService: WebSocketService) {
        self.sonnenBattery = sonnenBattery
        self.restAPIService = restAPIService
        self.websocketService = websocketService
    }

    func reload(entityID: EntityId, state: String) {
        switch entityID {
        case .pulsePower:
            pulsePower.state = state
        /* if let power = Double(state) {
             sonnenBattery.update(gridPower: power)
         }
          */
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
        let entityIDs = [EntityId.sonnenBattery.rawValue, EntityId.sonnenBatteryStatus.rawValue]
        let variableValueEntities: ServiceValues = .stringArray(entityIDs)
        sonnenUpdateTask = Task {
            while isViewActive {
                websocketService.callService(serviceID: .updateEntity, data: [.entityID: variableValueEntities])
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
