//
//  Entity.swift
//  IntelliNest
//
//  Created by Tobias on 2022-01-31.
//

import Foundation

struct Entity: EntityProtocol {
    var entityId: EntityId
    var state: String
    var lastUpdated: Date
    var lastChanged: Date
    var nextUpdate = NSDate().addingTimeInterval(-1)
    var isActive: Bool = false
    var date = Date.distantPast

    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case state
        case lastChanged = "last_changed"
        case lastUpdated = "last_updated"
    }

    init(entityId: EntityId, state: String = "Loading") {
        self.entityId = entityId
        self.state = state
        self.lastChanged = .distantPast
        self.lastUpdated = .distantPast
        updateIsActive()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entityId = try EntityId(rawValue: container.decode(String.self, forKey: .entityId))
        self.entityId = entityId ?? EntityId.unknown
        state = (try container.decodeIfPresent(String.self, forKey: .state)) ?? "Loading"

        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        if self.state.count == 8 {
            dateFormatter.dateFormat = "HH:mm:ss"
        } else {
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        }

        let optionalDate = dateFormatter.date(from: state)

        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let optionalDate = optionalDate {
            date = optionalDate
        } else {
            date = dateFormatter.date(from: state) ?? Date.distantPast
        }

        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
        if let lastChangedString = try container.decodeIfPresent(String.self, forKey: .lastChanged),
           let lastChangedDate = dateFormatter.date(from: lastChangedString) {
            self.lastChanged = lastChangedDate
        } else {
            self.lastChanged = .distantPast
        }

        if let lastUpdatedString = try container.decodeIfPresent(String.self, forKey: .lastUpdated),
           let lastUpdatedDate = dateFormatter.date(from: lastUpdatedString) {
            self.lastUpdated = lastUpdatedDate
        } else {
            self.lastUpdated = .distantPast
        }

        updateIsActive()
    }

    func recentlyUpdated() -> Bool {
        return -lastUpdated.timeIntervalSinceNow < 20 * 60
    }

    mutating func updateIsActive() {
        isActive = state.lowercased() == "on"
    }

    mutating func setNextUpdateTime() {
        nextUpdate = NSDate().addingTimeInterval(0.5)
    }

    static func == (lhs: Entity, rhs: Entity) -> Bool {
        return lhs.entityId == rhs.entityId && lhs.state == rhs.state
    }
}
