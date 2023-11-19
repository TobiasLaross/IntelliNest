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
    var isActive: Bool {
        get { state.lowercased() == "on" }
        set { state = newValue ? "on" : "off" }
    }

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
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entityId = try EntityId(rawValue: container.decode(String.self, forKey: .entityId))
        self.entityId = entityId ?? EntityId.unknown
        state = try (container.decodeIfPresent(String.self, forKey: .state)) ?? "Loading"

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
    }

    func recentlyUpdated() -> Bool {
        return -lastUpdated.timeIntervalSinceNow < 20 * 60
    }

    mutating func setNextUpdateTime() {
        nextUpdate = NSDate().addingTimeInterval(0.5)
    }

    static func == (lhs: Entity, rhs: Entity) -> Bool {
        return lhs.entityId == rhs.entityId && lhs.state == rhs.state
    }

    private mutating func updateDate() {
        guard !state.isEmpty, state.contains(where: { $0 == "T" || $0 == ":" }) else {
            date = .distantPast
            return
        }

        let dateFormatter = DateFormatter()
        let hasTimeComponent = state.contains(":")
        let hasDateComponent = state.contains("T") || state.count > 8

        switch (hasDateComponent, hasTimeComponent) {
        case (true, true): // Date and Time
            dateFormatter.dateFormat = state.contains("T") ? "yyyy-MM-dd'T'HH:mm:ssXXXXX" : "yyyy-MM-dd HH:mm:ss"
            dateFormatter.timeZone = state.contains("T") ? TimeZone(abbreviation: "UTC") : TimeZone.current

        case (false, true): // Only Time
            dateFormatter.dateFormat = "HH:mm:ss"
            if let time = dateFormatter.date(from: state) {
                date = time
            } else {
                date = .distantPast
            }
            return

        default:
            date = .distantPast
            return
        }

        date = dateFormatter.date(from: state) ?? .distantPast
    }
}
