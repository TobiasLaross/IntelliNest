//
//  CameraEntity.swift
//  IntelliNest
//
//  Created by Tobias on 2022-06-18.
//

import Foundation

struct CameraEntity: EntityProtocol {
    var entityId: EntityId
    var state: String
    var nextUpdate = NSDate().addingTimeInterval(-1)
    var isActive: Bool = false
    var isLoading: Bool = false
    // var imageUrlString: String = ""
    var urlPath = ""

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

        let attributes = try container.decode(CameraAttributes.self, forKey: .attributes)
        urlPath = attributes.urlPath
    }

    mutating func setNextUpdateTime() {
        nextUpdate = NSDate().addingTimeInterval(-1)
    }

    mutating func updateIsActive() {
        isActive.toggle()
    }

    static func == (lhs: CameraEntity, rhs: CameraEntity) -> Bool {
        false
    }
}

struct CameraAttributes: Decodable {
    var urlPath: String

    enum CodingKeys: String, CodingKey {
        case urlPath = "entity_picture"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        urlPath = try container.decode(String.self, forKey: .urlPath)
    }
}
