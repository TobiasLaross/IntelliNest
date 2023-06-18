//
//  EniroClimateScheduleViewModel.swift
//  IntelliNest
//
//  Created by Tobias on 2022-09-16.
//

import Foundation

class EniroClimateScheduleViewModel: HassViewModelProtocol {
    @Published var climate1 = Entity(entityId: .eniroClimateSchedule1)
    @Published var climate1Bool = Entity(entityId: .eniroClimateSchedule1Bool)
    @Published var climate2 = Entity(entityId: .eniroClimateSchedule2)
    @Published var climate2Bool = Entity(entityId: .eniroClimateSchedule2Bool)
    @Published var climate3 = Entity(entityId: .eniroClimateSchedule3)
    @Published var climate3Bool = Entity(entityId: .eniroClimateSchedule3Bool)
    @Published var climateMorning = Entity(entityId: .eniroClimateScheduleMorning)
    @Published var climateMorningBool = Entity(entityId: .eniroClimateScheduleMorningBool)
    @Published var climateDay = Entity(entityId: .eniroClimateScheduleDay)
    @Published var climateDayBool = Entity(entityId: .eniroClimateScheduleDayBool)
    var isReloading = false

    private var apiService: HassApiService
    let appearedAction: DestinationClosure
    init(apiService: HassApiService, appearedAction: @escaping DestinationClosure) {
        self.apiService = apiService
        self.appearedAction = appearedAction
    }

    func setClimateSchedule(dateEntity: Entity) async {
        await apiService.setDateTimeEntity(dateEntity: dateEntity)
    }

    func updateToggle(entity: Entity) async {
        let toggleAction = entity.isActive ? Action.turnOn : Action.turnOff
        await apiService.setStateFor(entity: entity, domain: .inputBoolean, action: toggleAction)
    }

    private func reload<T: EntityProtocol>(entity: T) async -> T {
        return await apiService.reload(hassEntity: entity, entityType: T.self)
    }

    @MainActor
    func reload() async {
        if !isReloading {
            isReloading = true
            async let tmpClimate1 = reload(entity: climate1)
            async let tmpClimate2 = reload(entity: climate2)
            async let tmpClimate3 = reload(entity: climate3)
            async let tmpClimate1Bool = reload(entity: climate1Bool)
            async let tmpClimate2Bool = reload(entity: climate2Bool)
            async let tmpClimate3Bool = reload(entity: climate3Bool)
            async let tmpClimateMorning = reload(entity: climateMorning)
            async let tmpClimateMorningBool = reload(entity: climateMorningBool)
            async let tmpClimateDay = reload(entity: climateDay)
            async let tmpClimateDayBool = reload(entity: climateDayBool)
            climate1 = await tmpClimate1
            climate2 = await tmpClimate2
            climate3 = await tmpClimate3
            climate1Bool = await tmpClimate1Bool
            climate2Bool = await tmpClimate2Bool
            climate3Bool = await tmpClimate3Bool
            climateMorning = await tmpClimateMorning
            climateMorningBool = await tmpClimateMorningBool
            climateDay = await tmpClimateDay
            climateDayBool = await tmpClimateDayBool
            isReloading = false
        }
    }
}
