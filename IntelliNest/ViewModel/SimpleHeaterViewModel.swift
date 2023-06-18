//
//  SimpleHeaterViewModel.swift
//  IntelliNest
//
//  Created by Tobias on 2022-09-13.
//

import Foundation

class SimpleHeaterViewModel: ObservableObject {
    let apiService: HassApiService

    let roomName: String
    let leftVaneTitle: String
    let rightVaneTitle: String

    @Published var therm1: Entity
    @Published var therm2: Entity
    @Published var therm3: Entity
    @Published var therm4: Entity
    @Published var heater: HeaterEntity
    @Published var showDetails: Bool = false

    static let numberFormat: NumberFormatter = {
        let numberFormatter = NumberFormatter()
        numberFormatter.minimumFractionDigits = 0
        numberFormatter.maximumFractionDigits = 1
        return numberFormatter
    }()

    init(apiService: HassApiService = HassApiService(), roomName: String, leftVaneTitle: String, rightVaneTitle: String,
         therm1: Entity, therm2: Entity, therm3: Entity, therm4: Entity, heater: HeaterEntity) {
        self.apiService = apiService
        self.roomName = roomName
        self.leftVaneTitle = leftVaneTitle
        self.rightVaneTitle = rightVaneTitle
        self.therm1 = therm1
        self.therm2 = therm2
        self.therm3 = therm3
        self.therm4 = therm4
        self.heater = heater
    }

    func reload() {
        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { @MainActor in self.therm1 = await self.reload(entity: self.therm1) }
                group.addTask { @MainActor in self.therm2 = await self.reload(entity: self.therm2) }
                group.addTask { @MainActor in self.therm3 = await self.reload(entity: self.therm3) }
                group.addTask { @MainActor in self.therm4 = await self.reload(entity: self.therm4) }
                group.addTask { @MainActor in self.heater = await self.reload(entity: self.heater) }
            }
        }
    }

    private func reload<T: EntityProtocol>(entity: T) async -> T {
        return await apiService.reload(hassEntity: entity, entityType: T.self)
    }
}
