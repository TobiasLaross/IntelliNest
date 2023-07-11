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

    func webSocketService(didReceiveEntity entityID: EntityId, state: String, brightness: Int?) {
        switch entityID {
        case .allLights, .hittaSarahsIphone, .coffeeMachine, .storageLock:
            homeViewModel.reload(entityID: entityID, state: state)
        default:
            break
        }

        if lightsViewModel.lightEntities.keys.contains(entityID) {
            lightsViewModel.reload(lightID: entityID, state: state, brightness: brightness)
        }
    }
}

extension Navigator: URLCreatorDelegate {
    func baseURLChanged(urlString: String) {
        webSocketService.baseURLChanged(urlString: urlString)
    }
}
