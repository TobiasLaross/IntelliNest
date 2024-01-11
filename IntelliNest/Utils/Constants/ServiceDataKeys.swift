//
//  ServiceVariableKeys.swift
//  IntelliNest
//
//  Created by Tobias on 2023-11-17.
//

import Foundation

enum ServiceDataKeys: String, Equatable, Codable, Hashable, CodingKey {
    case service
    case entityID = "entity_id"
    case deviceID = "device_id"
    case dcLimit = "dc_limit"
    case acLimit = "ac_limit"
    case temperature
    case hvacMode = "hvac_mode"
    case fanMode = "fan_mode"
    case position = "position"
    case date
    case time
    case datetime
}
