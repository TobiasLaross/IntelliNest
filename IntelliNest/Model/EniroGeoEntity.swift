//
//  EniroGeoEntity.swift
//  IntelliNest
//
//  Created by Tobias on 2022-05-08.
//

import Foundation

struct EniroGeoEntity: EntityProtocol {
    var entityId: EntityId
    var state: String
    var nextUpdate = NSDate().addingTimeInterval(-1)
    var isActive: Bool = false
    var isLoading: Bool = false
    var address: String = ""

    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case state
        case attributes
    }

    init(entityId: EntityId, state: String = "Loading") {
        self.entityId = entityId
        self.state = state
        self.address = ""
        updateIsActive()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entityId = try EntityId(rawValue: container.decode(String.self, forKey: .entityId))
        self.entityId = entityId ?? EntityId.unknown
        state = try container.decode(String.self, forKey: .state)

        let attributes = try container.decode(Attributes.self, forKey: .attributes)
        address = attributes.address
        if address == "" {
            address = String(state.prefix(35))
        }

        updateIsActive()
    }

    private enum AttributesCodingKeys: String, CodingKey {
        case address
    }

    private struct Attributes: Decodable {
        var address: String

        init(from decoder: Decoder) throws {
            let data = try decoder.container(keyedBy: AttributesCodingKeys.self)
            address = try data.decode(Address.self, forKey: .address).getAddress()
        }
    }

    private enum AddressCodingKeys: String, CodingKey {
        case road
        case village
        case neighbourhood
        case amenity
        case town
        case city
        case suburb
    }

    private struct Address: Decodable {
        var road: String
        var village: String

        init(from decoder: Decoder) throws {
            let data = try decoder.container(keyedBy: AddressCodingKeys.self)
            road = try data.decodeIfPresent(String.self, forKey: .road) ?? ""
            if let village = try data.decodeIfPresent(String.self, forKey: .village) {
                self.village = village
            } else if let village = try data.decodeIfPresent(String.self, forKey: .neighbourhood) {
                self.village = village
            } else if let village = try data.decodeIfPresent(String.self, forKey: .amenity) {
                self.village = village
            } else if let village = try data.decodeIfPresent(String.self, forKey: .town) {
                self.village = village
            } else if let village = try data.decodeIfPresent(String.self, forKey: .city) {
                self.village = village
            } else if let village = try data.decodeIfPresent(String.self, forKey: .suburb) {
                self.village = village
            } else {
                village = ""
            }
        }

        func getAddress() -> String {
            if village != "" {
                return road + ", " + village
            } else {
                return ""
            }
        }
    }

    mutating func updateIsActive() {
        isActive = false
    }

    mutating func setNextUpdateTime() {
        nextUpdate = NSDate().addingTimeInterval(0.29)
    }
}
