//
//  SonnenStatusEntity.swift
//  IntelliNest
//
//  Created by Tobias on 2023-12-20.
//

import Foundation

enum SonnenOperationModes: String, CaseIterable {
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

struct SonnenStatusEntity {
    let entityID: EntityId
    var gridPower: Double = 0.0
    var operationMode = SonnenOperationModes.unknown
    var hasFlowGridToBattery = false
    var hasFlowGridToHouse = false
    var hasFlowSolarToHouse = false
    var hasFlowBatteryToHouse = false
    var hasFlowSolarToBattery = false
    var hasFlowSolarToGrid = false

    init(entityID: EntityId, attributes: [String: Any]) {
        self.entityID = entityID
        if let hasFlowGridToBattery = attributes["FlowGridBattery"] as? Bool {
            self.hasFlowGridToBattery = hasFlowGridToBattery
        }
        if let hasFlowGridToHouse = attributes["FlowConsumptionGrid"] as? Bool {
            self.hasFlowGridToHouse = hasFlowGridToHouse
        }
        if let hasFlowSolarToHouse = attributes["FlowConsumptionProduction"] as? Bool {
            self.hasFlowSolarToHouse = hasFlowSolarToHouse
        }
        if let hasFlowBatteryToHouse = attributes["FlowConsumptionBattery"] as? Bool {
            self.hasFlowBatteryToHouse = hasFlowBatteryToHouse
        }
        if let hasFlowSolarToBattery = attributes["FlowProductionBattery"] as? Bool {
            self.hasFlowSolarToBattery = hasFlowSolarToBattery
        }
        if let hasFlowSolarToGrid = attributes["FlowProductionGrid"] as? Bool {
            self.hasFlowSolarToGrid = hasFlowSolarToGrid
        }
        if let gridIn = attributes["GridFeedIn_W"] as? Double {
            gridPower = gridIn
        }
        if let operationMode = attributes["OperatingMode"] as? String {
            self.operationMode = SonnenOperationModes(rawValue: operationMode) ?? .unknown
        }
    }
}
