//
//  LightsViewModel.swift
//  IntelliNest
//
//  Created by Tobias on 2022-07-07.
//

import Foundation
import ShipBookSDK

class LightsViewModel: HassViewModelProtocol {
    @Published var sofa = LightEntity(entityId: EntityId.soffbordet)
    @Published var cozy = LightEntity(entityId: EntityId.myshornan)
    @Published var livingRoom = LightEntity(entityId: EntityId.lamporIVardagsrummet)
    //    @Published var vince = LightEntity(entityId: EntityId.panel)
    //    @Published var vitrin = LightEntity(entityId: EntityId.vitrinskapet)
    @Published var corridor = LightEntity(entityId: EntityId.lamporIKorridoren)
    @Published var corridorN = LightEntity(entityId: EntityId.korridorenN)
    @Published var corridorS = LightEntity(entityId: EntityId.korridorenS)
    @Published var playroom = LightEntity(entityId: EntityId.lamporILekrummet)
    @Published var guestroom = LightEntity(entityId: EntityId.lamporIGastrummet)
    @Published var laundryRoom = LightEntity(entityId: EntityId.tvattstugan)

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

    private var apiService: HassApiService
    let appearedAction: DestinationClosure
    init(apiService: HassApiService,
         appearedAction: @escaping DestinationClosure) {
        self.apiService = apiService
        self.appearedAction = appearedAction
    }

    @MainActor
    func reload() async {
        async let tmpSofa = reload(light: sofa)
        async let tmpCozy = reload(light: cozy)
        async let tmpLivingRoom = reload(light: livingRoom)
        //            async let tmpVince = reload(light: vince)
        //            async let tmpVitrin = reload(light: vitrin)
        async let tmpCorridor = reload(light: corridor)
        async let tmpCorridorN = reload(light: corridorN)
        async let tmpCorridorS = reload(light: corridorS)
        async let tmpPlayroom = reload(light: playroom)
        async let tmpGuestroom = reload(light: guestroom)
        async let tmpLaundryRoom = reload(light: laundryRoom)
        sofa = await tmpSofa
        cozy = await tmpCozy
        livingRoom = await tmpLivingRoom
        //            vince = await tmpVince
        //            vitrin = await tmpVitrin
        corridor = await tmpCorridor
        corridorN = await tmpCorridorN
        corridorS = await tmpCorridorS
        playroom = await tmpPlayroom
        guestroom = await tmpGuestroom
        laundryRoom = await tmpLaundryRoom
    }

    private func reload(light: LightEntity) async -> LightEntity {
        return await apiService.reload(hassEntity: light, entityType: LightEntity.self)
    }

    func onSliderRelease(light: LightEntity) {
        Task { @MainActor in
            var action = Action.turnOn
            if light.brightness <= 0 {
                action = .turnOff
            }

            await apiService.setState(light: light, action: action)
            await apiService.setState(light: light, action: action)
            await reloadUntilLightIsUpdated(light: light)
        }
    }

    func onToggle(light: LightEntity) {
        Task { @MainActor in
            var action = Action.turnOn
            if light.isActive {
                action = .turnOff
            }

            await apiService.setState(light: light, action: action)
            await apiService.setState(light: light, action: action)
            await reloadUntilLightIsUpdated(light: light)
        }
    }

    @MainActor
    private func reloadUntilLightIsUpdated(light: LightEntity) async {
        var updatedLight: LightEntity
        var count = 0
        repeat {
            try? await Task.sleep(seconds: 0.1)
            await updatedLight = reload(light: light)
            if light.state != updatedLight.state || light.brightness == updatedLight.brightness {
                break
            }
            count += 1
        } while count < 10

        await reload()
    }
}
