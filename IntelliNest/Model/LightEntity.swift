//
//  LightEntity.swift
//  IntelliNest
//
//  Created by Tobias on 2022-06-30.
//

import Foundation

struct LightEntity: EntityProtocol {
    var entityId: EntityId
    var state: String
    var nextUpdate = NSDate().addingTimeInterval(-1)
    var isActive: Bool = false
    var brightness: Int

    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case state
        case attributes
    }

    init(entityId: EntityId, state: String = "Loading") {
        self.entityId = entityId
        self.state = state
        self.brightness = -1
        updateIsActive()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entityId = try EntityId(rawValue: container.decode(String.self, forKey: .entityId))
        self.entityId = entityId ?? EntityId.unknown
        state = try container.decode(String.self, forKey: .state)

        let attributes = try container.decode(Attributes.self, forKey: .attributes)
        brightness = attributes.brightness
        updateIsActive()
    }

    mutating func updateIsActive() {
        isActive = state == "on" ? true : false
    }

    private enum AttributesCodingKeys: String, CodingKey {
        case brightness
    }

    private struct Attributes: Decodable {
        var brightness: Int

        init(from decoder: Decoder) throws {
            let data = try decoder.container(keyedBy: AttributesCodingKeys.self)
            self.brightness = try data.decodeIfPresent(Int.self, forKey: .brightness) ?? -1
        }
    }

    mutating func setNextUpdateTime() {
        nextUpdate = NSDate().addingTimeInterval(0.5)
    }

    static func == (lhs: LightEntity, rhs: LightEntity) -> Bool {
        return (lhs.entityId == rhs.entityId &&
            lhs.brightness == rhs.brightness &&
            lhs.isActive == rhs.isActive &&
            lhs.state == rhs.state)
    }
}
