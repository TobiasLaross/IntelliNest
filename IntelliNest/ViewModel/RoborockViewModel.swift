//
//  RoborockViewModel.swift
//  IntelliNest
//
//  Created by Tobias on 2022-09-10.
//

import Foundation
import ShipBookSDK
import UIKit

class RoborockViewModel: HassViewModelProtocol {
    @Published var roborock = RoborockEntity(entityId: .roborock)
    @Published var roborockAutomation = Entity(entityId: .roborockAutomation)
    @Published var roborockLastCleanArea = Entity(entityId: .roborockLastCleanArea)
    @Published var roborockAreaSinceEmpty = Entity(entityId: .roborockAreaSinceEmptied)
    @Published var roborockEmptiedAtDate = Entity(entityId: .roborockEmptiedAtDate)
    @Published var roborockWaterShortage = Entity(entityId: .roborockWaterShortage, state: "off")
    @Published var showingMapView = false
    @Published var mapImage: UIImage?
    @Published var mapImage2: UIImage?

    var roborockSendToBin = Entity(entityId: .roborockSendToBin)
    var roborockKitchen = Entity(entityId: .roborockKitchen)
    var roborockKitchenTable = Entity(entityId: .roborockKitchenTable)
    var roborockKitchenStove = Entity(entityId: .roborockKitchenStove)
    var roborockLaundry = Entity(entityId: .roborockLaundry)
    var roborockHallway = Entity(entityId: .roborockHallway)
    var roborockCorridor = Entity(entityId: .roborockCorridor)
    var roborockLivingroom = Entity(entityId: .roborockLivingroom)
    var roborockGym = Entity(entityId: .roborockGym)
    var roborockVinceRoom = Entity(entityId: .roborockVinceRoom)
    var roborockBedroom = Entity(entityId: .roborockBedroom)
    private var isReloading = false
    var urlCreator: URLCreator {
        apiService.urlCreator
    }

    private var apiService: HassApiService
    let appearedAction: DestinationClosure

    init(apiService: HassApiService, appearedAction: @escaping DestinationClosure) {
        self.apiService = apiService
        self.appearedAction = appearedAction
    }

    @MainActor
    func reload() async {
        if !isReloading {
            isReloading = true
            async let tmpRoborock = reload(roborock: roborock)
            async let tmpRoborockAutomation = reload(entity: roborockAutomation)
            async let tmpRoborockLastCleanArea = reload(entity: roborockLastCleanArea)
            async let tmpRoborockAreaSinceEmpty = reload(entity: roborockAreaSinceEmpty)
            async let tmpRoborockEmptiedAtDate = reload(entity: roborockEmptiedAtDate)
            async let tmpRoborockWaterShortage = reload(entity: roborockWaterShortage)
            roborock = await tmpRoborock
            roborockAutomation = await tmpRoborockAutomation
            roborockLastCleanArea = await tmpRoborockLastCleanArea
            roborockAreaSinceEmpty = await tmpRoborockAreaSinceEmpty
            roborockEmptiedAtDate = await tmpRoborockEmptiedAtDate
            roborockWaterShortage = await tmpRoborockWaterShortage
            isReloading = false
        }
    }

    func locateRoborock() {
        Task {
            await apiService.setState(roborock: roborock, action: .locate)
        }
    }

    func manualEmpty() {
        Task { @MainActor in
            await apiService.callScript(entityId: .roborockManualEmpty)
            await reloadAfterSleep()
        }
    }

    func toggleCleaning() {
        Task { @MainActor in
            let action: Action = roborock.isActive ? .stop : .start
            await apiService.setState(roborock: roborock, action: action)
            await reloadUntilUpdated(roborock: roborock)
        }
    }

    func dockRoborock() {
        callScript(entityID: .roborockDock)
    }

    func sendRoborockToBin() {
        callScript(entityID: .roborockSendToBin)
    }

    func callScript(entityID: EntityId) {
        Task { @MainActor in
            await apiService.callScript(entityId: entityID)
            await reloadUntilUpdated(roborock: roborock)
        }
    }

    func setState(for entity: Entity) {
        Task { @MainActor in
            let action = entity.isActive ? Action.turnOn : Action.turnOff
            await apiService.setState(for: entity.entityId, in: entity.entityId.domain(), using: action)
            await reloadAfterSleep()
        }
    }

    func getStatus() -> String {
        if roborock.status.contains(roborock.state) {
            return "\(roborock.status.capitalized)"
        } else {
            return "\(roborock.state.capitalized) - \(roborock.status)"
        }
    }

    @MainActor
    private func reloadUntilUpdated(roborock: RoborockEntity) async {
        var updatedRoborock: RoborockEntity
        var count = 0
        repeat {
            try? await Task.sleep(seconds: 0.8)
            await updatedRoborock = reload(roborock: roborock)
            count += 1
            if roborock.state != updatedRoborock.state {
                break
            }
        } while count < 40

        await reload()
    }

    @MainActor
    private func reloadAfterSleep() async {
        try? await Task.sleep(seconds: 0.3)
        await reload()
    }

    private func reload(roborock: RoborockEntity) async -> RoborockEntity {
        return await apiService.reload(hassEntity: roborock, entityType: RoborockEntity.self)
    }

    private func reload(entity: Entity) async -> Entity {
        return await apiService.reload(hassEntity: entity, entityType: Entity.self)
    }
}
