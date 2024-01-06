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

        if heatersViewModel.entityIDs.contains(entityID) {
            heatersViewModel.reload(entityID: entityID, state: state)
        }

        if roborockViewModel.entityIDs.contains(entityID) {
            roborockViewModel.reload(entityID: entityID, state: state)
        }

        if eniroViewModel.entityIDs.contains(entityID) {
            eniroViewModel.reload(entityID: entityID, state: state)
        }

        if electricityViewModel.entityIDs.contains(entityID) {
            electricityViewModel.reload(entityID: entityID, state: state)
        }
    }

    func webSocketService(didReceiveImage entityID: EntityId, state: String, urlPath: String) {
        roborockViewModel.reload(entityID: entityID, state: state, urlPath: urlPath)
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
        heatersViewModel.updateHeater(from: heater)
    }

    func webSocketService(didReceiveEniroGeoEntity geoEntity: EniroGeoEntity) {
        eniroViewModel.reloadGeoEntity(geoEntity: geoEntity)
    }

    func webSocketService(didReceiveNordPoolEntity nordPoolEntity: NordPoolEntity) {
        homeViewModel.reloadNordPoolEntity(nordPoolEntity: nordPoolEntity)
        electricityViewModel.reloadNordPoolEntity(nordPoolEntity: nordPoolEntity)
    }

    func webSocketService(didReceiveSonnenEntity sonnenEntity: SonnenEntity) {
        homeViewModel.reloadSonnenBattery(sonnenEntity)
        electricityViewModel.reloadSonnenBattery(sonnenEntity)
    }

    func webSocketService(didReceiveSonnenStatusEntity sonnenStatusEntity: SonnenStatusEntity) {
        homeViewModel.reloadSonnenStatusBattery(sonnenStatusEntity)
        electricityViewModel.reloadSonnenStatusBattery(sonnenStatusEntity)
    }
}

extension Navigator: URLCreatorDelegate {
    func baseURLChanged(urlString: String) {
        webSocketService.baseURLChanged(urlString: urlString)
    }
}
