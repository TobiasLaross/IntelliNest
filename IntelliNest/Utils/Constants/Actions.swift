//
//  ActionConstants.swift
//  IntelliNest
//
//  Created by Tobias on 2022-08-23.
//

import Foundation

enum Action: String, Codable {
    case kiaUpdate = "update"
    case kiaForceUpdate = "force_update"
    case kiaStopCharge = "stop_charge"
    case kiaStartCharge = "start_charge"
    case kiaStartClimate = "start_climate"
    case kiaLimitCharger = "set_charge_limits"
    case lock
    case unlock
    case turnOn = "turn_on"
    case turnOff = "turn_off"
    case locate
    case snapshot
    case stop
    case start
    case setDateTime = "set_datetime"
    case setVaneHorizontal = "set_vane_horizontal"
    case setVaneVertical = "set_vane_vertical"
    case setValue = "set_value"
}

enum ClimateAction: String, Decodable {
    case setTemperature = "set_temperature"
    case setHvacMode = "set_hvac_mode"
}

enum ClimateScheduleAction: String, Decodable {
    case setDateTime = "set_datetime"
}
