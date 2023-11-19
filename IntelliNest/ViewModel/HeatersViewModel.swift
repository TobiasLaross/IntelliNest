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
    @Published var thermCorridor = Entity(entityId: .thermCorridor)
    @Published var resetCorridorHeaterTime = Entity(entityId: .resetCorridorHeaterTime)
    @Published var resetPlayroomHeaterTime = Entity(entityId: .resetPlayroomHeaterTime)
    @Published var thermBedroom = Entity(entityId: .thermBedroom)
    @Published var thermGym = Entity(entityId: .thermGym)
    @Published var thermVince = Entity(entityId: .thermVince)
    @Published var thermKitchen = Entity(entityId: .thermKitchen)
    @Published var thermCommonarea = Entity(entityId: .thermCommonarea)
    @Published var thermPlayroom = Entity(entityId: .thermPlayroom)
    @Published var thermGuest = Entity(entityId: .thermGuest)
    @Published var heaterCorridorTimerMode = Entity(entityId: .heaterCorridorTimerMode)
    @Published var heaterPlayroomTimerMode = Entity(entityId: .heaterPlayroomTimerMode)

    @Published var showCorridorDetails = false
    @Published var showPlayroomDetails = false
    let entityIDs: [EntityId] = [.resetCorridorHeaterTime, .resetPlayroomHeaterTime, .heaterCorridorTimerMode, .heaterPlayroomTimerMode]

    let websocketService: WebSocketService
    let apiService: HassApiService
    let appearedAction: DestinationClosure
    init(websocketService: WebSocketService, apiService: HassApiService, appearedAction: @escaping DestinationClosure) {
        self.websocketService = websocketService
        self.apiService = apiService
        self.appearedAction = appearedAction
    }

    func setTargetTemperature(entityId: EntityId, temperature: Double) {
        websocketService.updateHeaterTemperature(heaterID: entityId, temperature: temperature)
    }

    func setHvacMode(heater: HeaterEntity, hvacMode: HvacMode) {
        websocketService.updateHeaterHvacMode(heaterID: heater.entityId, hvacMode: hvacMode)
    }

    func fanModeSelectedCallback(heater: HeaterEntity, fanMode: HeaterFanMode) {
        if fanMode != heater.fanMode {
            websocketService.updateHeaterFanMode(heaterID: heater.entityId, fanMode: fanMode)
        }
    }

    func horizontalModeSelectedCallback(heater: HeaterEntity, horizontalMode: HeaterHorizontalMode) {
        websocketService.updateHeaterHorizontalMode(heaterID: heater.entityId, horizontalMode: horizontalMode)
    }

    func verticalModeSelectedCallback(heater: HeaterEntity, verticalMode: HeaterVerticalMode) {
        websocketService.updateHeaterVerticalMode(heaterID: heater.entityId, verticalMode: verticalMode)
    }

    func setClimateSchedule(dateEntity: Entity) {
        websocketService.updateDateTimeEntity(entity: dateEntity)
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
        default:
            Log.error("HeatersViewModel doesn't reload entityID: \(entityID)")
        }
    }

    func reloadHeater(_ heater: HeaterEntity) {
        if heater.entityId == .heaterCorridor {
            heaterCorridor = heater
        } else if heater.entityId == .heaterPlayroom {
            heaterPlayroom = heater
        } else {
            Log.error("HeatersViewModel doesn't reload heater with entityID: \(heater.entityId)")
        }
    }

    private func toggleHeaterTimerMode(heaterEntityID: EntityId, heaterTimerModeEntityID: EntityId, dateEntity: Entity, action: Action) {
        var dateEntity = dateEntity
        let serviceID: ServiceID = action == .turnOn ? .boolTurnOn : .boolTurnOff
        websocketService.callService(serviceID: serviceID, variables: [.entityID: heaterTimerModeEntityID.rawValue])

        if action == .turnOn {
            let calendar = Calendar.current
            let now = Date()
            if let newDate = calendar.date(byAdding: .minute, value: 15, to: now) {
                dateEntity.date = newDate
                setClimateSchedule(dateEntity: dateEntity)
                websocketService.callScript(scriptID: .saveClimateState, variables: [.entityID: heaterEntityID.rawValue])
            }
        }
    }
}
