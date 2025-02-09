//
//  EntityId.swift
//  IntelliNest
//
//  Created by Tobias on 2022-08-23.
//

import Foundation

enum EntityType: String {
    case image
    case light
    case lock
    case powerSwitch = "switch"
    case script
    case sensor
    case unknown
}

enum EntityId: String, Decodable, CaseIterable {
    case unknown
    case coffeeMachine = "switch.kaffemaskinen"
    case coffeeMachineStartTime = "input_datetime.kaffemaskinen_starta"
    case coffeeMachineStartTimeEnabled = "input_boolean.kaffemaskinen_starta"
    case sidodorren = "lock.sidodorren"
    case framdorren = "lock.framdorren"
    case storageLock = "lock.forradet"
    case hittaSarahsIphone = "script.hitta_sarahs_iphone"
    case sarahTookPill = "input_boolean.sarah_took_pill"
    case snoozeWashingMachine = "input_boolean.washer_snooze"
    case washerCompletionTime = "sensor.washing_machine_washer_completion_time"
    case washerState = "sensor.washing_machine_washer_job_state"
    case dryerCompletionTime = "sensor.tumble_dryer_dryer_completion_time"
    case dryerState = "sensor.tumble_dryer_dryer_job_state"
    case generalWasteDate = "sensor.general_waste_collection_date"
    case plasticWasteDate = "sensor.plastic_waste_collection_date"
    case gardenWasteDate = "sensor.garden_waste_collection_date"
    case homeLocation = "zone.home"
    case tobiasIsAway = "input_boolean.tobias_is_away"
    case sarahIsAway = "input_boolean.sarah_is_away"
    case personTobias = "person.tobias_laross"
    case personSarah = "person.sarah"

    /* Electricity */
    case nordPool = "sensor.nordpool_kwh_se4_sek_0_10_0"
    case sonnenAutomation = "automation.sonnen_battery_charger"
    case sonnenBattery = "sensor.sonnen_battery"
    case sonnenBatteryStatus = "sensor.sonnen_battery_status"
    case pulsePower = "sensor.pulse_power"
    case tibberPrice = "sensor.electricity_price_hem"
    case tibberCostToday = "sensor.accumulated_cost_hem"
    case pulseConsumptionToday = "sensor.pulse_consumption_today"
    case solarProducdtionToday = "sensor.solaredge_energy_today"

    /* Easee */
    case easeePower = "sensor.eh4ngpuj_power"
    case easeeIsEnabled = "switch.eh4ngpuj_is_enabled"
    case easeeNoCurrentReason = "sensor.eh4ngpuj_reason_for_no_current"

