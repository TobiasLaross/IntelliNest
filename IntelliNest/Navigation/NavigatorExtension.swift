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
        switch entityID.type {
        case .light:
            if entityID == .allLights {
                homeViewModel.reload(entityID: entityID, state: state)
            } else if lightsViewModel.lightEntities.keys.contains(entityID) {
                lightsViewModel.reload(lightID: entityID, state: state, brightness: brightness)
            }
        default:
//            Log.warning("Web socket delegate not implemented get state for \(entityID.rawValue)")
            break
        }
    }
}

extension Navigator: URLCreatorDelegate {
    func baseURLChanged(urlString: String) {
        webSocketService.baseURLChanged(urlString: urlString)
    }
}
