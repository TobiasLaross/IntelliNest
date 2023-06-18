//
//  RoborockEntity.swift
//  IntelliNest
//
//  Created by Tobias on 2022-04-25.
//

import Foundation

struct RoborockEntity: EntityProtocol {
    var entityId: EntityId
    var state: String
    var nextUpdate = NSDate().addingTimeInterval(-1)
    var isActive: Bool = false
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
        updateIsActive()
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

        updateIsActive()
    }

    mutating func updateIsActive() {
        if state.lowercased() == "cleaning" ||
            status.lowercased() == "segment cleaning" ||
            status.lowercased() == "returning home" {
            isActive = true
        } else {
            isActive = false
        }
    }

    mutating func setNextUpdateTime() {
        nextUpdate = NSDate().addingTimeInterval(0.5)
    }

    static func == (lhs: RoborockEntity, rhs: RoborockEntity) -> Bool {
        return (lhs.entityId == rhs.entityId &&
            lhs.isActive == rhs.isActive &&
            lhs.state == rhs.state &&
            lhs.status == rhs.status)
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
