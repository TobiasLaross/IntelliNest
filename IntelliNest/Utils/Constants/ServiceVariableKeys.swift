//
//  ServiceVariableKeys.swift
//  IntelliNest
//
//  Created by Tobias on 2023-11-17.
//

import Foundation

enum ServiceVariableKeys: String, Equatable, Codable, Hashable, CodingKey {
    case service
    case entityID = "entity_id"
    case deviceID = "device_id"
    case dcLimit = "dc_limit"
    case acLimit = "ac_limit"
}
