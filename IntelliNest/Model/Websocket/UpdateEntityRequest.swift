//
//  UpdateLightRequest.swift
//  IntelliNest
//
//  Created by Tobias on 2023-06-25.
//

import Foundation

// swiftlint:disable nesting
struct UpdateEntityRequest: Encodable {
    let type = "call_service"
    let domain: Domain
    let service: Action
    var serviceData: ServiceData
    let target: Target

    enum CodingKeys: String, CodingKey {
        case type
        case domain
        case service
        case serviceData = "service_data"
        case target
    }

    struct Target: Encodable {
        let entityIds: [String]

        enum CodingKeys: String, CodingKey {
            case entityIds = "entity_id"
        }
    }

    init(domain: Domain, action: Action, serviceData: ServiceData? = nil, entityIds: [EntityId]) {
        self.domain = domain
        self.service = action
        self.serviceData = serviceData ?? EmptyServiceData()
        self.target = Target(entityIds: entityIds.map { $0.rawValue })
    }
}
