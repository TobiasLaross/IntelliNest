import Foundation

@MainActor
class ElectricityViewModel: ObservableObject, Reloadable {
    @Published var nordPool = NordPoolEntity(entityId: .nordPool)
    @Published private var pulsePowerEntity = Entity(entityId: .pulsePower)
    @Published private var pulsePowerProductionEntity = Entity(entityId: .pulsePowerProduction)
    @Published private var solarPowerEntity = Entity(entityId: .solarPower)
    @Published var tibberCostToday = Entity(entityId: .tibberCostToday)
    @Published var pulseConsumptionToday = Entity(entityId: .pulseConsumptionToday)

    let entityIDs: [EntityId] = [
        .pulsePower,
        .pulsePowerProduction,
        .tibberCostToday,
        .pulseConsumptionToday,
        .solarPower,
        .nordPool
    ]
    var isReloading = false
    private let restAPIService: RestAPIService

    // The SolarEdge cloud sensor lags ~13 minutes behind real time (its API is rate-limited),
    // while the Tibber Pulse reports grid flow in near real time. With no home battery the house
    // can never export more than the panels generate, so the live net export is a lower bound on
    // current solar production. When the Pulse reading is newer than the inverter's, trust whichever
    // value is higher — this lifts a stale-low solar reading during a fast morning ramp so the
    // dashboard never shows the house exporting more power than the panels are making.
    var solarPower: Double {
        let inverterSolar = Double(solarPowerEntity.state) ?? 0
        guard pulsePowerProductionEntity.lastUpdated > solarPowerEntity.lastUpdated else {
            return inverterSolar
        }
        return max(inverterSolar, gridExport - gridImport)
    }

    // The Tibber Pulse exposes import and export as two separate, always-non-negative
    // sensors: pulse_power measures grid import, pulse_power_production measures grid
    // export. It never reports a negative value, so the signed net grid power has to be
    // reconstructed from the difference.
    var gridImport: Double {
        Double(pulsePowerEntity.state) ?? 0
    }

    var gridExport: Double {
        Double(pulsePowerProductionEntity.state) ?? 0
    }

    // Positive = importing from grid, negative = exporting to grid
    var gridPower: Double {
        gridImport - gridExport
    }

    // A house only ever consumes power; it never feeds the grid on its own. Clamp at zero so the
    // transient negative values that appear when the laggy solar reading trails a fresh Pulse export
    // never surface as the house "producing" power.
    var housePower: Double {
        max(0, solarPower + gridPower)
    }

    var isSolarToGrid: Bool {
        solarPower.toKW > 0 && gridExport.toKW > 0
    }

    var isSolarToHouse: Bool {
        solarPower.toKW > 0
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
        var entityUpdates: [(EntityId, Entity)] = []
        var newNordPool: NordPoolEntity?

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
                    newNordPool = nordPoolEntity
                } else if let entity {
                    entityUpdates.append((entityID, entity))
                }
            }
        }

        // Apply all updates together after all fetches complete so derived
        // properties like housePower never observe a partial/inconsistent snapshot.
        if let newNordPool {
            nordPool = newNordPool
        }
        for (entityID, entity) in entityUpdates {
            reload(entityID: entityID, entity: entity)
        }
    }

    private lazy var entityKeyPaths: [EntityId: ReferenceWritableKeyPath<ElectricityViewModel, Entity>] = [
        .pulsePower: \.pulsePowerEntity,
        .pulsePowerProduction: \.pulsePowerProductionEntity,
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

    // Replaces the whole entity rather than just its state so the decoded last_updated timestamp
    // flows through — solarPower relies on it to tell a stale inverter reading from a fresh one.
    func reload(entityID: EntityId, entity: Entity) {
        guard let keyPath = entityKeyPaths[entityID] else {
            Log.error("ElectricityViewModel doesn't reload entityID: \(entityID)")
            return
        }
        self[keyPath: keyPath] = entity
    }
}
