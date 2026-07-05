//
//  HeatersViewModel.swift
//  IntelliNest
//
//  Created by Tobias on 2022-09-24.
//

import Foundation

@MainActor
class HeatersViewModel: ObservableObject, Reloadable {
    @Published var heaterCorridor = HeaterEntity(entityId: .heaterCorridor)
    @Published var heaterPlayroom = HeaterEntity(entityId: .heaterPlayroom)
    @Published var purifier = PurifierEntity()
    @Published var purifier500 = PurifierEntity()
    @Published var thermCorridor = Entity(entityId: .thermCorridor)
    @Published var resetCorridorHeaterTime = Entity(entityId: .resetCorridorHeaterTime)
    @Published var resetPlayroomHeaterTime = Entity(entityId: .resetPlayroomHeaterTime)
    @Published var resetPurifierTime = Entity(entityId: .resetPurifierTime)
    @Published var resetPurifier500Time = Entity(entityId: .resetPurifier500Time)
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
    @Published var purifier500TimerMode = Entity(entityId: .purifier500TimerMode)

    let entityIDs: [EntityId] = [.resetCorridorHeaterTime, .resetPlayroomHeaterTime, .heaterCorridorTimerMode, .heaterPlayroomTimerMode,
                                 .purifierTimerMode, .purifierFanSpeed, .purifierHumidity, .purifierTemperature, .purifierMode,
                                 .resetPurifierTime, .purifier500TimerMode, .purifier500FanSpeed, .purifier500PM25,
                                 .resetPurifier500Time]

    var purifierSubtitle: String {
        "\(purifier.temperature)℃ - \(purifier.humidity)%"
    }

    var purifier500Subtitle: String {
        "PM2.5 \(purifier500.pm25) µg/m³"
    }

