//
//  NavigatorExtension.swift
//  IntelliNest
//
//  Created by Tobias on 2023-06-03.
//

import Foundation

extension Navigator: WebSocketServiceDelegate {
    func webSocketService(didReceiveURL urlString: String, for resultID: Int) {
        camerasViewModel.setRTSPURL(urlString: urlString, for: resultID)
    }
}
