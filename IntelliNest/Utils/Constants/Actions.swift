//
//  Actions.swift
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
    case stopClimate = "stop_climate"
    case kiaLimitCharger = "set_charge_limits"
    case lock
    case unlock
    case turnOn = "turn_on"
    case turnOff = "turn_off"
    case locate
    case register
    case snapshot
    case stop
    case start
    case lynkReload = "force_update_data"
    case lockDoors = "lock_doors"
    case unlockDoors = "unlock_doors"
    case startFlashLights = "start_flash_lights"
    case stopFlashLights = "stop_flash_lights"
    case setDateTime = "set_datetime"
    case setValue = "set_value"
    case setVaneHorizontal = "set_vane_horizontal"
    case setVaneVertical = "set_vane_vertical"
    case setFanMode = "set_fan_mode"
    case setPresetMode = "set_preset_mode"
    case startEngine = "start_engine"
    case stopEngine = "stop_engine"
    case setTemperature = "set_temperature"
    case setPercentage = "set_percentage"
    case setHvacMode = "set_hvac_mode"
    case updateEntity = "update_entity"
}