    var isReloading = false

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
                              dataValue: "\(temperature)",
                              reloadTimes: 5)
    }

    func setPurifierFanSpeed(_ speed: Double) {
        restAPIService.update(entityID: .purifierFanSpeed,
                              domain: .fan,
                              action: .setPercentage,
                              dataKey: .percentage,
                              dataValue: PurifierFanScale.pure.percentage(forLevel: speed),
                              reloadTimes: 5)
    }

    func setPurifier500FanSpeed(_ speed: Double) {
        restAPIService.update(entityID: .purifier500FanSpeed,
                              domain: .fan,
                              action: .setPercentage,
                              dataKey: .percentage,
                              dataValue: PurifierFanScale.pure500.percentage(forLevel: speed),
                              reloadTimes: 5)
    }

    func setHvacMode(heater: HeaterEntity, hvacMode: HvacMode) {
        restAPIService.update(entityID: heater.entityId,
                              domain: .climate,
                              action: .setHvacMode,
                              dataKey: .hvacMode,
                              dataValue: hvacMode.rawValue,
                              reloadTimes: 5)
    }

    func setFanMode(_ heater: HeaterEntity, _ fanMode: HeaterFanMode) {
        if fanMode != heater.fanMode {
            restAPIService.update(entityID: heater.entityId,
                                  domain: .climate,
                                  action: .setFanMode,
                                  dataKey: .fanMode,
                                  dataValue: fanMode.rawValue,
                                  reloadTimes: 5)
        }
    }

    func horizontalModeSelectedCallback(_ heater: HeaterEntity, _ horizontalMode: HeaterHorizontalMode) {
        restAPIService.update(entityID: heater.entityId,
                              domain: .melcloud,
                              action: .setVaneHorizontal,
                              dataKey: .position,
                              dataValue: horizontalMode.rawValue,
                              reloadTimes: 5)
    }

    func verticalModeSelectedCallback(_ heater: HeaterEntity, _ verticalMode: HeaterVerticalMode) {
        restAPIService.update(entityID: heater.entityId,
                              domain: .melcloud,
                              action: .setVaneVertical,
                              dataKey: .position,
                              dataValue: verticalMode.rawValue,
                              reloadTimes: 5)
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
                              action: action,
                              savedSpeed: (.purifierSavedSpeed, PurifierFanScale.pure.percentage(forLevel: purifier.speed)))
    }

    func togglePurifier500TimerMode() {
        let action: Action = purifier500TimerMode.isActive ? .turnOff : .turnOn
        toggleHeaterTimerMode(heaterEntityID: .purifier500FanSpeed,
                              heaterTimerModeEntityID: purifier500TimerMode.entityId,
                              dateEntity: resetPurifier500Time,
                              action: action,
                              savedSpeed: (.purifier500SavedSpeed, PurifierFanScale.pure500.percentage(forLevel: purifier500.speed)))
    }

    private lazy var entityKeyPaths: [EntityId: ReferenceWritableKeyPath<HeatersViewModel, Entity>] = [
        .resetCorridorHeaterTime: \.resetCorridorHeaterTime,
        .resetPlayroomHeaterTime: \.resetPlayroomHeaterTime,
        .heaterCorridorTimerMode: \.heaterCorridorTimerMode,
        .heaterPlayroomTimerMode: \.heaterPlayroomTimerMode,
        .resetPurifierTime: \.resetPurifierTime,
        .purifierTimerMode: \.purifierTimerMode,
        .resetPurifier500Time: \.resetPurifier500Time,
        .purifier500TimerMode: \.purifier500TimerMode
    ]

    private lazy var purifierReloaders: [EntityId: (String) -> Void] = [
        .purifierMode: { [unowned self] state in purifier.fanMode = PurifierFanMode(rawValue: state) ?? .off },
        .purifierFanSpeed: { [unowned self] state in purifier.speed = PurifierFanScale.pure.level(forPercentage: Double(state) ?? 0) },
        .purifierTemperature: { [unowned self] state in purifier.temperature = Double(state) ?? 0 },
        .purifierHumidity: { [unowned self] state in purifier.humidity = Int(state) ?? 0 },
        .purifier500FanSpeed: { [unowned self] state in
            purifier500.speed = PurifierFanScale.pure500.level(forPercentage: Double(state) ?? 0)
        },
        .purifier500PM25: { [unowned self] state in purifier500.pm25 = Int(Double(state) ?? 0) }
    ]

    func reload(entityID: EntityId, state: String) {
        if let keyPath = entityKeyPaths[entityID] {
            self[keyPath: keyPath].state = state
        } else if let reloader = purifierReloaders[entityID] {
            reloader(state)
        } else {
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
    /// Toggles a timer-mode helper. On enable it schedules the reset time 15 minutes out and snapshots the
    /// current speed/state so a Home Assistant automation can restore it: purifiers save their fan percentage
    /// into `savedSpeed`, heaters snapshot via the `saveClimateState` script.
    func toggleHeaterTimerMode(heaterEntityID: EntityId,
                               heaterTimerModeEntityID: EntityId,
                               dateEntity: Entity,
                               action: Action,
                               savedSpeed: (entityID: EntityId, percentage: Double)? = nil) {
        var dateEntity = dateEntity
        restAPIService.update(entityID: heaterTimerModeEntityID, domain: .inputBoolean, action: action)

        if action == .turnOn {
            let calendar = Calendar.current
            let now = Date()
            if let newDate = calendar.date(byAdding: .minute, value: 15, to: now) {
                dateEntity.date = newDate
                setClimateSchedule(dateEntity: dateEntity)
                if let savedSpeed {
                    restAPIService.update(entityID: savedSpeed.entityID,
                                          domain: .inputNumber,
                                          action: .setValue,
                                          dataKey: .value,
                                          dataValue: savedSpeed.percentage)
                } else {
                    restAPIService.callScript(scriptID: .saveClimateState, variables: [.entityID: heaterEntityID.rawValue])
                }
            }
        }
    }
}
