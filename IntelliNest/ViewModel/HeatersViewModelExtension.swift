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
    var heaterCorridorTimerMode: Entity { get set }
    var heaterPlayroomTimerMode: Entity { get set }

    func reload() async
    func reload<T: EntityProtocol>(entity: T) async -> T
}

extension HeatersViewModel: HeaterReloadable {
    @MainActor
    func reload() async {
        async let tmpThermCorridor = reload(entity: thermCorridor)
        async let tmpThermBedroom = reload(entity: thermBedroom)
        async let tmpThermGym = reload(entity: thermGym)
        async let tmpThermVince = reload(entity: thermVince)
        async let tmpThermKitchen = reload(entity: thermKitchen)
        async let tmpThermCommonarea = reload(entity: thermCommonarea)
        async let tmpThermPlayroom = reload(entity: thermPlayroom)
        async let tmpThermGuest = reload(entity: thermGuest)

        thermCorridor = await tmpThermCorridor
        thermBedroom = await tmpThermBedroom
        thermGym = await tmpThermGym
        thermVince = await tmpThermVince
        thermKitchen = await tmpThermKitchen
        thermCommonarea = await tmpThermCommonarea
        thermPlayroom = await tmpThermPlayroom
        thermGuest = await tmpThermGuest
    }

    func reload<T: EntityProtocol>(entity: T) async -> T {
        return await apiService.reload(hassEntity: entity, entityType: T.self)
    }
}
