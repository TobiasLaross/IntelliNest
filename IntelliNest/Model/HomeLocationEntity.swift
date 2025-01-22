import Foundation

struct HomeLocationEntity: EntityProtocol {
    let entityId: EntityId
    var state: String
    var latitude: Double
    var longitude: Double
    var nextUpdate = Date.now
    var isActive = false

    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case state
        case attributes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entityId = try EntityId(rawValue: container.decode(String.self, forKey: .entityId))
        self.entityId = entityId ?? EntityId.unknown
        state = try container.decode(String.self, forKey: .state)

        let attributes = try container.decode(HomeLocationAttributes.self, forKey: .attributes)
        latitude = attributes.latitude
        longitude = attributes.longitude
    }
}

struct HomeLocationAttributes: Decodable {
    let latitude: Double
    let longitude: Double
}
