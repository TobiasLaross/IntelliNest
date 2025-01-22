//
//  RoborockImageEntity.swift
//  IntelliNest
//
//  Created by Tobias on 2023-12-11.
//

import Foundation

struct RoborockImageEntity: EntityProtocol {
    let entityId: EntityId
    var state = ""
    var urlPath = ""
    var nextUpdate = Date.now
    var isActive = false

    init(entityId: EntityId) {
        self.entityId = entityId
    }

    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case state
        case attributes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entityId = try EntityId(rawValue: container.decode(String.self, forKey: .entityId))
        self.entityId = entityId ?? EntityId.unknown
        state = try container.decode(String.self, forKey: .state)

        let attributes = try container.decode(RoborockImageAttributes.self, forKey: .attributes)
        urlPath = attributes.entityPicture
    }
}

struct RoborockImageAttributes: Decodable {
    let entityPicture: String

    enum CodingKeys: String, CodingKey {
        case entityPicture = "entity_picture"
    }
}
