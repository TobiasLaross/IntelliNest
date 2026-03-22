import Foundation
import ShipBookSDK

@MainActor
class ElectricityViewModel: ObservableObject, Reloadable {
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
    var isReloading = false
    private let restAPIService: RestAPIService

    var solarPower: Double {
        Double(solarPowerEntity.state) ?? 0
    }

    var gridPower: Double {
        Double(pulsePowerEntity.state) ?? 0
    }

    var housePower: Double {
        gridPower + solarPower
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
        await withReloadGuard {
            await self.reloadEntities()
        }
    }

    private func reloadEntities() async {
        let service = restAPIService
        await withTaskGroup(of: (EntityId, Entity?, NordPoolEntity?).self) { group in
            for entityID in entityIDs {
                group.addTask {
                    do {
                        if entityID == .nordPool {
                            let nordPool = try await service.reload(entityId: entityID, entityType: NordPoolEntity.self)
                            return (entityID, nil, nordPool)
                        } else {
                            let entity = try await service.reloadState(entityID: entityID)
                            return (entityID, entity, nil)
                        }
                    } catch {
                        Log.error("Failed to reload entity: \(entityID): \(error)")
                        return (entityID, nil, nil)
                    }
                }
            }

            for await (entityID, entity, nordPoolEntity) in group {
                if let nordPoolEntity {
                    self.nordPool = nordPoolEntity
                } else if let entity {
                    self.reload(entityID: entityID, state: entity.state)
                }
            }
        }
    }

    private lazy var entityKeyPaths: [EntityId: ReferenceWritableKeyPath<ElectricityViewModel, Entity>] = [
        .pulsePower: \.pulsePowerEntity,
        .tibberCostToday: \.tibberCostToday,
        .pulseConsumptionToday: \.pulseConsumptionToday,
        .solarPower: \.solarPowerEntity
    ]

    func reload(entityID: EntityId, state: String) {
        guard let keyPath = entityKeyPaths[entityID] else {
            Log.error("ElectricityViewModel doesn't reload entityID: \(entityID)")
            return
        }
        self[keyPath: keyPath].state = state
    }
}
