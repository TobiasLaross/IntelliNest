import Foundation

struct PurifierSpeed: Decodable, EntityProtocol {
    var entityId = EntityId.purifierFanSpeed
    var state = ""
    var nextUpdate = Date.now
    var isActive = false
    var speed: Double

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

        let attributes = try container.decode(PurifierSpeedAttributes.self, forKey: .attributes)
        speed = attributes.percentage.toFanSpeedTargetNumber
    }
}

struct PurifierSpeedAttributes: Decodable {
    let percentage: Double
}
