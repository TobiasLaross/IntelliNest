//
//  NavigatorExtension.swift
//  IntelliNest
//
//  Created by Tobias on 2023-06-03.
//

import Foundation
import ShipBookSDK

extension Navigator: WebSocketServiceDelegate {
    func webSocketService(didReceiveURL urlString: String, for resultID: Int) {
        camerasViewModel.setRTSPURL(urlString: urlString, for: resultID)
    }

    func webSocketService(didReceiveEntity entityID: EntityId, state: String, lastChanged: Date?) {
        if homeViewModel.entityIDs.contains(entityID) {
            homeViewModel.reload(entityID: entityID, state: state, lastChanged: lastChanged)
        }

        if roborockViewModel.entityIDs.contains(entityID) {
            roborockViewModel.reload(entityID: entityID, state: state)
        }

        if eniroViewModel.entityIDs.contains(entityID) {
            eniroViewModel.reload(entityID: entityID, state: state)
        }
    }

    func webSocketService(didReceiveLight entityID: EntityId, state: String, brightness: Int?) {
        if lightsViewModel.lightEntities.keys.contains(entityID) {
            lightsViewModel.reload(lightID: entityID, state: state, brightness: brightness)
        }

        if entityID == .allLights {
            homeViewModel.reload(entityID: entityID, state: state)
        }
    }

    func webSocketService(didReceiveRoborock entityID: EntityId, state: String, status: String?, batteryLevel: Int?) {
        roborockViewModel.reloadRoborock(state: state, status: status, batteryLevel: batteryLevel)
    }

    func webSocketService(didReceiveHeater heater: HeaterEntity) {
        heatersViewModel.reloadHeater(heater)
    }

    func webSocketService(didReceiveEniroGeoEntity geoEntity: EniroGeoEntity) {
        eniroViewModel.reloadGeoEntity(geoEntity: geoEntity)
    }

    func webSocketService(didReceiveNordPoolEntity nordPoolEntity: NordPoolEntity) {
        eniroViewModel.reloadNordPoolEntity(nordPoolEntity: nordPoolEntity)
    }
}

extension Navigator: URLCreatorDelegate {
    func baseURLChanged(urlString: String) {
        webSocketService.baseURLChanged(urlString: urlString)
    }
}
