//
//  JSONKey.swift
//  IntelliNest
//
//  Created by Tobias on 2023-05-18.
//

import Foundation

enum JSONKey: String, Equatable, Codable, Hashable {
    case invalid
    case data
    case entityID = "entity_id"
    case deviceID = "device_id"
    case brightness = "brightness"
    case dateTime = "datetime"
    case time = "time"
    case inputNumberValue = "value"
    case temperature
    case hvacMode = "hvac_mode"
    case fanMode = "fan_mode"
    case position
    case duration
    case climate
    case defrost
    case heating
    case flseat
    case frseat
    case filename
    case variables
    case acLimit = "ac_limit"
    case dcLimit = "dc_limit"
    case operationMode
    case yaleAccessTokenFull = "yale_access_token_full"
    case watt
}
