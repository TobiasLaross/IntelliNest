//
//  RoborockEntity.swift
//  IntelliNest
//
//  Created by Tobias on 2022-04-25.
//

import SwiftUI

struct RoborockEntity: EntityProtocol {
    let entityId: EntityId
    var state: String

    var nextUpdate = Date().addingTimeInterval(-1)
    var isActive: Bool {
        isCleaning || isReturning
    }

    var isCleaning: Bool {
        ["cleaning", "segment cleaning"].contains { $0 == state.lowercased() || $0 == status.lowercased() }
    }

    var isReturning: Bool {
        ["returning home", "returning"].contains { $0 == state.lowercased() || $0 == status.lowercased() }
    }

    var cleanIcon: Image {
        isCleaning ? .init(systemImageName: .pause) : .init(systemImageName: .play)
    }

    var cleanButtonTitle: String {
        isCleaning ? "Pausa" : "Dammsug"
    }

    var returningIcon: Image {
        isReturning ? .init(systemImageName: .pause) : .init(systemImageName: .house)
    }

    var returnButtonTitle: String {
        isReturning ? "Pausa" : "Docka"
    }

    var status: String = ""

    var batteryLevel: Int = -1
    var error: String = ""

    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case state
        case attributes
    }

    init(entityId: EntityId, state: String = "Loading") {
        self.entityId = entityId
        self.state = state
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entityId = try EntityId(rawValue: container.decode(String.self, forKey: .entityId))
        self.entityId = entityId ?? EntityId.unknown
        state = try container.decode(String.self, forKey: .state)
        let attributes = try container.decode(RoborockAttributes.self, forKey: .attributes)
        status = attributes.status
        batteryLevel = attributes.batteryLevel
        error = attributes.error
    }

    static func == (lhs: RoborockEntity, rhs: RoborockEntity) -> Bool {
        lhs.entityId == rhs.entityId &&
            lhs.isActive == rhs.isActive &&
            lhs.state == rhs.state &&
            lhs.status == rhs.status
    }
}

private struct RoborockAttributes: Decodable {
    var status: String
    var batteryLevel: Int
    var error: String

    private enum CodingKeys: String, CodingKey {
        case status
        case batteryLevel = "battery_level"
        case error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(String.self, forKey: .status)
        batteryLevel = try container.decode(Int.self, forKey: .batteryLevel)
        error = try container.decodeIfPresent(String.self, forKey: .error) ?? ""
    }
}
