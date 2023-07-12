//
//  CallScriptRequest.swift
//  IntelliNest
//
//  Created by Tobias on 2023-07-11.
//

import Foundation

// swiftlint:disable nesting
struct CallScriptRequest: Encodable {
    let type = "call_service"
    let domain = Domain.script
    let service = Action.turnOn
    var serviceData = EmptyServiceData()
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

    init(scriptID: ScriptID) {
        self.target = Target(entityIds: [scriptID.rawValue])
    }
}
