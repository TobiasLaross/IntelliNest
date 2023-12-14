//  WebsocketService.swift
//
//  IntelliNest
//
//  Created by Tobias on 2023-06-02.
//

import Foundation
import ShipBookSDK
import Starscream

enum SocketResponseType: String {
    case result
    case authOK = "auth_ok"
    case authRequired = "auth_required"
    case event
}

protocol WebsocketServiceProtocol {
    @discardableResult
    func sendCameraStreamRequest(for cameraEntityID: EntityId) -> Int
}

class WebSocketService {
    var socket: WebSocket?
    weak var delegate: WebSocketServiceDelegate?
    var requestID = 0
    var requests: [String] = []
    var isAuthenticated = false
    var baseURLString = ""
    private let ignoredErrorMessages = ["The network connection was lost", "abort", "Socket is not connected"]

    init() {}

    func baseURLChanged(urlString: String) {
        baseURLString = urlString
        let wsURLString: String
        if urlString == GlobalConstants.baseInternalUrlString {
            wsURLString = "ws://\(urlString.removingHTTPSchemeAndTrailingSlash)/api/websocket"
        } else {
            wsURLString = "wss://\(urlString.removingHTTPSchemeAndTrailingSlash)/api/websocket"
        }
        guard let url = URL(string: wsURLString) else {
            Log.error("Failed to create url for base url: \(wsURLString)")
            return
        }

        if socket?.request.url != url {
            socket?.disconnect()
            let request = URLRequest(url: url)
            socket = WebSocket(request: request)
            socket?.delegate = self
            socket?.connect()
        }
    }

    func getNextRequestID() -> Int {
        requestID += 1
        return requestID
    }

    func connect() {
        socket?.connect()
    }

    private func sendJSONCommand<T: Encodable>(_ command: T, requestID: Int? = nil) {
        guard var dictionary = command.dictionary else {
            Log.error("Failed to encode command to JSON")
            return
        }
        if let requestID {
            dictionary["id"] = requestID
        } else {
            dictionary["id"] = getNextRequestID()
        }

        if let jsonData = try? JSONSerialization.data(withJSONObject: dictionary, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            if isAuthenticated {
                socket?.write(string: jsonString)
            } else {
                requests.append(jsonString)
            }
        }
    }
}

