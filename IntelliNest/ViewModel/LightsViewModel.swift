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
        .lamporIKorridoren: LightEntity(entityId: .lamporIKorridoren),
        .korridorenN: LightEntity(entityId: .korridorenN),
        .korridorenS: LightEntity(entityId: .korridorenS),
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

        let noStateChange = lightEntities[lightID]?.state != state
        lightEntities[lightID]?.state = state
        if let brightness {
            if lightEntities.keys.contains(lightID) {
                updateTasks[lightID]?.cancel()
                let task = DispatchWorkItem { [weak self] in
                    self?.lightEntities[lightID]?.brightness = brightness
                    self?.updateTasks[lightID] = nil
                }
                updateTasks[lightID] = task
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: task)
            }
        }
    }

    func onSliderChange(slideable: Slideable, brightness: Int) {
        if let light = slideable as? LightEntity {
            var updatedLight = light
            updatedLight.brightness = brightness
            lightEntities[light.entityId] = updatedLight
        }
    }

    func onSliderRelease(slideable: Slideable) {
        Task { @MainActor in
            if let slideableLight = slideable as? LightEntity,
               let light = lightEntities[slideableLight.entityId] {
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
    }

    func onToggle(slideable: Slideable) {
        Task { @MainActor in
            if let slideableLight = slideable as? LightEntity,
               let light = lightEntities[slideableLight.entityId] {
                var action = Action.turnOn
                if light.isActive {
                    action = .turnOff
                }

                websocketService.updateLights(lightIDs: [light.entityId], action: action, brightness: light.brightness)
            }
        }
    }
}

extension LightsViewModel {
    var corridor: LightEntity {
        lightEntities[.lamporIKorridoren] ?? .init(entityId: .lamporIKorridoren)
    }

    var corridorNorth: LightEntity {
        lightEntities[.korridorenN] ?? .init(entityId: .korridorenN)
    }

    var corridorSouth: LightEntity {
        lightEntities[.korridorenS] ?? .init(entityId: .korridorenS)
    }

    var sofa: LightEntity {
        lightEntities[.sofa] ?? .init(entityId: .sofa)
    }

    var cozy: LightEntity {
        lightEntities[.cozyCorner] ?? .init(entityId: .cozyCorner)
    }

    var livingRoom: LightEntity {
        lightEntities[.lightsInLivingRoom] ?? .init(entityId: .lightsInLivingRoom)
    }

    var playroom: LightEntity {
        lightEntities[.lightsInPlayroom] ?? .init(entityId: .lightsInPlayroom)
    }

    var guestroom: LightEntity {
        lightEntities[.lightsInGuestRoom] ?? .init(entityId: .lightsInGuestRoom)
    }

    var laundryRoom: LightEntity {
        lightEntities[.laundryRoom] ?? .init(entityId: .laundryRoom)
    }
}
