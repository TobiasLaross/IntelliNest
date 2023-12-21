//
//  SonnenEntity.swift
//  IntelliNest
//
//  Created by Tobias on 2023-12-14.
//

import Foundation

struct SonnenEntity {
    let entityID: EntityId
    var state = ""
    var houseConsumption = 0.0 // Consumption_W
    var chargedPercent = 0 // USOC
    var fullChargeCapacity = 0.0 // FullChargeCapacity
    var batteryPower = 0.0 // Pac_total_W
    var gridPower = 0.0 // GridFeedIn_W replaced by tibber power
    var solarProduction = 0.0 // Production_W
    var hasFlowGridToBattery = false
    var hasFlowGridToHouse = false
    var hasFlowBatteryToHouse = false
    var hasFlowSolarToBattery = false
    var hasFlowSolarToHouse = false
    var hasFlowSolarToGrid = false

    var hasFlowBatteryToGrid: Bool {
        !hasFlowGridToBattery && batteryPower < -60 && gridPower < -60 && (gridPower < houseConsumption - solarProduction)
    }

    var currentKWH: Double {
        ((Double(chargedPercent) / 100.0) * fullChargeCapacity) / 1000.0
    }

    init(entityID: EntityId) {
        self.entityID = entityID
    }

    init(entityID: EntityId, state: String, attributes: [String: Any]) {
        self.init(entityID: entityID)
        self.state = state

        if let houseConsumption = attributes["Consumption_W"] as? Double {
            self.houseConsumption = houseConsumption
        }
        if let chargedPercent = attributes["USOC"] as? Int {
            self.chargedPercent = chargedPercent
        }
        if let fullChargeCapacity = attributes["FullChargeCapacity"] as? Double {
            self.fullChargeCapacity = fullChargeCapacity
        }
        if let batteryPower = attributes["Pac_total_W"] as? Double {
            self.batteryPower = batteryPower * -1
        }
        if let gridPower = attributes["GridFeedIn_W"] as? Double {
            self.gridPower = gridPower
        }
        /* Get this from status entity
          if let solarProduction = attributes["Production_W"] as? Double {
             self.solarProduction = solarProduction
         }
          */
    }

    mutating func update(from sonnenEntity: SonnenEntity) {
        state = sonnenEntity.state
        houseConsumption = sonnenEntity.houseConsumption
        chargedPercent = sonnenEntity.chargedPercent
        fullChargeCapacity = sonnenEntity.fullChargeCapacity
        batteryPower = sonnenEntity.batteryPower
//        gridPower = sonnenEntity.gridPower
        solarProduction = sonnenEntity.solarProduction
    }

    mutating func update(from sonnenStatusEntity: SonnenStatusEntity) {
        hasFlowGridToBattery = sonnenStatusEntity.hasFlowGridToBattery
        hasFlowGridToHouse = sonnenStatusEntity.hasFlowGridToHouse
        hasFlowSolarToHouse = sonnenStatusEntity.hasFlowSolarToHouse
        hasFlowBatteryToHouse = sonnenStatusEntity.hasFlowBatteryToHouse
        hasFlowSolarToBattery = sonnenStatusEntity.hasFlowSolarToBattery
        hasFlowSolarToGrid = sonnenStatusEntity.hasFlowSolarToGrid
//        gridPower = sonnenStatusEntity.gridPower
    }

    mutating func update(gridPower: Double) {
        self.gridPower = gridPower
    }
}
