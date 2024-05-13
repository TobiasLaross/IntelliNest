//
//  JSONKey.swift
//  IntelliNest
//
//  Created by Tobias on 2023-05-18.
//

import Foundation

enum JSONKey: String, Equatable, Codable, Hashable {
    case invalid
    case appData = "app_data"
    case appID = "app_id"
    case appName = "app_name"
    case appVersion = "app_version"
    case data
    case entityID = "entity_id"
    case deviceID = "device_id"
    case deviceName = "device_name"
    case brightness
    case dateTime = "datetime"
    case manufacturer
    case model
    case osName = "os_name"
    case osVersion = "os_version"
    case time
    case percentage
    case presetMode = "preset_mode"
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
    case supportsEncryption = "supports_encryption"
    case pushToken = "push_token"
    case pushURL = "push_url"
    case operationMode
    case yaleAccessTokenFull = "yale_access_token_full"
    case value
    case watt
}