extension WebSocketService: WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch event {
        case .text(let string):
            didReceive(text: string)
        case .disconnected:
            socket?.connect()
        case .error(let error):
            let errorMessage = String(describing: error)
            if !ignoredErrorMessages.contains(errorMessage) {
                Log.error("Websocket error: \(String(describing: error))")
            }
        default:
            break
        }
    }

    private func didReceive(text: String) {
        if let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let typeString = json["type"] as? String,
           let type = SocketResponseType(rawValue: typeString) {
            switch type {
            case .authOK:
                onAuthenticationSuccessful()
            case .authRequired:
                sendAuthenticationMessage()
            case .result:
                if let result = json["result"] as? [String: Any],
                   let resultID = json["id"] as? Int {
                    parseDictionaryResult(result: result, resultID: resultID)
                } else if let result = json["result"] as? [[String: Any]] {
                    parseResultsArray(result: result)
                }
            case .event:
                if let event = json["event"] as? [String: Any],
                   let data = event["data"] as? [String: Any],
                   let newState = data["new_state"] as? [String: Any] {
                    parseStateChange(newState: newState)
                }
            }
        }
    }

    private func sendAuthenticationMessage() {
        let authMessage: [String: Any] = [
            "type": "auth",
            "access_token": "\(GlobalConstants.secretHassToken)"
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: authMessage, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            socket?.write(string: jsonString)
        }
    }

    private func onAuthenticationSuccessful() {
        sendGetStatesRequest()
        isAuthenticated = true
        sendRequests()
        subscribe()
    }

    func sendGetStatesRequest() {
        let getStatesRequest = ["type": "get_states"]
        sendJSONCommand(getStatesRequest)
    }

    func updateLights(lightIDs: [EntityId], action: Action, brightness: Int) {
        var updateEntityRequest = UpdateEntityRequest(domain: .light, action: action, entityIds: lightIDs)
        if action == .turnOn {
            let lightData = LightServiceData(brightness: brightness)
            updateEntityRequest.serviceData = lightData
        }

        sendJSONCommand(updateEntityRequest)
    }

    func updateEntity(entityID: EntityId, domain: Domain, action: Action) {
        let updateEntityRequest = UpdateEntityRequest(domain: domain, action: action, entityIds: [entityID])
        sendJSONCommand(updateEntityRequest)
    }

    func updateHeaterTemperature(heaterID: EntityId, temperature: Double) {
        let serviceData = ClimateServiceData(targetTemperature: temperature)
        var updateEntityRequest = UpdateEntityRequest(domain: .climate, action: .setTemperature, entityIds: [heaterID])
        updateEntityRequest.serviceData = serviceData
        sendJSONCommand(updateEntityRequest)
    }

    func updateHeaterHvacMode(heaterID: EntityId, hvacMode: HvacMode) {
        let serviceData = ClimateServiceData(hvacMode: hvacMode)
        var updateEntityRequest = UpdateEntityRequest(domain: .climate, action: .setHvacMode, entityIds: [heaterID])
        updateEntityRequest.serviceData = serviceData
        sendJSONCommand(updateEntityRequest)
    }

    func updateHeaterFanMode(heaterID: EntityId, fanMode: HeaterFanMode) {
        let serviceData = ClimateServiceData(fanMode: fanMode)
        var updateEntityRequest = UpdateEntityRequest(domain: .climate, action: .setFanMode, entityIds: [heaterID])
        updateEntityRequest.serviceData = serviceData
        sendJSONCommand(updateEntityRequest)
    }

    func updateHeaterHorizontalMode(heaterID: EntityId, horizontalMode: HeaterHorizontalMode) {
        let serviceData = MelcloudServiceData(horizontalMode: horizontalMode)
        var updateEntityRequest = UpdateEntityRequest(domain: .melcloud, action: .setVaneHorizontal, entityIds: [heaterID])
        updateEntityRequest.serviceData = serviceData
        sendJSONCommand(updateEntityRequest)
    }

    func updateHeaterVerticalMode(heaterID: EntityId, verticalMode: HeaterVerticalMode) {
        let serviceData = MelcloudServiceData(verticalMode: verticalMode)
        var updateEntityRequest = UpdateEntityRequest(domain: .melcloud, action: .setVaneVertical, entityIds: [heaterID])
        updateEntityRequest.serviceData = serviceData
        sendJSONCommand(updateEntityRequest)
    }

    func updateInputNumberEntity(entityId: EntityId, value: Double) {
        var updateEntityRequest = UpdateEntityRequest(domain: .inputNumber, action: .setValue, entityIds: [entityId])
        let serviceData = InputNumberServiceData(value: value)
        updateEntityRequest.serviceData = serviceData
        sendJSONCommand(updateEntityRequest)
    }

    func updateDateTimeEntity(entity: Entity) {
        var updateEntityRequest = UpdateEntityRequest(domain: .inputDateTime, action: .setDateTime, entityIds: [entity.entityId])
        let serviceData = DateTimeServiceData(date: entity.date)
        updateEntityRequest.serviceData = serviceData
        sendJSONCommand(updateEntityRequest)
    }

    func callScript(scriptID: ScriptID, variables: [ScriptVariableKeys: String]? = nil) {
        let callScriptRequest = CallScriptRequest(scriptID: scriptID, variables: variables)
        sendJSONCommand(callScriptRequest)
    }

    func callService(serviceID: ServiceID, variables: [ServiceVariableKeys: VariableValue]? = nil) {
        let callServiceRequest = CallServiceRequest(serviceID: serviceID, serviceData: variables)
        sendJSONCommand(callServiceRequest)
    }

    func callService(serviceID: ServiceID, variables: [ServiceVariableKeys: String]? = nil) {
        let callServiceRequest = CallServiceRequest(serviceID: serviceID, serviceData: variables)
        sendJSONCommand(callServiceRequest)
    }

    private func subscribe() {
        let subscribeRequest = SubscribeRequest(eventType: .stateChange)
        sendJSONCommand(subscribeRequest)
    }

    private func parseDictionaryResult(result: [String: Any], resultID: Int) {
        if let streamUrlString = result["url"] as? String {
            delegate?.webSocketService(didReceiveURL: streamUrlString, for: resultID)
        }
    }

    private func parseResultsArray(result: [[String: Any]]) {
        for dictionary in result {
            parseStateChange(newState: dictionary)
        }
    }

    private func parseStateChange(newState: [String: Any]) {
        if let entityIDString = newState["entity_id"] as? String,
           let entityID = EntityId(rawValue: entityIDString),
           let state = newState["state"] as? String {
            let attributes = newState["attributes"] as? [String: Any] ?? [:]
            if entityID == .roborock {
                let status = attributes["status"] as? String
                let batteryLevel = attributes["battery_level"] as? Int
                delegate?.webSocketService(didReceiveRoborock: entityID, state: state, status: status, batteryLevel: batteryLevel)
            } else if entityID.type == .image, let urlPath = attributes["entity_picture"] as? String {
                delegate?.webSocketService(didReceiveImage: entityID, state: state, urlPath: urlPath)
            } else if entityID.type == .light {
                let brightness = attributes["brightness"] as? Int
                delegate?.webSocketService(didReceiveLight: entityID, state: state, brightness: brightness)
            } else if entityID == .heaterCorridor || entityID == .heaterPlayroom {
                let heater = HeaterEntity(entityID: entityID, state: state, attributes: newState)
                delegate?.webSocketService(didReceiveHeater: heater)
            } else if entityID == .eniroGeoLocation {
                let addressDict = attributes["address"] as? [String: Any] ?? [:]
                let eniroGeoEntity = EniroGeoEntity(entityId: .eniroGeoLocation, state: state, addressDict: addressDict)
                delegate?.webSocketService(didReceiveEniroGeoEntity: eniroGeoEntity)
            } else if entityID == .nordPool {
                let nordPoolEntity = NordPoolEntity(entityId: entityID, state: state, attributes: attributes)
                delegate?.webSocketService(didReceiveNordPoolEntity: nordPoolEntity)
            } else {
                let lastChangedString = newState["last_changed"] as? String
                let lastChanged = Date.fromISO8601(lastChangedString)
                delegate?.webSocketService(didReceiveEntity: entityID, state: state, lastChanged: lastChanged)
            }
        }
    }

    private func sendRequests() {
        while !requests.isEmpty {
            let request = requests.removeFirst()
            socket?.write(string: request)
        }
    }
}

extension WebSocketService: WebsocketServiceProtocol {
    @discardableResult
    func sendCameraStreamRequest(for cameraEntityID: EntityId) -> Int {
        let requestID = getNextRequestID()
        let serviceRequest = CallServiceRequest(serviceID: .cameraStream, serviceData: [.entityID: cameraEntityID.rawValue])
        sendJSONCommand(serviceRequest, requestID: requestID)
        return requestID
    }
}

extension String {
    var removingHTTPSchemeAndTrailingSlash: String {
        replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "https://", with: "").removingTrailingSlash
    }

    var removingTrailingSlash: String {
        if hasSuffix("/") {
            return String(dropLast())
        }
        return self
    }
}
