import Foundation
import ShipBookSDK

struct CallServiceRequest: Encodable {
    let type: String
    let domain: String
    let service: String
    let target: [ServiceTargetKeys: ServiceValues]?
    let serviceData: [ServiceDataKeys: ServiceValues]?

    enum CodingKeys: String, CodingKey {
        case type
        case domain
        case service
        case serviceData = "service_data"
        case target
    }

    init(serviceID: ServiceID,
         target: [ServiceTargetKeys: ServiceValues]?,
         serviceData: [ServiceDataKeys: ServiceValues]?) {
        type = "call_service"

        let components = serviceID.rawValue.split(separator: ".")
        if components.count == 2 {
            domain = String(components[0])
            service = String(components[1])
        } else {
            domain = serviceID.rawValue
            service = serviceID.rawValue
            Log.error("ServiceID \(serviceID) does not specify domain and service")
        }

        self.target = target
        self.serviceData = serviceData
    }

    init(serviceID: ServiceID, serviceData: [ServiceDataKeys: String]?) {
        self.init(serviceID: serviceID, target: nil, serviceData: serviceData?.mapValues { .string($0) })
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(domain, forKey: .domain)
        try container.encode(service, forKey: .service)

        if let target {
            var targetContainer = container.nestedContainer(keyedBy: ServiceTargetKeys.self, forKey: .target)
            for (key, value) in target {
                try targetContainer.encode(value, forKey: key)
            }
        }

        if let serviceData {
            var serviceDataContainer = container.nestedContainer(keyedBy: ServiceDataKeys.self, forKey: .serviceData)
            for (key, value) in serviceData {
                try serviceDataContainer.encode(value, forKey: key)
            }
        }
    }
}
