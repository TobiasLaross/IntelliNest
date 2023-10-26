//
//  SwitchEntity.swift
//  IntelliNest
//
//  Created by Tobias on 2023-10-19.
//

import SwiftUI
import ShipBookSDK

struct SwitchEntity: EntityProtocol {
    var image: Image {
        isActive ? Image(systemImageName: .bolt) : Image(systemImageName: .boltSlash)
    }

    var activeColor: Color {
        guard isActive else {
            return .red
        }

        let now = Date()
        let elapsed = now.timeIntervalSince(lastChanged) / 60.0
        let minutesBeforeBlending = 1.0
        let minutesUntilPowered = 15.0
        if elapsed < minutesBeforeBlending {
            return .red
        } else if elapsed >= minutesUntilPowered {
            return .yellow
        } else {
            let ratio = (elapsed - minutesBeforeBlending) / (minutesUntilPowered - minutesBeforeBlending)
            return .blend(Color.red, with: Color.orange, ratio: CGFloat(ratio))
        }
    }

    var nextUpdate = NSDate().addingTimeInterval(-1)
    var isActive: Bool {
        state.lowercased() == "on"
    }

    var title: String {
        switch entityId {
        case .coffeeMachine:
            return "Kaffemaskinen"
        default:
            return ""
        }
    }

    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case state
        case lastChanged = "last_changed"
    }

    let entityId: EntityId
    var state: String
    var lastChanged: Date

    init(entityId: EntityId, state: String = "Loading", lastChanged: Date = .now) {
        self.entityId = entityId
        self.state = state
        self.lastChanged = lastChanged
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entityId = try EntityId(rawValue: container.decode(String.self, forKey: .entityId))
        self.entityId = entityId ?? EntityId.unknown
        state = try container.decode(String.self, forKey: .state)

        let dateFormatter = ISO8601DateFormatter()
        if let lastChangedString = try? container.decode(String.self, forKey: .lastChanged),
           let date = dateFormatter.date(from: lastChangedString) {
            lastChanged = date
        } else {
            lastChanged = .distantFuture
            Log.error("Failed to parse last_changed in SwitchEntity")
        }
    }

    static func == (lhs: SwitchEntity, rhs: SwitchEntity) -> Bool {
        lhs.entityId == rhs.entityId
    }
}
