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
class RoborockViewModel: ObservableObject {
    @Published var roborock = RoborockEntity(entityId: .roborock)
    @Published var roborockAutomation = Entity(entityId: .roborockAutomation)
    @Published var roborockLastCleanArea = Entity(entityId: .roborockLastCleanArea)
    @Published var roborockAreaSinceEmptied = Entity(entityId: .roborockAreaSinceEmptied)
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

    private var isReloading = false
    private var isReloadingMap = false
    let entityIDs: [EntityId] = [.roborock, .roborockAutomation, .roborockWaterShortage, .roborockEmptiedAtDate, .roborockLastCleanArea,
                                 .roborockAreaSinceEmptied, .roborockMapImage]
    private var restAPIService: RestAPIService

    init(restAPIService: RestAPIService) {
        self.restAPIService = restAPIService
    }

    func reload() async {
        guard !isReloading else {
            return
        }

        isReloading = true
        for entityID in entityIDs {
            do {
                if entityID == .roborockMapImage {
                    await reloadMapImage()
                } else if entityID == .roborock {
                    await reloadRoborock()
                } else {
                    let entity = try await restAPIService.reloadState(entityID: entityID)
                    reload(entityID: entityID, state: entity.state)
                }
            } catch {
                Log.error("Failed to reload entity: \(entityID): \(error)")
            }
        }
        isReloading = false
    }

    func reload(entityID: EntityId, state: String) {
        switch entityID {
        case .roborockAutomation:
            roborockAutomation.state = state
        case .roborockLastCleanArea:
            roborockLastCleanArea.state = state
        case .roborockAreaSinceEmptied:
            roborockAreaSinceEmptied.state = state
        case .roborockEmptiedAtDate:
            roborockEmptiedAtDate.state = state
        case .roborockWaterShortage:
            roborockWaterShortage.state = state
        case .roborockMapImage:
            roborockMapImage.state = state
        default:
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

    func reloadRoborock(state: String, status: String?, batteryLevel: Int?) {
        roborock.state = state
        roborock.status = status ?? ""
        roborock.batteryLevel = batteryLevel ?? -1
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
        let action: Action = roborockAutomation.isActive ? .turnOff : .turnOn
        roborockAutomation.isActive.toggle()
        restAPIService.update(entityID: .roborockAutomation, domain: .automation, action: action, reloadTimes: 2)
    }
}
