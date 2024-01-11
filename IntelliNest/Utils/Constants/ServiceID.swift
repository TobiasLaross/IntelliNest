//
//  ServiceID.swift
//  IntelliNest
//
//  Created by Tobias on 2023-11-17.
//

import Foundation

enum ServiceID: String, Decodable, CaseIterable {
    case kiaForceUpdate = "kia_uvo.force_update"
    case kiaUpdate = "kia_uvo.update"
    case kiaLock = "kia_uvo.lock"
    case kiaUnlock = "kia_uvo.unlock"
    case kiaStartCharge = "kia_uvo.start_charge"
    case kiaStopCharge = "kia_uvo.stop_charge"
    case kiaChargeLimit = "kia_uvo.set_charge_limits"
    case kiaStopClimate = "kia_uvo.stop_climate"
    case cameraStream = "camera/stream"
    case boolTurnOn = "input_boolean.turn_on"
    case boolTurnOff = "input_boolean.turn_off"
    case updateEntity = "homeassistant.update_entity"
    case heaterTemperature = "climate.set_temperature"
    case heaterHvacMode = "climate.set_hvac_mode"
    case heaterFanMode = "climate.set_fan_mode"
    case heaterHorizontal = "melcloud.set_vane_horizontal"
    case heaterVertical = "melcloud.set_vane_vertical"
    case setDateTime = "input_datetime.set_datetime"
}
