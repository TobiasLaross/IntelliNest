//
//  WebsocketService.swift
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

    init() {}

    func baseURLChanged(urlString: String) {
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

    private func sendJSONCommand(_ command: [String: Any], requestID: Int) {
        // Replace with encodable
        var mutableCommand = command
        mutableCommand["id"] = requestID
        if let jsonData = try? JSONSerialization.data(withJSONObject: mutableCommand, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            if isAuthenticated {
                socket?.write(string: jsonString)
            } else {
                requests.append(jsonString)
            }
        }
    }

    private func sendJSONCommand<T: Encodable>(_ command: T, requestID: Int) {
        guard var dictionary = command.dictionary else {
            Log.error("Failed to encode command to JSON")
            return
        }
        dictionary["id"] = requestID

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
            if !errorMessage.contains("abort") {
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
        let getStatesRequest: [String: Any] = [
            "type": "get_states"
        ]
        let requestID = getNextRequestID()
        sendJSONCommand(getStatesRequest, requestID: requestID)
    }

    func updateLights(lightIDs: [EntityId], action: Action, brightness: Int) {
        let updateLightRequest = UpdateLightRequest(action: action, brightness: brightness, lightIDs: lightIDs)
        let requestID = getNextRequestID()
        sendJSONCommand(updateLightRequest, requestID: requestID)
    }

    private func subscribe() {
        let requestID = getNextRequestID()
        let subscribeRequest = SubscribeRequest(eventType: .stateChange)

        sendJSONCommand(subscribeRequest, requestID: requestID)
    }

    private func parseDictionaryResult(result: [String: Any], resultID: Int) {
        if let streamUrlString = result["url"] as? String {
            delegate?.webSocketService(didReceiveURL: streamUrlString, for: resultID)
        }
    }

    private func parseResultsArray(result: [[String: Any]]) {
        for dictionary in result {
            if let entityIDString = dictionary["entity_id"] as? String,
               let entityID = EntityId(rawValue: entityIDString),
               let state = dictionary["state"] as? String {
                let attributes = dictionary["attributes"] as? [String: Any]
                let brightness = attributes?["brightness"] as? Int
                delegate?.webSocketService(didReceiveEntity: entityID, state: state, brightness: brightness)
            }
        }
    }

    private func parseStateChange(newState: [String: Any]) {
        if let entityIDString = newState["entity_id"] as? String,
           let entityID = EntityId(rawValue: entityIDString),
           let state = newState["state"] as? String {
            var brightness: Int?
            if let attributes = newState["attributes"] as? [String: Any] {
                brightness = attributes["brightness"] as? Int
            }

            delegate?.webSocketService(didReceiveEntity: entityID, state: state, brightness: brightness)
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
        let cameraStreamRequest: [String: Any] = [
            "type": "camera/stream",
            "entity_id": "\(cameraEntityID.rawValue)"
        ]
        let requestID = getNextRequestID()
        sendJSONCommand(cameraStreamRequest, requestID: requestID)
        return requestID
    }
}

extension String {
    var removingHTTPSchemeAndTrailingSlash: String {
        self.replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "https://", with: "").removingTrailingSlash
    }

    var removingTrailingSlash: String {
        if self.hasSuffix("/") {
            return String(self.dropLast())
        }
        return self
    }
}
