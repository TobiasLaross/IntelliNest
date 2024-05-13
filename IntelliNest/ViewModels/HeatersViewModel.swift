//
//  HeatersViewModel.swift
//  IntelliNest
//
//  Created by Tobias on 2022-09-24.
//

import Foundation
import ShipBookSDK

@MainActor
class HeatersViewModel: HassAPIViewModelProtocol {
    @Published var heaterCorridor = HeaterEntity(entityId: .heaterCorridor)
    @Published var heaterPlayroom = HeaterEntity(entityId: .heaterPlayroom)
    @Published var purifier = PurifierEntity()
    @Published var thermCorridor = Entity(entityId: .thermCorridor)
    @Published var resetCorridorHeaterTime = Entity(entityId: .resetCorridorHeaterTime)
    @Published var resetPlayroomHeaterTime = Entity(entityId: .resetPlayroomHeaterTime)
    @Published var resetPurifierTime = Entity(entityId: .resetPurifierTime)
    @Published var thermBedroom = Entity(entityId: .thermBedroom)
    @Published var thermGym = Entity(entityId: .thermGym)
    @Published var thermVince = Entity(entityId: .thermVince)
    @Published var thermKitchen = Entity(entityId: .thermKitchen)
    @Published var thermCommonarea = Entity(entityId: .thermCommonarea)
    @Published var thermPlayroom = Entity(entityId: .thermPlayroom)
    @Published var thermGuest = Entity(entityId: .thermGuest)
    @Published var heaterCorridorTimerMode = Entity(entityId: .heaterCorridorTimerMode)
    @Published var heaterPlayroomTimerMode = Entity(entityId: .heaterPlayroomTimerMode)
    @Published var purifierTimerMode = Entity(entityId: .purifierTimerMode)

    let entityIDs: [EntityId] = [.resetCorridorHeaterTime, .resetPlayroomHeaterTime, .heaterCorridorTimerMode, .heaterPlayroomTimerMode,
                                 .purifierTimerMode, .purifierFanSpeed, .purifierHumidity, .purifierTemperature, .purifierMode,
                                 .resetPurifierTime]

    let restAPIService: RestAPIService
    let showHeaterDetails: MainActorEntityIDClosure
    init(restAPIService: RestAPIService, showHeaterDetails: @escaping MainActorEntityIDClosure) {
        self.restAPIService = restAPIService
        self.showHeaterDetails = showHeaterDetails
    }

    func setTargetTemperature(entityId: EntityId, temperature: Double) {
        restAPIService.update(entityID: entityId,
                              domain: .climate,
                              action: .setTemperature,
                              dataKey: .temperature,
                              dataValue: "\(temperature)")
    }

    func setPurifierFanSpeed(_ speed: Double) {
        restAPIService.update(entityID: .purifierFanSpeed,
                              domain: .fan,
                              action: .setPercentage,
                              dataKey: .percentage,
                              dataValue: speed.toFanSpeedPercentage)
    }

    func setHvacMode(heater: HeaterEntity, hvacMode: HvacMode) {
        restAPIService.update(entityID: heater.entityId,
                              domain: .climate,
                              action: .setHvacMode,
                              dataKey: .hvacMode,
                              dataValue: hvacMode.rawValue)
    }

    func setFanMode(_ heater: HeaterEntity, _ fanMode: HeaterFanMode) {
        if fanMode != heater.fanMode {
            restAPIService.update(entityID: heater.entityId,
                                  domain: .climate,
                                  action: .setFanMode,
                                  dataKey: .fanMode,
                                  dataValue: fanMode.rawValue)
        }
    }

    func horizontalModeSelectedCallback(_ heater: HeaterEntity, _ horizontalMode: HeaterHorizontalMode) {
        restAPIService.update(entityID: heater.entityId,
                              domain: .melcloud,
                              action: .setVaneHorizontal,
                              dataKey: .position,
                              dataValue: horizontalMode.rawValue)
    }

