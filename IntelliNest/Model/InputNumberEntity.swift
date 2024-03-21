//
//  InputNumberEntity.swift
//  IntelliNest
//
//  Created by Tobias on 2022-03-28.
//

import Foundation

struct InputNumberEntity: EntityProtocol {
    var entityId: EntityId
    var state: String { didSet {
        inputNumber = Double(state) ?? 0
    }}
    var lastUpdated: Date
    var lastChanged: Date
    var nextUpdate = NSDate().addingTimeInterval(-1)
    var isActive = false
    var isLoading = false
    var inputNumber: Double = 0

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
    }

    static let numberFormat: NumberFormatter = {
        let numberFormatter = NumberFormatter()
        numberFormatter.minimumFractionDigits = 0
        numberFormatter.maximumFractionDigits = 1
        return numberFormatter
    }()

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entityId = try EntityId(rawValue: container.decode(String.self, forKey: .entityId))
        self.entityId = entityId ?? EntityId.unknown
        state = try container.decode(String.self, forKey: .state)
        inputNumber = try Double(container.decode(String.self, forKey: .state)) ?? 22

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
        let lastChanged = try container.decode(String.self, forKey: .lastChanged)
        self.lastChanged = dateFormatter.date(from: lastChanged) ?? .distantPast
        let lastUpdated = try container.decode(String.self, forKey: .lastUpdated)
        self.lastUpdated = dateFormatter.date(from: lastUpdated) ?? .distantPast
    }

    mutating func updateIsActive() {
        isActive = false
    }

    mutating func setNextUpdateTime() {
        nextUpdate = NSDate().addingTimeInterval(0.29)
    }

    static func == (lhs: InputNumberEntity, rhs: InputNumberEntity) -> Bool {
        lhs.entityId == rhs.entityId && lhs.state == rhs.state
    }
}
