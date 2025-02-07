//
//  ServiceData.swift
//  IntelliNest
//
//  Created by Tobias on 2023-07-10.
//

import Foundation
import ShipBookSDK

class ServiceData: Encodable {}

@MainActor
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

@MainActor
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

@MainActor
class DateTimeServiceData: ServiceData {
    let date: String?
    let time: String?

    init(date: Date) {
        let dateFormatter = DateFormatter()

        dateFormatter.dateFormat = "yyyy-MM-dd"
        self.date = dateFormatter.string(from: date)

        dateFormatter.dateFormat = "HH:mm:ss"
        time = dateFormatter.string(from: date)
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

    override func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        for (key, value) in variables {
            if let codingKey = CodingKeys(rawValue: key.rawValue) {
                try container.encode(value, forKey: codingKey)
            } else {
                //       Log.error("ScriptServiceData failed to encode key: \(key.rawValue) with value: \(value)")
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case entityID = "entity_id"
    }
}

class EmptyServiceData: ServiceData {}