    /* Lights */
    case sofa = "light.soffbordet"
    case cozyCorner = "light.myshornan"
    case panel = "light.tradfri_panel"
    case corridorN = "light.korridoren_n"
    case corridorS = "light.korridoren_s"
    case vitrinskapet = "light.vitrinskapet"
    case lightsInPlayroom = "light.lampor_i_lekrummet"
    case playroomCeiling1 = "light.lekrummet_tak1"
    case playroomCeiling2 = "light.lekrummet_tak2"
    case playroomCeiling3 = "light.lekrummet_tak3"
    case lightsInGuestRoom = "light.lampor_i_gastrummet"
    case guestRoomCeiling1 = "light.gastrummet_tak1"
    case guestRoomCeiling2 = "light.gastrummet_tak2"
    case guestRoomCeiling3 = "light.gastrummet_tak3"
    case laundryRoom = "light.tvattstugan"
    case lightsInLivingRoom = "light.lampor_i_vardagsrummet"
    case lightsInCorridor = "light.lampor_i_korridoren"
    case lamporIKoket = "light.lampor_i_koket"
    case allLights = "light.alla_lampor"
    /* Eniro */
    case eniroClimate = "input_boolean.car_heater"
    case eniroForceCharge = "input_boolean.manually_charge_car"
    case eniroClimateControl = "script.kia_climate_control"
    case eniroTurnOffClimateControl = "script.turn_off_kia_climate_control"
    /* Leaf */
    case leafACTimer = "sensor.leaf1sara_ac_timer"
    case leafBattery = "sensor.leaf1sara_battery"
    case leafCharging = "binary_sensor.leaf1sara_charging"
    case leafRange = "sensor.leaf1sara_estimated_range"
    case leafRangeAC = "sensor.leaf1sara_estimated_range_ac"
    case leafLastPoll = "sensor.leaf1sara_last_poll_request"
    case leafPluggedIn = "binary_sensor.leaf1sara_plug_status"
    /* Lynk */
    case lynkClimateHeating = "binary_sensor.lynk_co_pre_climate_active"
    case lynkDoorLock = "lock.lynk_co_locks"
    case lynkEngineRunning = "binary_sensor.lynk_co_vehicle_is_running"
    case lynkTemperatureExterior = "sensor.lynk_co_exterior_temperature"
    case lynkTemperatureInterior = "sensor.lynk_co_interior_temperature"
    case lynkBatteryDistance = "sensor.lynk_co_battery_distance"
    case lynkBattery = "sensor.lynk_co_battery"
    case lynkFuel = "sensor.lynk_co_fuel_level"
    case lynkFuelDistance = "sensor.lynk_co_fuel_distance"
    case lynkAddress = "sensor.lynk_co_address"
    case lynkChargeState = "sensor.lynk_co_charge_state"
    case lynkChargerConnectionStatus = "sensor.lynk_co_charger_connection_status"
    case lynkTimeUntilCharged = "sensor.lynk_co_time_until_charged"
    case lynkCarUpdatedAt = "sensor.lynk_co_last_updated_by_car"
    case lynkClimateUpdatedAt = "sensor.lynk_co_climate_updated"
    case lynkDoorLockUpdatedAt = "sensor.lynk_co_door_lock_updated"
    case lynkBatteryUpdatedAt = "sensor.lynk_co_battery_updated"
    case lynkFuelUpdatedAt = "sensor.lynk_co_fuel_updated"
    case lynkAddressUpdatedAt = "sensor.lynk_co_position_updated"
    case lynkChargerUpdatedAt = "sensor.lynk_co_charger_updated"
    /* Thermometers */
    case thermCorridor = "sensor.temperature_korridoren"
    case thermKitchen = "sensor.temperature_koket"
    case thermBedroom = "sensor.temperature_sovrummet"
    case thermGym = "sensor.temperature_gymmet"
    case thermVince = "sensor.temperature_vince_rum"
    case thermCommonarea = "sensor.temperature_vardagsrummet"
    case thermPlayroom = "sensor.temperature_lekrummet"
    case thermGuest = "sensor.temperature_gastrummet"
    /* Pure */
    case purifierFanSpeed = "fan.wellbeing_pure_fanspeed"
    case purifierMode = "sensor.wellbeing_pure_workmode"
    case purifierTemperature = "sensor.wellbeing_pure_temp"
    case purifierHumidity = "sensor.wellbeing_pure_humidity"
    case purifierTimerMode = "input_boolean.purifier_timer_mode"
    case resetPurifierTime = "input_datetime.reset_purifier_heater_time"
    case purifierSavedSpeed = "input_number.purifier_saved_speed"
    /* Heaters */
    case heaterCorridor = "climate.varmepump"
    case heaterPlayroom = "climate.mellanrummet"
    case heaterCorridorTimerMode = "input_boolean.heater_corridor_timer_mode"
    case heaterPlayroomTimerMode = "input_boolean.heater_playroom_timer_mode"
    case resetCorridorHeaterTime = "input_datetime.reset_corridor_heater_time"
    case resetPlayroomHeaterTime = "input_datetime.reset_playroom_heater_time"
    case saveClimateState = "script.save_climate_state"
    /* Roborock */
    case roborock = "vacuum.bob"
    case roborockAutomation = "automation.vacuum"
    case roborockLastCleanArea = "sensor.bob_last_clean_area"
    case roborockAreaSinceEmptied = "input_number.bob_clean_area_since_trash_emptied"
    case roborockEmptiedAtDate = "input_datetime.bob_trash_last_emptied"
    case roborockWaterShortage = "binary_sensor.bob_water_shortage"
    case roborockMapImage = "image.bob_houseplan"
    /* Cameras */
    case cameraVince = "camera.vince_rtsp"
    case cameraFront = "camera.framsidan_frigate"
    case cameraCarport = "camera.carporten_frigate"
    case cameraBack = "camera.baksidan_frigate"

    /* Yale Access token */
    case yaleAccessTokenPart1 = "input_text.yale_access_token_part1"
    case yaleAccessTokenPart2 = "input_text.yale_access_token_part2"
    case yaleAccessTokenPart3 = "input_text.yale_access_token_part3"
    case yaleAccessTokenPart4 = "input_text.yale_access_token_part4"
    case yaleAccessTokenPart5 = "input_text.yale_access_token_part5"

    var type: EntityType {
        if let rawType = rawValue.components(separatedBy: ".").first {
            switch rawType.lowercased() {
            case "light":
                return .light
            case "image":
                return .image
            default:
                break
            }
        }
        return .unknown
    }

    func domain() -> Domain {
        Domain(rawValue: rawValue.components(separatedBy: ".").first!) ?? .unknown
    }
}
