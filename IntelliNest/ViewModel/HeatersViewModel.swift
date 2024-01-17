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
    init(websocketService: WebSocketService, apiService: HassApiService) {
        self.websocketService = websocketService
        self.apiService = apiService
    }

    func setTargetTemperature(entityId: EntityId, temperature: Double) {
        websocketService.callService(serviceID: .heaterTemperature,
                                     target: [.entityID: .string(entityId.rawValue)],
                                     data: [.temperature: .double(temperature)])
    }

    func setHvacMode(heater: HeaterEntity, hvacMode: HvacMode) {
        websocketService.callService(serviceID: .heaterHvacMode,
                                     target: [.entityID: .string(heater.entityId.rawValue)],
                                     data: [.hvacMode: .string(hvacMode.rawValue)])
    }

    func fanModeSelectedCallback(heater: HeaterEntity, fanMode: HeaterFanMode) {
        if fanMode != heater.fanMode {
            websocketService.callService(serviceID: .heaterFanMode,
                                         target: [.entityID: .string(heater.entityId.rawValue)],
                                         data: [.fanMode: .string(fanMode.rawValue)])
        }
    }

    func horizontalModeSelectedCallback(heater: HeaterEntity, horizontalMode: HeaterHorizontalMode) {
        websocketService.callService(serviceID: .heaterHorizontal,
                                     target: [.entityID: .string(heater.entityId.rawValue)],
                                     data: [.position: .string(horizontalMode.rawValue)])
    }

    func verticalModeSelectedCallback(heater: HeaterEntity, verticalMode: HeaterVerticalMode) {
        websocketService.callService(serviceID: .heaterVertical,
                                     target: [.entityID: .string(heater.entityId.rawValue)],
                                     data: [.position: .string(verticalMode.rawValue)])
    }

    func setClimateSchedule(dateEntity: Entity) {
        var data: [ServiceDataKeys: ServiceValues] = [:]
        let dateFormatter = DateFormatter()

        dateFormatter.dateFormat = "yyyy-MM-dd"
        data[.date] = .string(dateFormatter.string(from: dateEntity.date))

        dateFormatter.dateFormat = "HH:mm:ss"
        data[.time] = .string(dateFormatter.string(from: dateEntity.date))
        websocketService.callService(serviceID: .setDateTime,
                                     target: [.entityID: .string(dateEntity.entityId.rawValue)],
                                     data: data)
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

    func updateHeater(from heater: HeaterEntity) {
        if heater.entityId == .heaterCorridor {
            heaterCorridor = heater
        } else if heater.entityId == .heaterPlayroom {
            heaterPlayroom = heater
        } else {
            Log.error("HeatersViewModel doesn't update heater with entityID: \(heater.entityId)")
        }
    }

    private func toggleHeaterTimerMode(heaterEntityID: EntityId, heaterTimerModeEntityID: EntityId, dateEntity: Entity, action: Action) {
        var dateEntity = dateEntity
        let serviceID: ServiceID = action == .turnOn ? .boolTurnOn : .boolTurnOff
        websocketService.callService(serviceID: serviceID, data: [.entityID: heaterTimerModeEntityID.rawValue])

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
