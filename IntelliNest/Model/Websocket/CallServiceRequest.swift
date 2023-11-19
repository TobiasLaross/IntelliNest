//
//  CallServiceRequest.swift
//  IntelliNest
//
//  Created by Tobias on 2023-11-17.
//

import Foundation
import ShipBookSDK

struct CallServiceRequest: Encodable {
    let type: String
    let domain: String
    let service: String
    let serviceData: [ServiceVariableKeys: VariableValue]?

    enum CodingKeys: String, CodingKey {
        case type
        case domain
        case service
        case serviceData = "service_data"
    }

    init(serviceID: ServiceID, serviceData: [ServiceVariableKeys: VariableValue]?) {
        type = "call_service"

        let components = serviceID.rawValue.split(separator: ".")
        guard components.count == 2 else {
            fatalError("Invalid ServiceID format: \(serviceID.rawValue)")
        }

        domain = String(components[0])
        service = String(components[1])
        self.serviceData = serviceData
    }

    init(serviceID: ServiceID, serviceData: [ServiceVariableKeys: String]?) {
        self.init(serviceID: serviceID, serviceData: serviceData?.mapValues { .string($0) })
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(domain, forKey: .domain)
        try container.encode(service, forKey: .service)

        if let serviceData {
            var serviceDataContainer = container.nestedContainer(keyedBy: ServiceVariableKeys.self, forKey: .serviceData)
            for (key, value) in serviceData {
                try serviceDataContainer.encode(value, forKey: key)
            }
        }
    }
}
