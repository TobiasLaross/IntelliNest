//
//  LightServiceData.swift
//  IntelliNest
//
//  Created by Tobias on 2023-07-10.
//

import Foundation
import ShipBookSDK

class ServiceData: Encodable {}

class LightServiceData: ServiceData {
    let brightness: Int
    init(brightness: Int) {
        self.brightness = brightness
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(brightness, forKey: .brightness)
    }

    private enum CodingKeys: String, CodingKey {
        case brightness
    }
}

class InputNumberServiceData: ServiceData {
    let value: Double

    init(value: Double) {
        self.value = value
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
    }

    private enum CodingKeys: String, CodingKey {
        case value
    }
}

class ClimateServiceData: ServiceData {
    let targetTemperature: Double?
    let hvacMode: HvacMode?
    let fanMode: HeaterFanMode?
    let swingMode: String?

    init(targetTemperature: Double? = nil,
         hvacMode: HvacMode? = nil,
         fanMode: HeaterFanMode? = nil,
         swingMode: String? = nil) {
        self.targetTemperature = targetTemperature
        self.hvacMode = hvacMode
        self.fanMode = fanMode
        self.swingMode = swingMode
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(targetTemperature, forKey: .targetTemperature)
        try container.encodeIfPresent(hvacMode?.rawValue, forKey: .hvacMode)
        try container.encodeIfPresent(fanMode?.rawValue, forKey: .fanMode)
        try container.encodeIfPresent(swingMode, forKey: .swingMode)
    }

    private enum CodingKeys: String, CodingKey {
        case targetTemperature = "target_temperature"
        case hvacMode = "hvac_mode"
        case fanMode = "fan_mode"
        case swingMode = "swing_mode"
    }
}

class MelcloudServiceData: ServiceData {
    let horizontalMode: HeaterHorizontalMode?
    let verticalMode: HeaterVerticalMode?

    init(horizontalMode: HeaterHorizontalMode? = nil, verticalMode: HeaterVerticalMode? = nil) {
        self.horizontalMode = horizontalMode
        self.verticalMode = verticalMode

        if horizontalMode != nil && verticalMode != nil {
            Log.error("Both horizontalMode and verticalMode can't be set in the same MelcloudServiceData")
        }
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(horizontalMode, forKey: .position)
        try container.encodeIfPresent(verticalMode, forKey: .position)
    }

    private enum CodingKeys: String, CodingKey {
        case position
    }
}

class DateTimeServiceData: ServiceData {
    let date: String?
    let time: String?

    init(date: Date) {
        let dateFormatter = DateFormatter()

        dateFormatter.dateFormat = "yyyy-MM-dd"
        self.date = dateFormatter.string(from: date)

        dateFormatter.dateFormat = "HH:mm:ss"
        self.time = dateFormatter.string(from: date)
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        if let date {
            try container.encode(date, forKey: .date)
        }

        if let time {
            try container.encode(time, forKey: .time)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case date
        case time
    }
}

class ScriptServiceData: ServiceData {
    var variables: [ScriptVariableKeys: String]

    init(variables: [ScriptVariableKeys: String]) {
        self.variables = variables
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        for (key, value) in variables {
            if let codingKey = CodingKeys(rawValue: key.rawValue) {
                try container.encode(value, forKey: codingKey)
            } else {
                Log.error("ScriptServiceData failed to encode key: \(key.rawValue) with value: \(value)")
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case entityID = "entity_id"
    }
}

class EmptyServiceData: ServiceData {}
