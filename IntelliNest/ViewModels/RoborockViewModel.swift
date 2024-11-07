//
//  RoborockViewModel.swift
//  IntelliNest
//
//  Created by Tobias on 2022-09-10.
//

import Foundation
import ShipBookSDK
import UIKit

class RoborockViewModel: ObservableObject {
    @Published var roborock = RoborockEntity(entityId: .roborock)
    @Published var roborockAutomation = Entity(entityId: .roborockAutomation)
    @Published var roborockLastCleanArea = Entity(entityId: .roborockLastCleanArea)
    @Published var roborockAreaSinceEmptied = Entity(entityId: .roborockAreaSinceEmptied)
    @Published var roborockEmptiedAtDate = Entity(entityId: .roborockEmptiedAtDate)
    @Published var roborockWaterShortage = Entity(entityId: .roborockWaterShortage, state: "off")
    @Published var roborockMapImage = ImageEntity(entityID: .roborockMapImage)
    @Published var isShowingMapView = false
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

    let entityIDs: [EntityId] = [.roborock, .roborockAutomation, .roborockWaterShortage, .roborockEmptiedAtDate, .roborockLastCleanArea,
                                 .roborockAreaSinceEmptied, .roborockMapImage]
    private var restAPIService: RestAPIService

    init(restAPIService: RestAPIService) {
        self.restAPIService = restAPIService
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

    func reload(entityID: EntityId, state: String, urlPath: String) {
        switch entityID {
        case .roborockMapImage:
            roborockMapImage.state = state
            roborockMapImage.urlPath = urlPath
        default:
            Log.error("RoborockViewModel doesn't reload image entity: \(entityID)")
        }
    }

    func reloadRoborock(state: String, status: String?, batteryLevel: Int?) {
        roborock.state = state
        roborock.status = status ?? ""
        roborock.batteryLevel = batteryLevel ?? -1
    }

    func locateRoborock() {
        restAPIService.update(entityID: .roborock, domain: .vacuum, action: .locate)
    }

    func manualEmpty() {
        restAPIService.callScript(scriptID: .roborockManualEmpty)
    }

    func toggleCleaning() {
        let action: Action = roborock.isCleaning ? .stop : .start
        restAPIService.update(entityID: .roborock, domain: .vacuum, action: action)
    }

    func dockRoborock() {
        if roborock.isReturning {
            restAPIService.update(entityID: .roborock, domain: .vacuum, action: .stop)
        } else {
            restAPIService.callScript(scriptID: .roborockDock)
        }
    }

    func sendRoborockToBin() {
        restAPIService.callScript(scriptID: .roborockSendToBin)
    }

    func callScript(scriptID: ScriptID) {
        restAPIService.callScript(scriptID: scriptID)
    }

    func toggleRoborockAutomation() {
        let action: Action = roborockAutomation.isActive ? .turnOff : .turnOn
        roborockAutomation.isActive.toggle()
        restAPIService.update(entityID: .roborockAutomation, domain: .automation, action: action)
    }
}
