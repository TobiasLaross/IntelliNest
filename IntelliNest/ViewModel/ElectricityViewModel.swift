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
    @Published var tibberPrice = Entity(entityId: .tibberPrice)
    @Published var pulseConsumptionToday = Entity(entityId: .pulseConsumptionToday)

    var sonnenUpdateTask: Task<Void, Error>?
    var isViewActive = false {
        didSet {
            if isViewActive {
                updateSonnenContinously()
            }
        }
    }

    let entityIDs: [EntityId] = [.sonnenBattery, .pulsePower, .tibberPrice, .pulseConsumptionToday]

    var websocketService: WebSocketService
    let appearedAction: DestinationClosure

    init(sonnenBattery: SonnenEntity,
         websocketService: WebSocketService,
         appearedAction: @escaping DestinationClosure) {
        self.sonnenBattery = sonnenBattery
        self.websocketService = websocketService
        self.appearedAction = appearedAction
    }

    func reload(entityID: EntityId, state: String) {
        switch entityID {
        case .pulsePower:
            pulsePower.state = state
            if let power = Double(state) {
                sonnenBattery.update(gridPower: power)
            }
        case .tibberPrice:
            tibberPrice.state = state
        case .pulseConsumptionToday:
            pulseConsumptionToday.state = state
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
        let variableValueEntities: VariableValue = .stringArray(entityIDs)
        sonnenUpdateTask = Task {
            while isViewActive {
                websocketService.callService(serviceID: .updateEntity, variables: [.entityID: variableValueEntities])
                try? await Task.sleep(seconds: 1)
            }
        }
    }
}
