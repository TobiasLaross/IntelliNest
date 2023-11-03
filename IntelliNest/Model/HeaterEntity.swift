//
//  Heater.swift
//  IntelliNest
//
//  Created by Tobias on 2022-02-12.
//

import Foundation
import ShipBookSDK

struct HeaterEntity: EntityProtocol {
    var entityId: EntityId
    var state: String
    var hvacMode: HvacMode {
        HvacMode(rawValue: state) ?? .off
    }

    var nextUpdate = NSDate().addingTimeInterval(-1)
    var isActive: Bool {
        state.lowercased() == "on"
    }

    var heaterName = ""
    var leftVaneTitle = ""
    var rightVaneTitle = ""

    var currentTemperature: Double = 0
    var currentTemperatureFormatted: NSNumber {
        return NSNumber(value: currentTemperature)
    }

    var targetTemperature: Double = 0
    var fanMode: HeaterFanMode = .auto
    var swingMode: String = ""
    var vaneHorizontal = HeaterHorizontalMode.unknown
    var vaneVertical = HeaterVerticalMode.unknown

    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case state
        case attributes
    }

    init(entityId: EntityId, state: String = "Loading") {
        self.entityId = entityId
        self.state = state
        setTitles()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entityId = try EntityId(rawValue: container.decode(String.self, forKey: .entityId))
        self.entityId = entityId ?? EntityId.unknown
        state = try container.decode(String.self, forKey: .state)
        let attributes = try container.decode(HeaterAttributes.self, forKey: .attributes)
        configureWith(heaterAttributes: attributes)
        setTitles()
    }

    init(entityID: EntityId, state: String, attributes: [String: Any]) {
        self.init(entityId: entityID, state: state)
        configureWith(attributes: attributes)
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

    mutating func setNextUpdateTime() {
        nextUpdate = NSDate().addingTimeInterval(0.5)
    }

    static func == (lhs: HeaterEntity, rhs: HeaterEntity) -> Bool {
        return (lhs.entityId == rhs.entityId &&
            lhs.state == rhs.state)
    }

    private mutating func configureWith(attributes: [String: Any]) {
        do {
            guard let nestedAttributes = attributes["attributes"] as? [String: Any] else {
                Log.error("HeaterEntity failed to find nested attributes.")
                return
            }

            let jsonData = try JSONSerialization.data(withJSONObject: nestedAttributes, options: [])
            let heaterAttributes = try JSONDecoder().decode(HeaterAttributes.self, from: jsonData)
            configureWith(heaterAttributes: heaterAttributes)
        } catch {
            Log.error("HeaterEntity failed to configure attributes: \(error)")
        }
    }

    private mutating func configureWith(heaterAttributes: HeaterAttributes) {
        currentTemperature = heaterAttributes.currentTemperature
        targetTemperature = heaterAttributes.targetTemperature
        fanMode = heaterAttributes.fanMode
        swingMode = heaterAttributes.swingMode
        vaneHorizontal = HeaterHorizontalMode(rawValue: heaterAttributes.vaneHorizontal) ?? .unknown
        vaneVertical = HeaterVerticalMode(rawValue: heaterAttributes.vaneVertical) ?? HeaterVerticalMode.unknown
    }
}

private struct HeaterAttributes: Decodable {
    var currentTemperature: Double
    var targetTemperature: Double
    var fanMode: HeaterFanMode
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
        fanMode = try container.decode(HeaterFanMode.self, forKey: .fanMode)
        swingMode = try container.decode(String.self, forKey: .swingMode)
        vaneHorizontal = try container.decode(String.self, forKey: .vaneHorizontal)
        vaneVertical = try container.decode(String.self, forKey: .vaneVertical)
    }
}
