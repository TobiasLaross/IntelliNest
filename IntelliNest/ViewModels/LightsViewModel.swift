//
//  LightsViewModel.swift
//  IntelliNest
//
//  Created by Tobias on 2022-07-07.
//

import Foundation
import ShipBookSDK

@MainActor
class LightsViewModel: ObservableObject {
    @Published var lightEntities: [EntityId: LightEntity] = [
        .sofa: LightEntity(entityId: .sofa),
        .cozyCorner: LightEntity(entityId: .cozyCorner),
        .lightsInLivingRoom: LightEntity(entityId: .lightsInLivingRoom),
        .lightsInCorridor: LightEntity(entityId: .lightsInCorridor),
        .corridorN: LightEntity(entityId: .corridorN),
        .corridorS: LightEntity(entityId: .corridorS),
        .lightsInPlayroom: LightEntity(entityId: .lightsInPlayroom,
                                       groupedLightIDs: [.playroomCeiling1, .playroomCeiling2, .playroomCeiling3]),
        .lightsInGuestRoom: LightEntity(entityId: .lightsInGuestRoom,
                                        groupedLightIDs: [.guestRoomCeiling1, .guestRoomCeiling2, .guestRoomCeiling3]),
        .laundryRoom: LightEntity(entityId: .laundryRoom)
    ]
    private var isReloading = false

    let corridorName = "Korridoren"
    let corridorSouthName = "Södra"
    let corridorNorthName = "Norra"
    let livingroomName = "Vardagsrummet"
    let cozyName = "Myshörnan"
    let sofaName = "Soffbordet"
    let vinceName = "Vince rum"
    let vitrinName = "Vitrinskåpet"
    let playroomName = "Lekrummet"
    let guestroomName = "Gästrummet"
    let laundryRoomName = "Tvättstugan"

    private var restAPIService: RestAPIService

    init(restAPIService: RestAPIService) {
        self.restAPIService = restAPIService
    }

    func reload() async {
        guard !isReloading else {
            return
        }
        isReloading = true
        for (entityID, light) in lightEntities {
            do {
                var updatedLight = try await restAPIService.reload(entityId: entityID, entityType: LightEntity.self)
                updatedLight.groupedLightIDs = light.groupedLightIDs
                lightEntities[entityID] = updatedLight
            } catch {
                Log.error("Failed to reload light: \(entityID): \(error)")
            }
        }
        isReloading = false
    }

    func onSliderChange(slideable: Slideable, brightness: Int) {
        if let light = slideable as? LightEntity {
            var updatedLight = light
            updatedLight.brightness = brightness
            lightEntities[light.entityId] = updatedLight
        }
    }

    @MainActor
    func onSliderRelease(slideable: Slideable) async {
        if let slideableLight = slideable as? LightEntity,
           let light = lightEntities[slideableLight.entityId] {
            lightEntities[slideableLight.entityId]?.isUpdating = true
            var action = Action.turnOn
            if light.brightness <= 0 {
                action = .turnOff
            }

            var lightIDs = [light.entityId]
            if let groupedLightIDs = light.groupedLightIDs {
                lightIDs.insert(contentsOf: groupedLightIDs, at: 0)
            }

            restAPIService.update(lightIDs: lightIDs, action: action, brightness: light.brightness, reloadTimes: 2)
        }
    }

    @MainActor
    func onToggle(slideable: Slideable) async {
        if let slideableLight = slideable as? LightEntity,
           let light = lightEntities[slideableLight.entityId] {
            lightEntities[slideableLight.entityId]?.isUpdating = true
            var action = Action.turnOn
            if light.isActive {
                action = .turnOff
            }

            var lightIDs = [light.entityId]
            if let groupedLightIDs = light.groupedLightIDs {
                lightIDs.insert(contentsOf: groupedLightIDs, at: 0)
            }

            restAPIService.update(lightIDs: lightIDs, action: action, brightness: light.brightness, reloadTimes: 2)
        }
    }
}
