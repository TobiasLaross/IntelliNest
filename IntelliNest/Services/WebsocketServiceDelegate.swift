//
//  WebsocketServiceDelegate.swift
//  IntelliNest
//
//  Created by Tobias on 2023-06-02.
//

import Foundation

protocol WebSocketServiceDelegate: AnyObject {
    func webSocketService(didReceiveURL urlString: String, for resultID: Int)
    func webSocketService(didReceiveEntity entityID: EntityId, state: String, lastChanged: Date?)
    func webSocketService(didReceiveImage entityID: EntityId, state: String, urlPath: String)
    func webSocketService(didReceiveLight entityID: EntityId, state: String, brightness: Int?)
    func webSocketService(didReceiveRoborock entityID: EntityId, state: String, status: String?, batteryLevel: Int?)
    func webSocketService(didReceiveHeater heater: HeaterEntity)
    func webSocketService(didReceiveEniroGeoEntity geoEntity: EniroGeoEntity)
    func webSocketService(didReceiveNordPoolEntity nordPoolEntity: NordPoolEntity)
    func webSocketService(didReceiveSonnenEntity sonnenEntity: SonnenEntity)
    func webSocketService(didReceiveSonnenStatusEntity sonnenStatusEntity: SonnenStatusEntity)
}
