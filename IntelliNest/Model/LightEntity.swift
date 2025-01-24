//
//  LightEntity.swift
//  IntelliNest
//
//  Created by Tobias on 2022-06-30.
//

import Foundation

struct LightEntity: EntityProtocol, Decodable {
    var entityId: EntityId
    var state: String
    var nextUpdate = Date().addingTimeInterval(-1)
    var isActive: Bool {
        state == "on" ? true : false
    }

    var isSliding = false
    var isUpdating = false

    var brightness: Int
    var groupedLightIDs: [EntityId]?

    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case state
        case attributes
    }

    init(entityId: EntityId, state: String = "Loading", groupedLightIDs: [EntityId]? = nil) {
        self.entityId = entityId
        self.state = state
        brightness = -1
        self.groupedLightIDs = groupedLightIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        entityId = try container.decode(EntityId.self, forKey: .entityId)
        state = try container.decode(String.self, forKey: .state)

        if let attributesContainer = try? container.nestedContainer(keyedBy: AttributesCodingKeys.self, forKey: .attributes) {
            brightness = try attributesContainer.decodeIfPresent(Int.self, forKey: .brightness) ?? -1
        } else {
            brightness = -1
        }
        groupedLightIDs = nil
    }

    mutating func updateIsActive() {}

    private enum AttributesCodingKeys: String, CodingKey {
        case brightness
    }

    private struct Attributes: Decodable {
        var brightness: Int

        init(from decoder: Decoder) throws {
            let data = try decoder.container(keyedBy: AttributesCodingKeys.self)
            brightness = try data.decodeIfPresent(Int.self, forKey: .brightness) ?? -1
        }
    }

    mutating func setNextUpdateTime() {
        nextUpdate = Date().addingTimeInterval(0.5)
    }

    static func == (lhs: LightEntity, rhs: LightEntity) -> Bool {
        lhs.entityId == rhs.entityId &&
            lhs.brightness == rhs.brightness &&
            lhs.isActive == rhs.isActive &&
            lhs.state == rhs.state
    }
}
