//
//  HeatersViewModelExtension.swift
//  IntelliNest
//
//  Created by Tobias on 2023-06-17.
//

import Foundation
import ShipBookSDK

extension HeatersViewModel {
    @MainActor
    func reload() async {
        await withReloadGuard {
            async let tmpThermCorridor = self.reload(entity: self.thermCorridor)
            async let tmpThermBedroom = self.reload(entity: self.thermBedroom)
            async let tmpThermGym = self.reload(entity: self.thermGym)
            async let tmpThermVince = self.reload(entity: self.thermVince)
            async let tmpThermKitchen = self.reload(entity: self.thermKitchen)
            async let tmpThermCommonarea = self.reload(entity: self.thermCommonarea)
            async let tmpThermPlayroom = self.reload(entity: self.thermPlayroom)
            async let tmpThermGuest = self.reload(entity: self.thermGuest)
            async let tmpHeaterCorridor = self.reload(entity: self.heaterCorridor)
            async let tmpHeaterPlayroom = self.reload(entity: self.heaterPlayroom)

            self.thermCorridor = await tmpThermCorridor
            self.thermBedroom = await tmpThermBedroom
            self.thermGym = await tmpThermGym
            self.thermVince = await tmpThermVince
            self.thermKitchen = await tmpThermKitchen
            self.thermCommonarea = await tmpThermCommonarea
            self.thermPlayroom = await tmpThermPlayroom
            self.thermGuest = await tmpThermGuest
            self.heaterCorridor = await tmpHeaterCorridor
            self.heaterPlayroom = await tmpHeaterPlayroom

            for entityID in self.entityIDs {
                do {
                    if entityID == .purifierFanSpeed {
                        let purifierSpeed = try await self.restAPIService.reload(entityId: entityID, entityType: PurifierSpeed.self)
                        self.purifier.speed = purifierSpeed.speed
                    } else {
                        let entity = try await self.restAPIService.reloadState(entityID: entityID)
                        self.reload(entityID: entityID, state: entity.state)
                    }
                } catch {
                    Log.error("Failed to reload entity: \(entityID): \(error)")
                }
            }
        }
    }

    func reload<T: EntityProtocol>(entity: T) async -> T {
        await restAPIService.reload(hassEntity: entity, entityType: T.self)
    }
}
