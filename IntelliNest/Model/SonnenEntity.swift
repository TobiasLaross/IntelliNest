import Foundation

struct SonnenEntity: EntityProtocol {
    let entityId: EntityId
    var state = ""
    var houseConsumption = 0.0 // Consumption_W
    var chargedPercent = 0 // USOC
    var fullChargeCapacity = 0.0 // FullChargeCapacity
    var batteryPower = 0.0 // Pac_total_W
    var gridPower = 0.0 // GridFeedIn_W replaced by tibber power
    var solarProduction = 0.0 // Production_W
    var operationMode = SonnenOperationModes.unknown
    var hasFlowGridToBattery = false
    var hasFlowGridToHouse = false
    var hasFlowBatteryToHouse = false
    var hasFlowSolarToBattery = false
    var hasFlowSolarToHouse = false
    var hasFlowSolarToGrid = false
    var nextUpdate = Date.now
    var isActive = false

    var hasFlowBatteryToGrid: Bool {
        !hasFlowGridToBattery && batteryPower < -60 && gridPower < -60 && (gridPower < houseConsumption - solarProduction)
    }

    var currentKWH: Double {
        ((Double(chargedPercent) / 100.0) * fullChargeCapacity) / 1000.0
    }

    init(entityID: EntityId) {
        entityId = entityID
    }

    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case state
        case attributes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        entityId = try EntityId(rawValue: container.decode(String.self, forKey: .entityId)) ?? .unknown
        state = try container.decode(String.self, forKey: .state)

        let attributes = try container.decode(SonnenAttributes.self, forKey: .attributes)
        houseConsumption = attributes.houseConsumption
        chargedPercent = attributes.chargedPercent
        fullChargeCapacity = attributes.fullChargeCapacity
        batteryPower = attributes.batteryPower * -1
        gridPower = attributes.gridPower
        solarProduction = attributes.solarProduction
    }

    mutating func update(from sonnenEntity: SonnenEntity) {
        state = sonnenEntity.state
        houseConsumption = sonnenEntity.houseConsumption
        chargedPercent = sonnenEntity.chargedPercent
        fullChargeCapacity = sonnenEntity.fullChargeCapacity
        batteryPower = sonnenEntity.batteryPower
        // gridPower = sonnenEntity.gridPower
        solarProduction = sonnenEntity.solarProduction
    }

    mutating func update(from statusEntity: SonnenStatusEntity) {
        hasFlowGridToBattery = statusEntity.hasFlowGridToBattery && abs(statusEntity.gridPower) >= 100 && batteryPower > 100
        hasFlowGridToHouse = statusEntity.hasFlowGridToHouse && abs(statusEntity.gridPower) >= 100
        hasFlowSolarToHouse = statusEntity.hasFlowSolarToHouse
        hasFlowBatteryToHouse = statusEntity.hasFlowBatteryToHouse
        hasFlowSolarToBattery = statusEntity.hasFlowSolarToBattery
        hasFlowSolarToGrid = statusEntity.hasFlowSolarToGrid
        operationMode = statusEntity.operationMode
        gridPower = statusEntity.gridPower * -1
    }
}

struct SonnenAttributes: Decodable {
    let houseConsumption: Double
    let chargedPercent: Int
    let fullChargeCapacity: Double
    let batteryPower: Double
    let gridPower: Double
    let solarProduction: Double

    enum CodingKeys: String, CodingKey {
        case houseConsumption = "Consumption_W"
        case chargedPercent = "USOC"
        case fullChargeCapacity = "FullChargeCapacity"
        case batteryPower = "Pac_total_W"
        case gridPower = "GridFeedIn_W"
        case solarProduction = "Production_W"
    }
}
