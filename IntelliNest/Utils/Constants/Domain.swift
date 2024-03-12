//
//  Domain.swift
//  IntelliNest
//
//  Created by Tobias on 2022-08-23.
//

import Foundation

enum Domain: String, Encodable {
    case apnsToken
    case camera
    case climate
    case melcloud
    case switchDomain = "switch"
    case lock
    case script
    case automation
    case homeassistant
    case restCommand = "rest_command"
    case light
    case lynkco
    case inputBoolean = "input_boolean"
    case inputDateTime = "input_datetime"
    case inputNumber = "input_number"
    case sensor
    case binarySensor = "binary_sensor"
    case kiaUvo = "kia_uvo"
    case vacuum
    case unknown
}
