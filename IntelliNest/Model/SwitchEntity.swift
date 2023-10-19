//
//  SwitchEntity.swift
//  IntelliNest
//
//  Created by Tobias on 2023-10-19.
//

import SwiftUI

struct SwitchEntity: EntityProtocol {
    var image: Image {
        isActive ? Image(systemImageName: .bolt) : Image(systemImageName: .boltSlash)
    }

    var nextUpdate = NSDate().addingTimeInterval(-1)
    var isActive: Bool {
        state.lowercased() == "on"
    }

    let entityId: EntityId
    var state: String

    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case state
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
    }

    static func == (lhs: SwitchEntity, rhs: SwitchEntity) -> Bool {
        lhs.entityId == rhs.entityId
    }
}
