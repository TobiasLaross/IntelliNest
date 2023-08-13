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

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(brightness, forKey: .brightness)
    }

    private enum CodingKeys: String, CodingKey {
        case brightness
    }
}

class EmptyServiceData: ServiceData {}
