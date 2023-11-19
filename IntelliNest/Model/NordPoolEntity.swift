//
//  NordPoolEntity.swift
//  IntelliNest
//
//  Created by Tobias on 2023-02-06.
//

import Foundation

enum NordPoolDay: String {
    case today = "Idag"
    case tomorrow = "Imorgon"
}

struct NordPoolPriceData: Identifiable {
    var id = UUID()
    var day: NordPoolDay
    var hour: Int
    var price: Int
}

struct NordPoolEntity: EntityProtocol {
    var entityId: EntityId
    var state: String
    var price: String {
        state.components(separatedBy: ".").first ?? state
    }

    var nextUpdate = NSDate().addingTimeInterval(-1)
    var isActive = true
    var hours: [Int] {
        stride(from: 0, to: 25, by: 4).map { $0 }
    }

    var today: [Int] = [] { didSet {
        populatePriceData()
    }}
    var priceData: [NordPoolPriceData] = []
    var tomorrow: [Int] = [] { didSet {
        populatePriceData()
    }}

    var tomorrowValid = false

    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case state
        case attributes
    }

    init(entityId: EntityId, state: String = "Loading") {
        self.entityId = entityId
        self.state = state
        updateIsActive()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entityId = try EntityId(rawValue: container.decode(String.self, forKey: .entityId))
        self.entityId = entityId ?? EntityId.unknown
        state = try container.decode(String.self, forKey: .state)

        let attributes = try container.decode(Attributes.self, forKey: .attributes)
        today = attributes.today.map { Int($0 ?? 0) }
        tomorrow = attributes.tomorrow.map { Int($0 ?? 0) }
        tomorrowValid = attributes.tomorrowValid
        updateIsActive()
    }

    mutating func updateIsActive() {
        isActive = true
    }

    func chartBarHeight() -> Int {
        Int(1.1 * Double(today.max() ?? 0))
    }

    private mutating func populatePriceData() {
        priceData = []
        var hour = 0
        for price in today {
            priceData.append(.init(day: .today, hour: hour, price: price))
            hour += 1
        }

        hour = 0
        if tomorrowValid {
            for price in tomorrow {
                priceData.append(.init(day: .tomorrow, hour: hour, price: price))
                hour += 1
            }
        }
    }

    private enum AttributesCodingKeys: String, CodingKey {
        case today
        case tomorrow
        case tomorrowValid = "tomorrow_valid"
    }

    private struct Attributes: Decodable {
        var today: [Float?]
        var tomorrow: [Float?]
        var tomorrowValid: Bool

        init(from decoder: Decoder) throws {
            let data = try decoder.container(keyedBy: AttributesCodingKeys.self)
            self.today = try data.decodeIfPresent([Float?].self, forKey: .today) ?? []
            self.tomorrow = try data.decodeIfPresent([Float?].self, forKey: .tomorrow) ?? []
            self.tomorrowValid = try data.decodeIfPresent(Bool.self, forKey: .tomorrowValid) ?? false
        }
    }

    mutating func setNextUpdateTime() {
        nextUpdate = NSDate().addingTimeInterval(0.5)
    }

    static func == (lhs: NordPoolEntity, rhs: NordPoolEntity) -> Bool {
        lhs.state == lhs.state
    }
}
