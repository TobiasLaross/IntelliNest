//
//  Heater.swift
//  IntelliNest
//
//  Created by Tobias on 2022-02-12.
//

import Foundation

struct HeaterEntity: EntityProtocol {
    var entityId: EntityId
    var state: String
    var nextUpdate = NSDate().addingTimeInterval(-1)
    var isActive: Bool = false
    var heaterName = ""
    var leftVaneTitle = ""
    var rightVaneTitle = ""

    var currentTemperature: Double = 0
    var currentTemperatureFormatted: NSNumber {
        return NSNumber(value: currentTemperature)
    }

    var targetTemperature: Double = 0
    var fanMode: FanMode = .auto
    var swingMode: String = ""
    var vaneHorizontal = HorizontalMode.unknown
    var vaneVertical = HeaterVerticalPosition.unknown

    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case state
        case attributes
    }

    init(entityId: EntityId, state: String = "Loading") {
        self.entityId = entityId
        self.state = state
        if entityId == .heaterCorridor {
            heaterName = "Korridoren"
            leftVaneTitle = "Vardagsrummet"
            rightVaneTitle = "Sovrummet"
        } else { // .heaterPlayroom
            heaterName = "Lekrummet"
            leftVaneTitle = "Gästrummet"
            rightVaneTitle = "Förrådet"
        }
        setTitles()
        updateIsActive()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entityId = try EntityId(rawValue: container.decode(String.self, forKey: .entityId))
        self.entityId = entityId ?? EntityId.unknown
        state = try container.decode(String.self, forKey: .state)
        let attributes = try container.decode(HeaterAttributes.self, forKey: .attributes)
        currentTemperature = attributes.currentTemperature
        targetTemperature = attributes.targetTemperature
        fanMode = attributes.fanMode
        swingMode = attributes.swingMode
        vaneHorizontal = HorizontalMode(rawValue: attributes.vaneHorizontal) ?? .unknown
        vaneVertical = HeaterVerticalPosition(rawValue: attributes.vaneVertical) ?? HeaterVerticalPosition.unknown
        setTitles()
        updateIsActive()
    }

    mutating func setTitles() {
        if entityId == .heaterCorridor {
            heaterName = "Korridoren"
            leftVaneTitle = "Vardagsrummet"
            rightVaneTitle = "Sovrummet"
        } else { // .heaterPlayroom
            heaterName = "Lekrummet"
            leftVaneTitle = "Gästrummet"
            rightVaneTitle = "Förrådet"
        }
    }

    mutating func updateIsActive() {
        if state.lowercased() == "on" {
            isActive = true
        } else {
            isActive = false
        }
    }

    mutating func setNextUpdateTime() {
        nextUpdate = NSDate().addingTimeInterval(0.5)
    }

    static func == (lhs: HeaterEntity, rhs: HeaterEntity) -> Bool {
        return (lhs.entityId == rhs.entityId &&
            lhs.state == rhs.state)
    }
}

private struct HeaterAttributes: Decodable {
    var currentTemperature: Double
    var targetTemperature: Double
    var fanMode: FanMode
    var swingMode: String
    var vaneHorizontal: String
    var vaneVertical: String

    enum CodingKeys: String, CodingKey {
        case currentTemperature = "current_temperature"
        case targetTemperature = "temperature"
        case fanMode = "fan_mode"
        case swingMode = "swing_mode"
        case vaneHorizontal = "vane_horizontal"
        case vaneVertical = "vane_vertical"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentTemperature = try container.decode(Double.self, forKey: .currentTemperature)
        targetTemperature = try container.decode(Double.self, forKey: .targetTemperature)
        fanMode = try container.decode(FanMode.self, forKey: .fanMode)
        swingMode = try container.decode(String.self, forKey: .swingMode)
        vaneHorizontal = try container.decode(String.self, forKey: .vaneHorizontal)
        vaneVertical = try container.decode(String.self, forKey: .vaneVertical)
    }
}
