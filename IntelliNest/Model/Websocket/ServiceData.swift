//
//  LightServiceData.swift
//  IntelliNest
//
//  Created by Tobias on 2023-07-10.
//

import Foundation

class ServiceData: Encodable {}

class LightServiceData: ServiceData {
    let brightness: Int
    init(brightness: Int) {
        self.brightness = brightness
    }
}

class EmptyServiceData: ServiceData {}
