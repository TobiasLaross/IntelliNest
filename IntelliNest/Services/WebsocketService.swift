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
    weak var delegate: WebSocketServiceDelegate?

    private var socket: WebSocket?
    private var requestID = 0
    private var requests: [String] = []
    private var shouldRetryConnection = true
    private var expectingTextTask: Task<Void, Error>?
    private var recentlySentRequests: [String] = [] {
        didSet {
            let count = recentlySentRequests.count
            if count > 10 {
                recentlySentRequests.removeFirst(count - 10)
            }
        }
    }

    var isExpectingTextResponse = false {
        didSet {
            if !isExpectingTextResponse {
                expectingTextTask?.cancel()
                expectingTextTask = nil
            }
        }
    }

    var isAuthenticated = false {
        didSet {
            if isAuthenticated {
                sendGetStatesRequest()
            } else if oldValue {
                socket?.connect()
            }
        }
    }

    var baseURLString = ""
    private var isLocalConnection: Bool {
        baseURLString == GlobalConstants.baseInternalUrlString
    }

    private let ignoredErrorMessages = ["The network connection was lost", "abort", "Socket is not connected"]

    private var reloadConnectionAction: VoidClosure
    private let setErrorBannerText: StringStringClosure

    init(reloadConnectionAction: @escaping VoidClosure, setErrorBannerText: @escaping StringStringClosure) {
        self.reloadConnectionAction = reloadConnectionAction
        self.setErrorBannerText = setErrorBannerText
    }

    func baseURLChanged(urlString: String) {
        baseURLString = urlString
        let wsURLString = if urlString == GlobalConstants.baseInternalUrlString {
            "ws://\(urlString.removingHTTPSchemeAndTrailingSlash)/api/websocket"
        } else {
            "wss://\(urlString.removingHTTPSchemeAndTrailingSlash)/api/websocket"
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
        } else if !isAuthenticated {
            socket?.connect()
        } else {
            sendGetStatesRequest()
        }
    }

    func getNextRequestID() -> Int {
        requestID += 1
        return requestID
    }

    func connect() {
        socket?.connect()
    }

    func disconnect() {
        socket?.disconnect()
        expectingTextTask?.cancel()
        expectingTextTask = nil
    }

    private func sendJSONCommand(_ command: some Encodable, requestID: Int? = nil) {
        guard var dictionary = command.dictionary else {
            Log.error("Failed to encode command to JSON: \(command)")
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
                writeToSocket(string: jsonString)
            } else {
                requests.append(jsonString)
            }
        }
    }
}

extension WebSocketService: WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client _: WebSocketClient) {
        switch event {
        case let .text(string):
            isExpectingTextResponse = false
            didReceive(text: string)
        case .disconnected:
            isAuthenticated = false
        case let .error(error):
            isAuthenticated = false
            handleWebSocketError(error)
        case let .binary(data):
            print("Received data: \(data.count)")
        case .cancelled, .peerClosed:
            isAuthenticated = false
        case let .viabilityChanged(isViable):
            if !isViable {
                isAuthenticated = false
            }
        case .reconnectSuggested:
            isAuthenticated = false
        case .connected, .ping, .pong:
            break
        }
    }

    private func handleWebSocketError(_ error: Error?) {
        reloadConnectionAction()
        let errorMessage = String(describing: error)
        if let wsError = error as? Starscream.WSError, wsError.type == .securityError {
            Log.error("Websocket security error: \(wsError.message)")
            logRecentlySentRequests()
        } else if let darwinError = error as? POSIXError, darwinError.code == .ECONNABORTED {
            recentlySentRequests.removeAll()
        } else if let darwinError = error as? POSIXError, darwinError.code == .ENOTCONN {
            let lastSentRequest = recentlySentRequests.removeLast()
            requests.append(lastSentRequest)
        } else if !ignoredErrorMessages.contains(errorMessage) {
            Log.error("Websocket error: \(String(describing: error))")
            logRecentlySentRequests()
        }
    }

    private func logRecentlySentRequests() {
        Log.error("""
        Recently sent requests:
        \(recentlySentRequests.reversed().joined(separator: "\n"))
        """)
        recentlySentRequests.removeAll()
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
            recentlySentRequests.append("type: auth, access_token: eyxxxx")
        }
    }

    private func writeToSocket(string: String) {
        socket?.write(string: string)
        recentlySentRequests.append(string)
    }

    private func onAuthenticationSuccessful() {
        isAuthenticated = true
        sendRequests()
        subscribe()
    }

    func sendGetStatesRequest() {
        expectTextResponse()
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

    func callService(serviceID: ServiceID,
                     target: [ServiceTargetKeys: ServiceValues]? = nil,
                     data: [ServiceDataKeys: ServiceValues]? = nil) {
        let callServiceRequest = CallServiceRequest(serviceID: serviceID, target: target, serviceData: data)
        sendJSONCommand(callServiceRequest)
    }

    func callService(serviceID: ServiceID, data: [ServiceDataKeys: String]? = nil) {
        let callServiceRequest = CallServiceRequest(serviceID: serviceID, serviceData: data)
        sendJSONCommand(callServiceRequest)
    }

    func removeRecentlySentRequests() {
        recentlySentRequests.removeAll()
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
            } else if entityID == .nordPool {
                let nordPoolEntity = NordPoolEntity(entityId: entityID, state: state, attributes: attributes)
                delegate?.webSocketService(didReceiveNordPoolEntity: nordPoolEntity)
            } else if entityID == .sonnenBattery {
                let sonnenEntity = SonnenEntity(entityID: entityID, state: state, attributes: attributes)
                delegate?.webSocketService(didReceiveSonnenEntity: sonnenEntity)
            } else if entityID == .sonnenBatteryStatus {
                let sonnenStatusEntity = SonnenStatusEntity(entityID: entityID, attributes: attributes)
                delegate?.webSocketService(didReceiveSonnenStatusEntity: sonnenStatusEntity)
            } else if entityID == .homeLocation,
                      let latitude = attributes["latitude"] as? Double,
                      let longitude = attributes["longitude"] as? Double {
                delegate?.webSocketService(didReceiveCoodinates: Coordinates(longitude: longitude, latitude: latitude), for: entityID)
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
            writeToSocket(string: request)
            recentlySentRequests.append(request)
        }
    }

    private func expectTextResponse() {
        expectingTextTask = Task {
            isExpectingTextResponse = true
            do {
                let sleepTime = isLocalConnection ? 0.2 : 1.0
                try await Task.sleep(seconds: sleepTime)
                if isExpectingTextResponse {
                    Log.warning("Websocket did not get expected text response, internal: \(isLocalConnection)")
                    if shouldRetryConnection {
                        shouldRetryConnection = false
                        baseURLChanged(urlString: GlobalConstants.baseExternalUrlString)
                    } else {
                        setErrorBannerText("Websocket error", "Fick inte uppdatering från websocket")
                        shouldRetryConnection = true
                    }
                }
            } catch {}
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
