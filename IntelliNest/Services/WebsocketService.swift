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

    init(baseURLString: String, delegate: WebSocketServiceDelegate) {
        self.delegate = delegate
        let wsUrlString = "wss://\(baseURLString.removingHTTPSchemeAndTrailingSlash)/api/websocket"
        guard let url = URL(string: wsUrlString) else {
            Log.error("Failed to create url for base url: \(wsUrlString)")
            return
        }
        let request = URLRequest(url: url)
        socket = WebSocket(request: request)
        socket?.delegate = self
        socket?.connect()
    }

    func getNextRequestID() -> Int {
        requestID += 1
        return requestID
    }

    private func sendJSONCommand(_ command: [String: Any], requestID: Int) {
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
}

extension WebSocketService: WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch event {
        case .text(let string):
            if let data = string.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let typeString = json["type"] as? String,
               let type = SocketResponseType(rawValue: typeString) {
                switch type {
                case .authOK:
                    isAuthenticated = true
                    sendRequests()
                case .authRequired:
                    sendAuthenticationMessage()
                case .result:
                    if let result = json["result"] as? [String: Any],
                       let resultID = json["id"] as? Int {
                        parseResult(result: result, resultID: resultID)
                    } else {
                        Log.error("Socket response does not contain result: \(json)")
                    }
                }
            }
        case .error(let error):
            let errorMessage = String(describing: error)
            if !errorMessage.contains("abort") {
                Log.error("Websocket error: \(String(describing: error))")
            }
        default:
            break
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

    private func parseResult(result: [String: Any], resultID: Int) {
        if let streamUrlString = result["url"] as? String {
            delegate?.webSocketService(didReceiveURL: streamUrlString, for: resultID)
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
