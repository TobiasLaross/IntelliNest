//
//  WebsocketServiceDelegate.swift
//  IntelliNest
//
//  Created by Tobias on 2023-06-02.
//

import Foundation

protocol WebSocketServiceDelegate: AnyObject {
    func webSocketService(didReceiveURL urlString: String, for resultID: Int)
}
