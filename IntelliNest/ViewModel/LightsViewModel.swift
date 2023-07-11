//
//  LightsViewModel.swift
//  IntelliNest
//
//  Created by Tobias on 2022-07-07.
//

import Foundation
import ShipBookSDK

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
    var updateTasks: [EntityId: DispatchWorkItem] = [:]

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

    private var websocketService: WebSocketService
    let appearedAction: DestinationClosure
    init(websocketService: WebSocketService,
         appearedAction: @escaping DestinationClosure) {
        self.websocketService = websocketService
        self.appearedAction = appearedAction
    }

    @MainActor
    func reload(lightID: EntityId, state: String, brightness: Int?) {
        guard lightEntities[lightID] != nil else {
            Log.error("Light: \(lightID) not in lightEntities")
            return
        }

        lightEntities[lightID]?.state = state
        if let brightness {
            if lightEntities.keys.contains(lightID) {
                updateTasks[lightID]?.cancel()
                let task = DispatchWorkItem { [weak self] in
                    self?.lightEntities[lightID]?.brightness = brightness
                    self?.lightEntities[lightID]?.isUpdating = false
                    self?.updateTasks[lightID] = nil
                }
                updateTasks[lightID] = task
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: task)
            }
        }

        if brightness == nil || !lightEntities.keys.contains(lightID) {
            lightEntities[lightID]?.isUpdating = false
        }
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

            websocketService.updateLights(lightIDs: lightIDs, action: action, brightness: light.brightness)
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

            websocketService.updateLights(lightIDs: [light.entityId], action: action, brightness: light.brightness)
        }
    }
}
