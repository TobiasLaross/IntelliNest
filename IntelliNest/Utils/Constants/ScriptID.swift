//
//  ScriptID.swift
//  IntelliNest
//
//  Created by Tobias on 2023-07-11.
//

import Foundation

enum ScriptID: String, Decodable, CaseIterable {
    case saveClimateState = "script.save_climate_state"
    case eniroStartClimate = "script.kia_climate_control"
    case eniroTurnOffStartClimate = "script.turn_off_kia_climate_control"
    case lynkStartClimate = "script.lynk_start_climate"
    case lynkStopClimate = "script.lynk_stop_climate"
    case lynkStartEngine = "script.lynk_start_engine"
    case lynkStopEngine = "script.lynk_stop_engine"
    case easeeToggle = "script.toggle_easee"
}
