//
//  HeatersViewModelExtension.swift
//  IntelliNest
//
//  Created by Tobias on 2023-06-17.
//

import Foundation

protocol HeaterReloadable: AnyObject {
    var heaterCorridor: HeaterEntity { get set }
    var heaterPlayroom: HeaterEntity { get set }
    var thermCorridor: Entity { get set }
    var resetCorridorHeaterTime: Entity { get set }
    var resetPlayroomHeaterTime: Entity { get set }
    var thermBedroom: Entity { get set }
    var thermGym: Entity { get set }
    var thermVince: Entity { get set }
    var thermKitchen: Entity { get set }
    var thermCommonarea: Entity { get set }
    var thermPlayroom: Entity { get set }
    var thermGuest: Entity { get set }
    var isCorridorTimerModeEnabled: Entity { get set }
    var isPlayroomTimerModeEnabled: Entity { get set }

    func reload() async
    func reloadHeaterCorridorUntilHvacUpdated() async
    func reloadHeaterPlayroomUntilHvacUpdated() async
    func reloadHeaterCorridorUntilFanUpdated() async
    func reloadHeaterPlayroomUntilFanUpdated() async
    func reloadHeaterCorridorUntilVaneHorizontalUpdated() async
    func reloadHeaterPlayroomUntilVaneHorizontalUpdated() async
    func reloadHeaterCorridorUntilVaneVerticalUpdated() async
    func reloadHeaterPlayroomUntilVaneVerticalUpdated() async
    func reload<T: EntityProtocol>(entity: T) async -> T
}

extension HeatersViewModel: HeaterReloadable {
    @MainActor
    func reload() async {
        async let tmpHeaterCorridor = reload(entity: heaterCorridor)
        async let tmpHeaterPlayroom = reload(entity: heaterPlayroom)
        async let tmpThermCorridor = reload(entity: thermCorridor)
        async let tmpThermBedroom = reload(entity: thermBedroom)
        async let tmpThermGym = reload(entity: thermGym)
        async let tmpThermVince = reload(entity: thermVince)
        async let tmpThermKitchen = reload(entity: thermKitchen)
        async let tmpThermCommonarea = reload(entity: thermCommonarea)
        async let tmpThermPlayroom = reload(entity: thermPlayroom)
        async let tmpThermGuest = reload(entity: thermGuest)
        async let tmpCorridorTimerModeEnabled = reload(entity: isCorridorTimerModeEnabled)
        async let tmpPlayroomTimerModeEnabled = reload(entity: isPlayroomTimerModeEnabled)
        async let tmpResetCorridorHeaterTime = reload(entity: resetCorridorHeaterTime)
        async let tmpResetPlayroomHeaterTime = reload(entity: resetPlayroomHeaterTime)

        heaterCorridor = await tmpHeaterCorridor
        heaterPlayroom = await tmpHeaterPlayroom
        thermCorridor = await tmpThermCorridor
        thermBedroom = await tmpThermBedroom
        thermGym = await tmpThermGym
        thermVince = await tmpThermVince
        thermKitchen = await tmpThermKitchen
        thermCommonarea = await tmpThermCommonarea
        thermPlayroom = await tmpThermPlayroom
        thermGuest = await tmpThermGuest
        isCorridorTimerModeEnabled = await tmpCorridorTimerModeEnabled
        isPlayroomTimerModeEnabled = await tmpPlayroomTimerModeEnabled
        resetCorridorHeaterTime = await tmpResetCorridorHeaterTime
        resetPlayroomHeaterTime = await tmpResetPlayroomHeaterTime
    }

    func reloadHeaterCorridorUntilHvacUpdated() {
        Task { @MainActor in
            let hvac = self.heaterCorridor.state
            var count = 0
            while hvac == heaterCorridor.state && count < 10 {
                try await Task.sleep(seconds: 0.5)
                self.heaterCorridor = await self.reload(entity: self.heaterCorridor)
                count += 1
            }
        }
    }

    func reloadHeaterPlayroomUntilHvacUpdated() {
        Task { @MainActor in
            let hvac = self.heaterPlayroom.state
            var count = 0
            while hvac == heaterPlayroom.state && count < 10 {
                try await Task.sleep(seconds: 0.5)
                self.heaterPlayroom = await self.reload(entity: self.heaterPlayroom)
                count += 1
            }
        }
    }

    func reloadHeaterCorridorUntilFanUpdated() {
        Task { @MainActor in
            let fanMode = self.heaterCorridor.fanMode
            var count = 0
            while fanMode == heaterCorridor.fanMode && count < 10 {
                try await Task.sleep(seconds: 0.5)
                self.heaterCorridor = await self.reload(entity: self.heaterCorridor)
                count += 1
            }
        }
    }

    func reloadHeaterPlayroomUntilFanUpdated() {
        Task { @MainActor in
            let fanMode = self.heaterPlayroom.fanMode
            var count = 0
            while fanMode == heaterPlayroom.fanMode && count < 10 {
                try await Task.sleep(seconds: 0.5)
                self.heaterPlayroom = await self.reload(entity: self.heaterPlayroom)
                count += 1
            }
        }
    }

    func reloadHeaterCorridorUntilVaneHorizontalUpdated() {
        Task { @MainActor in
            let vaneHorizontal = heaterCorridor.vaneHorizontal
            var count = 0
            while vaneHorizontal == heaterCorridor.vaneHorizontal && count < 10 {
                try await Task.sleep(seconds: 0.5)
                self.heaterCorridor = await self.reload(entity: self.heaterCorridor)
                count += 1
            }
        }
    }

    func reloadHeaterPlayroomUntilVaneHorizontalUpdated() {
        Task { @MainActor in
            let vaneHorizontal = heaterPlayroom.vaneHorizontal
            var count = 0
            while vaneHorizontal == heaterPlayroom.vaneHorizontal && count < 10 {
                try await Task.sleep(seconds: 0.5)
                self.heaterPlayroom = await self.reload(entity: self.heaterPlayroom)
                count += 1
            }
        }
    }

    func reloadHeaterCorridorUntilVaneVerticalUpdated() {
        Task { @MainActor in
            let vaneVertical = heaterCorridor.vaneVertical
            var count = 0
            while vaneVertical == heaterCorridor.vaneVertical && count < 10 {
                try await Task.sleep(seconds: 0.5)
                self.heaterCorridor = await self.reload(entity: self.heaterCorridor)
                count += 1
            }
        }
    }

    func reloadHeaterPlayroomUntilVaneVerticalUpdated() {
        Task { @MainActor in
            let vaneVertical = heaterPlayroom.vaneVertical
            var count = 0
            while vaneVertical == heaterPlayroom.vaneVertical && count < 10 {
                try await Task.sleep(seconds: 0.5)
                self.heaterPlayroom = await self.reload(entity: self.heaterPlayroom)
                count += 1
            }
        }
    }

    func reload<T: EntityProtocol>(entity: T) async -> T {
        return await apiService.reload(hassEntity: entity, entityType: T.self)
    }
}
