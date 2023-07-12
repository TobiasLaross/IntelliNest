//
//  HeatersViewModel.swift
//  IntelliNest
//
//  Created by Tobias on 2022-09-24.
//

import Foundation

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
    @Published var isCorridorTimerModeEnabled = Entity(entityId: .heaterCorridorTimerMode)
    @Published var isPlayroomTimerModeEnabled = Entity(entityId: .heaterPlayroomTimerMode)

    @Published var showCorridorDetails = false
    @Published var showPlayroomDetails = false

    let apiService: HassApiService
    let appearedAction: DestinationClosure
    init(apiService: HassApiService, appearedAction: @escaping DestinationClosure) {
        self.apiService = apiService
        self.appearedAction = appearedAction
    }

    func setTargetTemperature(entityId: EntityId, temperature: Double) {
        Task {
            var json = [JSONKey: Any]()
            json[.entityID] = entityId.rawValue
            json[.temperature] = temperature
            await apiService.sendPostRequest(json: json, domain: .climate, action: .setTemperature)
        }
    }

    func setHvacMode(heater: HeaterEntity, hvacMode: String) {
        Task {
            if hvacMode != heater.state {
                var json = [JSONKey: Any]()
                json[.entityID] = heater.entityId.rawValue
                json[.hvacMode] = hvacMode
                await apiService.sendPostRequest(json: json, domain: .climate, action: .setHvacMode)

                if heater.entityId == .heaterCorridor {
                    reloadHeaterCorridorUntilHvacUpdated()
                } else {
                    reloadHeaterPlayroomUntilHvacUpdated()
                }
            }
        }
    }

    func fanModeSelectedCallback(heater: HeaterEntity, fanMode: FanMode) {
        Task {
            if fanMode != heater.fanMode {
                var json = [JSONKey: Any]()
                json[JSONKey.entityID] = heater.entityId.rawValue
                json[JSONKey.fanMode] = fanMode.rawValue
                await apiService.sendPostRequest(json: json, domain: Domain.climate,
                                                 action: Action.setFanMode)
                if heater.entityId == .heaterCorridor {
                    reloadHeaterCorridorUntilFanUpdated()
                } else {
                    reloadHeaterPlayroomUntilFanUpdated()
                }
            }
        }
    }

    func horizontalModeSelectedCallback(heater: HeaterEntity, horizontalMode: HorizontalMode) {
        Task {
            if horizontalMode != heater.vaneHorizontal {
                var json = [JSONKey: Any]()
                json[JSONKey.entityID] = heater.entityId.rawValue
                json[JSONKey.position] = horizontalMode.rawValue
                await apiService.sendPostRequest(json: json,
                                                 domain: Domain.melcloud,
                                                 action: Action.setVaneHorizontal)
                if heater.entityId == .heaterCorridor {
                    reloadHeaterCorridorUntilVaneHorizontalUpdated()
                } else {
                    reloadHeaterPlayroomUntilVaneHorizontalUpdated()
                }
            }
        }
    }

    func verticalModeSelectedCallback(heater: HeaterEntity, verticalMode: HeaterVerticalPosition) {
        Task {
            if verticalMode != heater.vaneVertical {
                var json = [JSONKey: Any]()
                json[JSONKey.entityID] = heater.entityId.rawValue
                json[JSONKey.position] = verticalMode.rawValue
                await apiService.sendPostRequest(json: json,
                                                 domain: Domain.melcloud,
                                                 action: Action.setVaneVertical)
                if heater.entityId == .heaterCorridor {
                    reloadHeaterCorridorUntilVaneVerticalUpdated()
                } else {
                    reloadHeaterPlayroomUntilVaneVerticalUpdated()
                }
            }
        }
    }

    func setClimateSchedule(dateEntity: Entity) async {
        await apiService.setDateTimeEntity(dateEntity: dateEntity)
    }

    func toggleCorridorTimerMode() {
        Task { @MainActor in
            let action: Action = isCorridorTimerModeEnabled.isActive ? .turnOff : .turnOn
            await apiService.setState(for: .heaterCorridorTimerMode, in: .inputBoolean, using: action)
            isCorridorTimerModeEnabled.isActive.toggle()
            if isCorridorTimerModeEnabled.isActive {
                let calendar = Calendar.current
                let now = Date()
                if let newDate = calendar.date(byAdding: .minute, value: 15, to: now) {
                    resetCorridorHeaterTime.date = newDate
                    await setClimateSchedule(dateEntity: resetCorridorHeaterTime)
                }
                await apiService.callScript(entityId: .saveClimateState, variables: [.entityID: EntityId.heaterCorridor.rawValue])
            }
        }
    }

    func togglePlayroomTimerMode() {
        Task { @MainActor in
            let action: Action = isPlayroomTimerModeEnabled.isActive ? .turnOff : .turnOn
            await apiService.setState(for: .heaterPlayroomTimerMode, in: .inputBoolean, using: action)
            isPlayroomTimerModeEnabled.isActive.toggle()
            if isPlayroomTimerModeEnabled.isActive {
                let calendar = Calendar.current
                let now = Date()
                if let newDate = calendar.date(byAdding: .minute, value: 15, to: now) {
                    resetPlayroomHeaterTime.date = newDate
                    await setClimateSchedule(dateEntity: resetPlayroomHeaterTime)
                }
                await apiService.callScript(entityId: .saveClimateState, variables: [.entityID: EntityId.heaterPlayroom.rawValue])
            }
        }
    }
}
