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
    @Published var showingMapView = false
    @Published var showingrooms = false

    private var baseURLString: String {
        websocketService.baseURLString
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
    private var websocketService: WebSocketService
    let appearedAction: DestinationClosure

    init(websocketService: WebSocketService, appearedAction: @escaping DestinationClosure) {
        self.websocketService = websocketService
        self.appearedAction = appearedAction
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
        default:
            Log.error("HomeViewModel doesn't reload entityID: \(entityID)")
        }
    }

    func reload(entityID: EntityId, state: String, urlPath: String) {
        switch entityID {
        case .roborockMapImage:
            roborockMapImage.state = state
            roborockMapImage.urlPath = urlPath
        default:
            Log.error("HomeViewModel doesn't reload image entity: \(entityID)")
        }
    }

    func reloadRoborock(state: String, status: String?, batteryLevel: Int?) {
        roborock.state = state
        roborock.status = status ?? ""
        roborock.batteryLevel = batteryLevel ?? -1
    }

    func locateRoborock() {
        websocketService.updateEntity(entityID: .roborock, domain: .vacuum, action: .locate)
    }

    func manualEmpty() {
        websocketService.callScript(scriptID: .roborockManualEmpty)
    }

    func toggleCleaning() {
        let action: Action = roborock.isActive ? .stop : .start
        websocketService.updateEntity(entityID: .roborock, domain: .vacuum, action: action)
    }

    func dockRoborock() {
        websocketService.callScript(scriptID: .roborockDock)
    }

    func sendRoborockToBin() {
        websocketService.callScript(scriptID: .roborockSendToBin)
    }

    func callScript(scriptID: ScriptID) {
        websocketService.callScript(scriptID: scriptID)
    }

    func toggleRoborockAutomation() {
        let action: Action = roborockAutomation.isActive ? .turnOff : .turnOn
        roborockAutomation.isActive.toggle()
        websocketService.updateEntity(entityID: .roborockAutomation, domain: .automation, action: action)
    }
}
