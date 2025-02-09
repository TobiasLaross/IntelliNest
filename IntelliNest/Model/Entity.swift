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
    var nextUpdate = Date().addingTimeInterval(-1)
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
    var state: String {
        didSet {
            updateDate()
        }
    }

    var timerEnabledIcon: Image? {
        isActive ? Image(systemImageName: .clock) : nil
    }

    init(entityId: EntityId, state: String = "Loading") {
        self.entityId = entityId
        self.state = state
        lastChanged = .distantPast
        lastUpdated = .distantPast
        updateDate()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entityId = try EntityId(rawValue: container.decode(String.self, forKey: .entityId))
        self.entityId = entityId ?? EntityId.unknown
        state = try (container.decodeIfPresent(String.self, forKey: .state)) ?? "Loading"

        let utcDateFormatter = Entity.utcDateFormatter

        if let lastChangedString = try container.decodeIfPresent(String.self, forKey: .lastChanged),
           let lastChangedDate = utcDateFormatter.date(from: lastChangedString) {
            lastChanged = lastChangedDate
        } else {
            lastChanged = .distantPast
        }

        if let lastUpdatedString = try container.decodeIfPresent(String.self, forKey: .lastUpdated),
           let lastUpdatedDate = utcDateFormatter.date(from: lastUpdatedString) {
            lastUpdated = lastUpdatedDate
        } else {
            lastUpdated = .distantPast
        }

        updateDate()
    }

    func recentlyUpdated() -> Bool {
        -lastUpdated.timeIntervalSinceNow < 20 * 60
    }

    mutating func setNextUpdateTime() {
        nextUpdate = Date().addingTimeInterval(0.5)
    }

    static func == (lhs: Entity, rhs: Entity) -> Bool {
        lhs.entityId == rhs.entityId && lhs.state == rhs.state
    }

    private mutating func updateDate() {
        date = .distantPast

        if entityId == .leafLastPoll {
            print("")
        }
        let dateFormatter = DateFormatter()
        let hasDateComponent = state.contains("T") || state.count > 8
        let hasTimeComponent = state.contains(":")

        switch (hasDateComponent, hasTimeComponent) {
        case (true, true): // Date and Time
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX") // Ensure the formatter is not affected by the user's locale
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")

            if state.contains(".") {
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
            } else if state.contains("Z") {
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
            } else if state.contains("T") {
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
                dateFormatter.timeZone = .current
            } else {
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                dateFormatter.timeZone = .current
            }

            date = dateFormatter.date(from: state) ?? .distantPast
        case (false, true): // Only Time
            dateFormatter.dateFormat = "HH:mm:ss"
            if let time = dateFormatter.date(from: state) {
                date = time
            }
        case (true, false): // Only Date
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            date = dateFormatter.date(from: state) ?? .distantPast
        default:
            break
        }
    }
}

extension Entity {
    static let utcDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
        return formatter
    }()
}
