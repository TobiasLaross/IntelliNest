//
//  PreviewProviderUtil.swift
//  IntelliNest
//
//  Created by Tobias on 2024-01-25.
//

import Foundation

class PreviewProviderUtil {
    static var urlCreator = URLCreator()
    static var websocketService = WebSocketService(reloadConnectionAction: {})
    static var restAPIService = RestAPIService(urlCreator: PreviewProviderUtil.urlCreator, setErrorBannerText: { _, _ in })

    private init() {}
}
