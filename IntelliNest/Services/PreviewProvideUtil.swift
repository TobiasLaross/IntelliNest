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
    static var restAPIService = RestAPIService(urlCreator: PreviewProviderUtil.urlCreator, setErrorBannerText: { _, _ in },
                                               repeatReloadAction: { _ in })
    static var electricityViewModel = ElectricityViewModel(sonnenBattery: .init(entityID: .sonnenBattery),
                                                           restAPIService: PreviewProviderUtil.restAPIService)
    static var heatersViewModel = HeatersViewModel(restAPIService: restAPIService, showHeaterDetails: { _ in })
    static var lynkViewModel = LynkViewModel(restAPIService: restAPIService)

    private init() {}
}
