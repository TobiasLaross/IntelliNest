//
//  PreviewProvideUtil.swift
//  IntelliNest
//
//  Created by Tobias on 2024-01-25.
//

import Foundation

@MainActor
class PreviewProviderUtil {
    static var urlCreator = URLCreator()
    static var websocketService = WebSocketService(reloadConnectionAction: {}, setErrorBannerText: { _, _ in }, setConnectionInfo: { _ in })
    static var restAPIService = RestAPIService(urlCreator: PreviewProviderUtil.urlCreator, setErrorBannerText: { _, _ in })
    static var electricityViewModel = ElectricityViewModel(sonnenBattery: .init(entityID: .sonnenBattery),
                                                           restAPIService: PreviewProviderUtil.restAPIService,
                                                           websocketService: PreviewProviderUtil.websocketService)
    static var heatersViewModel = HeatersViewModel(restAPIService: restAPIService, showHeaterDetails: { _ in })

    private init() {}
}
