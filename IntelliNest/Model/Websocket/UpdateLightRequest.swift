//
//  UpdateLightRequest.swift
//  IntelliNest
//
//  Created by Tobias on 2023-06-25.
//

import Foundation

// swiftlint:disable nesting
struct UpdateLightRequest: Encodable {
    let type = "call_service"
    let domain = "light"
    let service: Action
    let serviceData: ServiceData?
    let target: Target

    enum CodingKeys: String, CodingKey {
        case type
        case domain
        case service
        case serviceData = "service_data"
        case target
    }

    struct ServiceData: Encodable {
        let brightness: Int
    }

    struct Target: Encodable {
        let lightIDs: [String]

        enum CodingKeys: String, CodingKey {
            case lightIDs = "entity_id"
        }
    }

    init(action: Action, brightness: Int, lightIDs: [EntityId]) {
        service = action

        if action == .turnOn {
            serviceData = ServiceData(brightness: brightness)
        } else {
            serviceData = nil
        }
        target = Target(lightIDs: lightIDs.map { $0.rawValue })
    }
}
