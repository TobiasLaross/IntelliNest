//
//  SonnenStatusEntity.swift
//  IntelliNest
//
//  Created by Tobias on 2023-12-20.
//

import Foundation

enum SonnenOperationModes: String, CaseIterable, Decodable {
    case manual = "1"
    case selfConsumption = "2"
    case timeOfUse = "10"
    case unknown

    var title: String {
        switch self {
        case .manual:
            "Manual"
        case .selfConsumption:
            "Self consumption"
        case .timeOfUse:
            "Time of use"
        case .unknown:
            "Unknown"
        }
    }
}

struct SonnenStatusEntity: EntityProtocol {
    let entityId: EntityId
    var gridPower: Double = 0.0
    var operationMode = SonnenOperationModes.unknown
    var hasFlowGridToBattery = false
    var hasFlowGridToHouse = false
    var hasFlowSolarToHouse = false
    var hasFlowBatteryToHouse = false
    var hasFlowSolarToBattery = false
    var hasFlowSolarToGrid = false
    var state: String
    var nextUpdate = Date.now
    var isActive = false

    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case state
        case attributes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        entityId = try EntityId(rawValue: container.decode(String.self, forKey: .entityId)) ?? .unknown
        state = try container.decode(String.self, forKey: .state)

        let attributes = try container.decode(SonnenStatusAttributes.self, forKey: .attributes)
        gridPower = attributes.gridPower
        operationMode = attributes.operationMode
        hasFlowGridToBattery = attributes.hasFlowGridToBattery
        hasFlowGridToHouse = attributes.hasFlowGridToHouse
        hasFlowSolarToHouse = attributes.hasFlowSolarToHouse
        hasFlowBatteryToHouse = attributes.hasFlowBatteryToHouse
        hasFlowSolarToBattery = attributes.hasFlowSolarToBattery
        hasFlowSolarToGrid = attributes.hasFlowSolarToGrid
    }
}

struct SonnenStatusAttributes: Decodable {
    let gridPower: Double
    let operationMode: SonnenOperationModes
    let hasFlowGridToBattery: Bool
    let hasFlowGridToHouse: Bool
    let hasFlowSolarToHouse: Bool
    let hasFlowBatteryToHouse: Bool
    let hasFlowSolarToBattery: Bool
    let hasFlowSolarToGrid: Bool

    enum CodingKeys: String, CodingKey {
        case gridPower = "GridFeedIn_W"
        case operationMode = "OperatingMode"
        case hasFlowGridToBattery = "FlowGridBattery"
        case hasFlowGridToHouse = "FlowConsumptionGrid"
        case hasFlowSolarToHouse = "FlowConsumptionProduction"
        case hasFlowBatteryToHouse = "FlowConsumptionBattery"
        case hasFlowSolarToBattery = "FlowProductionBattery"
        case hasFlowSolarToGrid = "FlowProductionGrid"
    }
}
