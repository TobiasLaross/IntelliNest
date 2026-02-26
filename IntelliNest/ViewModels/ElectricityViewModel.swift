import Foundation
import ShipBookSDK

@MainActor
class ElectricityViewModel: ObservableObject {
    @Published var nordPool = NordPoolEntity(entityId: .nordPool)
    @Published private var pulsePowerEntity = Entity(entityId: .pulsePower)
    @Published private var solarPowerEntity = Entity(entityId: .solarPower)
    @Published var tibberCostToday = Entity(entityId: .tibberCostToday)
    @Published var pulseConsumptionToday = Entity(entityId: .pulseConsumptionToday)

    let entityIDs: [EntityId] = [
        .pulsePower,
        .tibberCostToday,
        .pulseConsumptionToday,
        .solarPower,
        .nordPool
    ]
    private var isReloading = false
    private let restAPIService: RestAPIService

    var solarPower: Double {
        Double(solarPowerEntity.state) ?? 0
    }

    var housePower: Double {
        Double(pulsePowerEntity.state) ?? 0
    }

    var gridPower: Double {
        housePower - solarPower
    }

    var isSolarToGrid: Bool {
        solarPower.toKW > 0 && gridPower.toKW < 0
    }

    var isSolarToHouse: Bool {
        solarPower.toKW > 0 && gridPower < housePower
    }

    var isGridToHouse: Bool {
        gridPower.toKW > 0
    }

    init(restAPIService: RestAPIService) {
        self.restAPIService = restAPIService
    }

    func reload() async {
        guard !isReloading else {
            return
        }

        isReloading = true
        for entityID in entityIDs {
            do {
                if entityID == .nordPool {
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
            pulsePowerEntity.state = state
        case .tibberCostToday:
            tibberCostToday.state = state
        case .pulseConsumptionToday:
            pulseConsumptionToday.state = state
        case .solarPower:
            solarPowerEntity.state = state
        default:
            Log.error("ElectricityViewModel doesn't reload entityID: \(entityID)")
        }
    }
}
