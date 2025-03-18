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
        async let tmpThermCorridor = reload(entity: thermCorridor)
        async let tmpThermBedroom = reload(entity: thermBedroom)
        async let tmpThermGym = reload(entity: thermGym)
        async let tmpThermVince = reload(entity: thermVince)
        async let tmpThermKitchen = reload(entity: thermKitchen)
        async let tmpThermCommonarea = reload(entity: thermCommonarea)
        async let tmpThermPlayroom = reload(entity: thermPlayroom)
        async let tmpThermGuest = reload(entity: thermGuest)
        async let tmpHeaterCorridor = reload(entity: heaterCorridor)
        async let tmpHeaterPlayroom = reload(entity: heaterPlayroom)

        thermCorridor = await tmpThermCorridor
        thermBedroom = await tmpThermBedroom
        thermGym = await tmpThermGym
        thermVince = await tmpThermVince
        thermKitchen = await tmpThermKitchen
        thermCommonarea = await tmpThermCommonarea
        thermPlayroom = await tmpThermPlayroom
        thermGuest = await tmpThermGuest
        heaterCorridor = await tmpHeaterCorridor
        heaterPlayroom = await tmpHeaterPlayroom

        for entityID in entityIDs {
            do {
                if entityID == .purifierFanSpeed {
                    let purifierSpeed = try await restAPIService.reload(entityId: entityID, entityType: PurifierSpeed.self)
                    purifier.speed = purifierSpeed.speed
                } else {
                    let entity = try await restAPIService.reloadState(entityID: entityID)
                    reload(entityID: entityID, state: entity.state)
                }
            } catch {
                Log.error("Failed to reload entity: \(entityID): \(error)")
            }
        }
    }

    func reload<T: EntityProtocol>(entity: T) async -> T {
        await restAPIService.reload(hassEntity: entity, entityType: T.self)
    }
}