    func verticalModeSelectedCallback(_ heater: HeaterEntity, _ verticalMode: HeaterVerticalMode) {
        restAPIService.update(entityID: heater.entityId,
                              domain: .melcloud,
                              action: .setVaneVertical,
                              dataKey: .position,
                              dataValue: verticalMode.rawValue)
    }

    func setClimateSchedule(dateEntity: Entity) {
        restAPIService.update(dateEntityID: dateEntity.entityId, date: dateEntity.date)
    }

    func toggleCorridorTimerMode() {
        let action: Action = heaterCorridorTimerMode.isActive ? .turnOff : .turnOn
        toggleHeaterTimerMode(heaterEntityID: heaterCorridor.entityId,
                              heaterTimerModeEntityID: heaterCorridorTimerMode.entityId,
                              dateEntity: resetCorridorHeaterTime,
                              action: action)
    }

    func togglePlayroomTimerMode() {
        let action: Action = heaterPlayroomTimerMode.isActive ? .turnOff : .turnOn
        toggleHeaterTimerMode(heaterEntityID: heaterPlayroom.entityId,
                              heaterTimerModeEntityID: heaterPlayroomTimerMode.entityId,
                              dateEntity: resetPlayroomHeaterTime,
                              action: action)
    }

    func togglePurifierTimerMode() {
        let action: Action = purifierTimerMode.isActive ? .turnOff : .turnOn
        toggleHeaterTimerMode(heaterEntityID: .purifierFanSpeed,
                              heaterTimerModeEntityID: purifierTimerMode.entityId,
                              dateEntity: resetPurifierTime,
                              action: action)
    }

    func reload(entityID: EntityId, state: String) {
        switch entityID {
        case .resetCorridorHeaterTime:
            resetCorridorHeaterTime.state = state
        case .resetPlayroomHeaterTime:
            resetPlayroomHeaterTime.state = state
        case .heaterCorridorTimerMode:
            heaterCorridorTimerMode.state = state
        case .heaterPlayroomTimerMode:
            heaterPlayroomTimerMode.state = state
        case .purifierMode:
            purifier.fanMode = PurifierFanMode(rawValue: state) ?? .off
        case .purifierFanSpeed:
            print("speed raw: \(state)")
            purifier.speed = Double(state)?.toFanSpeedTargetNumber ?? 0
            print("speed target: \(purifier.speed)")
        case .purifierTemperature:
            purifier.temperature = Double(state) ?? 0
        case .purifierHumidity:
            purifier.humidity = Int(state) ?? 0
        case .resetPurifierTime:
            resetPurifierTime.state = state
        case .purifierTimerMode:
            purifierTimerMode.state = state
        default:
            Log.error("HeatersViewModel doesn't reload entityID: \(entityID)")
        }
    }

    func updateHeater(from heater: HeaterEntity) {
        if heater.entityId == .heaterCorridor {
            heaterCorridor = heater
        } else if heater.entityId == .heaterPlayroom {
            heaterPlayroom = heater
        } else {
            Log.error("HeatersViewModel doesn't update heater with entityID: \(heater.entityId)")
        }
    }
}

private extension HeatersViewModel {
    func toggleHeaterTimerMode(heaterEntityID: EntityId, heaterTimerModeEntityID: EntityId, dateEntity: Entity, action: Action) {
        var dateEntity = dateEntity
        restAPIService.update(entityID: heaterTimerModeEntityID, domain: .inputBoolean, action: action)

        if action == .turnOn {
            let calendar = Calendar.current
            let now = Date()
            if let newDate = calendar.date(byAdding: .minute, value: 15, to: now) {
                dateEntity.date = newDate
                setClimateSchedule(dateEntity: dateEntity)
                if heaterEntityID == .purifierFanSpeed {
                    restAPIService.update(entityID: .purifierSavedSpeed,
                                          domain: .inputNumber,
                                          action: .setValue,
                                          dataKey: .value,
                                          dataValue: purifier.speed.toFanSpeedPercentage)
                } else {
                    restAPIService.callScript(scriptID: .saveClimateState, variables: [.entityID: heaterEntityID.rawValue])
                }
            }
        }
    }
}
