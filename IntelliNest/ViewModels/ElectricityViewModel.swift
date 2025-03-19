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

    var gridPower: String {
        let pulsePower = pulsePower.state
        let sonnenPower = Double(sonnenBattery.gridPower)
        if abs(Double(pulsePower) ?? 0) < 0.05 && sonnenPower < 0 {
            return sonnenBattery.gridPower.toKWString
        } else {
            return sonnenPower.toKWString
        }
    }

    let entityIDs: [EntityId] = [
        .sonnenBatteryStatus,
        .sonnenBattery,
        .pulsePower,
        .tibberCostToday,
        .pulseConsumptionToday,
        .sonnenAutomation,
        .nordPool
    ]
    private var isReloading = false
    private let restAPIService: RestAPIService

    init(sonnenBattery: SonnenEntity, restAPIService: RestAPIService) {
        self.sonnenBattery = sonnenBattery
        self.restAPIService = restAPIService
    }

    func reload() async {
        guard !isReloading else {
            return
        }

        isReloading = true
        restAPIService.callService(serviceID: .updateEntity,
                                   domain: .homeassistant,
                                   json: [.entityID: EntityId.sonnenBattery.rawValue],
                                   reloadTimes: 0)
        restAPIService.callService(serviceID: .updateEntity,
                                   domain: .homeassistant,
                                   json: [.entityID: EntityId.sonnenBatteryStatus.rawValue],
                                   reloadTimes: 0)
        try? await Task.sleep(seconds: 0.2)
        for entityID in entityIDs {
            do {
                if entityID == .sonnenBatteryStatus {
                    let sonnenStatus = try await restAPIService.reload(entityId: entityID, entityType: SonnenStatusEntity.self)
                    sonnenBattery.update(from: sonnenStatus)
                } else if entityID == .sonnenBattery {
                    let sonnenBattery = try await restAPIService.reload(entityId: entityID, entityType: SonnenEntity.self)
                    self.sonnenBattery.update(from: sonnenBattery)
                } else if entityID == .nordPool {
                    let nordPool = try await restAPIService.reload(entityId: entityID, entityType: NordPoolEntity.self)
                    self.nordPool = nordPool
                } else {
                    let entity = try await restAPIService.reloadState(entityID: entityID)
                    reload(entityID: entityID, state: entity.state)
                }
            } catch {
                Log.error("Failed to reload entity: \(entityID): \(error)")
            }
        }
        isReloading = false
    }

    func reload(entityID: EntityId, state: String) {
        switch entityID {
        case .pulsePower:
            pulsePower.state = state
        case .tibberCostToday:
            tibberCostToday.state = state
        case .pulseConsumptionToday:
            pulseConsumptionToday.state = state
        case .sonnenAutomation:
            sonnenAutomationEnabled.state = state
        default:
            Log.error("ElectricityViewModel doesn't reload entityID: \(entityID)")
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
