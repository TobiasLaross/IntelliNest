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
    case nordPool = "sensor.nordpool_kwh_se4_sek_0_10_0"
    case sonnenAutomation = "automation.battery_charger"
    case sonnenBattery = "sensor.sonnen_battery"
    case sonnenBatteryStatus = "sensor.sonnen_battery_status"
    case pulsePower = "sensor.pulse_power"
    case tibberPrice = "sensor.electricity_price_hem"
    case tibberCostToday = "sensor.accumulated_cost_hem"
    case pulseConsumptionToday = "sensor.pulse_consumption_today"
    case washerCompletionTime = "sensor.washing_machine_washer_completion_time"
    case washerState = "sensor.washing_machine_washer_job_state"
    case dryerCompletionTime = "sensor.tumble_dryer_dryer_completion_time"
    case dryerState = "sensor.tumble_dryer_dryer_job_state"
    case easeeCharger = "sensor.eh4ngpuj_power"
    case generalWasteDate = "sensor.general_waste_collection_date"
    case plasticWasteDate = "sensor.plastic_waste_collection_date"
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
    case eniroClimateTemperature = "input_number.kia_climate_temperature"
    case eniroClimateHeating = "input_boolean.kia_climate_heating"
    case eniroClimateDefrost = "input_boolean.kia_climate_defrost"
    case eniroDoorLock = "lock.e_niro_door_lock"
    case eniroForceCharge = "input_boolean.manually_charge_car"
    case eniroBatteryLevel = "sensor.e_niro_ev_battery_level"
    case eniroACChargingLimit = "number.e_niro_ac_charging_limit"
    case eniroDCChargingLimit = "number.e_niro_dc_charging_limit"
    case eniroIsCharging = "binary_sensor.e_niro_ev_battery_charge"
    case eniroTherm = "temperature_kia"
    case eniroBackWindowHeater = "binary_sensor.e_niro_back_window_heater"
    case eniroAirConditioner = "binary_sensor.e_niro_air_conditioner"
    case eniroDefroster = "binary_sensor.e_niro_defrost"
    case eniroDoorFrontLeft = "binary_sensor.e_niro_door_front_left"
    case eniroDoorFrontRight = "binary_sensor.e_niro_door_front_right"
    case eniroDoorRearLeft = "binary_sensor.e_niro_door_rear_left"
    case eniroDoorRearRight = "binary_sensor.e_niro_door_rear_right"
    case eniroEngine = "binary_sensor.e_niro_engine"
    case eniroHood = "binary_sensor.e_niro_hood"
    case eniroPluggedIn = "binary_sensor.e_niro_plugged_in"
    case eniroSteeringWheelHeater = "binary_sensor.e_niro_steering_wheel_heater"
    case eniroTrunk = "binary_sensor.e_niro_trunk"
    case eniroLastUpdate = "sensor.e_niro_last_updated_at"
    case eniroGeoLocation = "sensor.e_niro_geocoded_location"
    case eniroRange = "sensor.e_niro_range_by_ev"
    case eniroClimateControl = "script.kia_climate_control"
    case eniroTurnOffClimateControl = "script.turn_off_kia_climate_control"
    /* Eniro climate schedule */
    case eniroClimateSchedule1Bool = "input_boolean.kia_climate"
    case eniroClimateSchedule1 = "input_datetime.kia_climate"
    case eniroClimateSchedule2Bool = "input_boolean.kia_climate2"
    case eniroClimateSchedule2 = "input_datetime.kia_climate2"
    case eniroClimateSchedule3Bool = "input_boolean.kia_climate3"
    case eniroClimateSchedule3 = "input_datetime.kia_climate3"
    case eniroClimateScheduleMorning = "input_datetime.kia_morning"
    case eniroClimateScheduleMorningBool = "input_boolean.kia_morning"
    case eniroClimateScheduleDay = "input_datetime.kia_day"
    case eniroClimateScheduleDayBool = "input_boolean.kia_day"
    /* Thermometers */
    case thermCorridor = "sensor.temperature_korridoren"
    case thermKitchen = "sensor.temperature_koket"
    case thermBedroom = "sensor.temperature_sovrummet"
    case thermGym = "sensor.temperature_gymmet"
    case thermVince = "sensor.temperature_vince_rum"
    case thermCommonarea = "sensor.temperature_vardagsrummet"
    case thermPlayroom = "sensor.temperature_lekrummet"
    case thermGuest = "sensor.temperature_gastrummet"
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
    case roborockAutomation = "automation.dammsug"
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
        if let rawType = self.rawValue.components(separatedBy: ".").first {
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
        return Domain(rawValue: self.rawValue.components(separatedBy: ".").first!) ?? .unknown
    }
}
