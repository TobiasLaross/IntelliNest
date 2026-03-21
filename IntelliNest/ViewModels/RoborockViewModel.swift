//
//  RoborockViewModel.swift
//  IntelliNest
//
//  Created by Tobias on 2022-09-10.
//

import Foundation
import ShipBookSDK
import UIKit

@MainActor
class RoborockViewModel: ObservableObject, Reloadable {
    @Published var roborock = RoborockEntity(entityId: .roborock)
    @Published var roborockBattery = Entity(entityId: .roborockBattery)
    @Published var roborockAutomation = Entity(entityId: .roborockAutomation)
    @Published var roborockLastCleanArea = Entity(entityId: .roborockLastCleanArea)
    @Published var roborockAreaWhenEmptied = Entity(entityId: .roborockAreaWhenEmptied)
    @Published var roborockTotalCleaningArea = Entity(entityId: .roborockTotalCleaningArea)
    @Published var roborockEmptiedAtDate = Entity(entityId: .roborockEmptiedAtDate)
    @Published var roborockWaterShortage = Entity(entityId: .roborockWaterShortage, state: "off")
    @Published var roborockMapImage = RoborockImageEntity(entityId: .roborockMapImage)
    private var mapViewTask: Task<Void, Never>?

    @Published var isShowingMapView = false {
        didSet {
            mapViewTask?.cancel()
            if isShowingMapView {
                mapViewTask = Task {
                    for _ in 0 ..< 4 {
                        await reloadMapImage()
                        try? await Task.sleep(seconds: 1.5)
                        if !isShowingMapView {
                            break
                        }
                    }
                }
            }
        }
    }

    @Published var isShowingrooms = false

    private var baseURLString: String {
        restAPIService.urlString
    }

    var imagageURLString: String {
        baseURLString.removingTrailingSlash + roborockMapImage.urlPath
    }

    var cleaningAreaSinceEmptied: Double {
        (Double(roborockTotalCleaningArea.state) ?? 0) - (Double(roborockAreaWhenEmptied.state) ?? 0)
    }

    var status: String {
        let status = roborock.status.lowercased()
        let state = roborock.state.lowercased()
        if status == state || status.contains(state) {
            return status.capitalized
        } else if status == "" {
            return state.capitalized
        } else {
            return "\(roborock.state.capitalized) - \(roborock.status)"
        }
    }

    var isReloading = false
    private var isReloadingMap = false
    let entityIDs: [EntityId] = [.roborock, .roborockAutomation, .roborockWaterShortage, .roborockEmptiedAtDate, .roborockLastCleanArea,
                                 .roborockAreaWhenEmptied, .roborockTotalCleaningArea, .roborockMapImage, .roborockBattery]
    private var restAPIService: RestAPIService

    init(restAPIService: RestAPIService) {
        self.restAPIService = restAPIService
    }

    func reload() async {
        await withReloadGuard {
            let service = self.restAPIService
            let simpleEntityIDs = self.entityIDs.filter { $0 != .roborockMapImage && $0 != .roborock }
            await withTaskGroup(of: (EntityId, Entity)?.self) { group in
                group.addTask {
                    await self.reloadMapImage()
                    return nil
                }
                group.addTask {
                    await self.reloadRoborock()
                    return nil
                }
                for entityID in simpleEntityIDs {
                    group.addTask {
                        do {
                            let entity = try await service.reloadState(entityID: entityID)
                            return (entityID, entity)
                        } catch {
                            Log.error("Failed to reload entity: \(entityID): \(error)")
                            return nil
                        }
                    }
                }

                for await result in group {
                    if let (entityID, entity) = result {
                        self.reload(entityID: entityID, state: entity.state)
                    }
                }
            }
        }
    }

    private lazy var entityKeyPaths: [EntityId: ReferenceWritableKeyPath<RoborockViewModel, Entity>] = [
        .roborockAutomation: \.roborockAutomation,
        .roborockBattery: \.roborockBattery,
        .roborockLastCleanArea: \.roborockLastCleanArea,
        .roborockAreaWhenEmptied: \.roborockAreaWhenEmptied,
        .roborockTotalCleaningArea: \.roborockTotalCleaningArea,
        .roborockEmptiedAtDate: \.roborockEmptiedAtDate,
        .roborockWaterShortage: \.roborockWaterShortage,
    ]

    func reload(entityID: EntityId, state: String) {
        if let keyPath = entityKeyPaths[entityID] {
            self[keyPath: keyPath].state = state
        } else if entityID == .roborockMapImage {
            roborockMapImage.state = state
        } else {
            Log.error("RoborockViewModel doesn't reload entityID: \(entityID)")
        }
    }

    @MainActor
    func reloadMapImage() async {
        do {
            guard !isReloadingMap else {
                return
            }
            isReloadingMap = true
            let mapImage = try await restAPIService.reload(entityId: .roborockMapImage, entityType: RoborockImageEntity.self)
            roborockMapImage.urlPath = mapImage.urlPath
            roborockMapImage.state = mapImage.state
        } catch {
            Log.error("Failed to reload roborock map: \(error)")
        }
        isReloadingMap = false
    }

    @MainActor
    func reloadRoborock() async {
        do {
            let roborock = try await restAPIService.reload(entityId: .roborock, entityType: RoborockEntity.self)
            self.roborock = roborock
        } catch {
            Log.error("Failed to reload roborock: \(error)")
        }
    }

    func locateRoborock() {
        restAPIService.update(entityID: .roborock, domain: .vacuum, action: .locate, reloadTimes: 0)
    }

    func manualEmpty() {
        callScript(scriptID: .roborockManualEmpty)
    }

    func toggleCleaning() {
        let action: Action = roborock.isCleaning ? .stop : .start
        restAPIService.update(entityID: .roborock, domain: .vacuum, action: action, reloadTimes: 6)
    }

    func dockRoborock() {
        if roborock.isReturning {
            restAPIService.update(entityID: .roborock, domain: .vacuum, action: .stop, reloadTimes: 6)
        } else {
            callScript(scriptID: .roborockDock)
        }
    }

    func sendRoborockToBin() {
        callScript(scriptID: .roborockSendToBin)
    }

    func callScript(scriptID: ScriptID) {
        restAPIService.callScript(scriptID: scriptID, reloadTimes: 6)
    }

    func toggleRoborockAutomation() {
        let action: Action = roborockAutomation.isActive ? .turnOn : .turnOff // Just toggled
        restAPIService.update(entityID: .roborockAutomation, domain: .automation, action: action, reloadTimes: 2)
    }
}
