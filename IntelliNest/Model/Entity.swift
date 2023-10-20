//
//  Entity.swift
//  IntelliNest
//
//  Created by Tobias on 2022-01-31.
//

import SwiftUI

struct Entity: EntityProtocol {
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

    var entityId: EntityId
    var state: String { didSet {
        updateDate()
        updateIsActive()
    }}
    var timerEnabledIcon: Image? {
        isActive ? Image(systemImageName: .clock) : nil
    }

    init(entityId: EntityId, state: String = "Loading") {
        self.entityId = entityId
        self.state = state
        self.lastChanged = .distantPast
        self.lastUpdated = .distantPast
        updateDate()
        updateIsActive()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entityId = try EntityId(rawValue: container.decode(String.self, forKey: .entityId))
        self.entityId = entityId ?? EntityId.unknown
        state = (try container.decodeIfPresent(String.self, forKey: .state)) ?? "Loading"

        // Parsing lastChanged and lastUpdated in UTC
        let utcDateFormatter = DateFormatter()
        utcDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"

        if let lastChangedString = try container.decodeIfPresent(String.self, forKey: .lastChanged),
           let lastChangedDate = utcDateFormatter.date(from: lastChangedString) {
            self.lastChanged = lastChangedDate
        } else {
            self.lastChanged = .distantPast
        }

        if let lastUpdatedString = try container.decodeIfPresent(String.self, forKey: .lastUpdated),
           let lastUpdatedDate = utcDateFormatter.date(from: lastUpdatedString) {
            self.lastUpdated = lastUpdatedDate
        } else {
            self.lastUpdated = .distantPast
        }

        updateDate()
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

    private mutating func updateDate() {
        let localDateFormatter = DateFormatter()
        let utcDateFormatter = DateFormatter()
        utcDateFormatter.timeZone = TimeZone(abbreviation: "UTC")

        // Detect if the state contains only time or both date and time
        if state.count == 8 { // Only time (HH:mm:ss)
            localDateFormatter.dateFormat = "HH:mm:ss"
        } else { // Date and time
            localDateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        }

        date = localDateFormatter.date(from: state) ?? Date.distantPast
    }
}
