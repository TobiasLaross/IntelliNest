import Foundation

enum NordPoolDay: String {
    case today = "Idag"
    case tomorrow = "Imorgon"
}

struct NordPoolPriceData: Identifiable {
    var id = UUID()
    var day: NordPoolDay
    var quarter: Int
    var price: Int
}

struct NordPoolEntity: EntityProtocol {
    var entityId: EntityId
    var state: String
    private var price: String {
        state.components(separatedBy: ".").first ?? state
    }

    var title: String {
        "\(price) öre"
    }

    var nextUpdate = Date().addingTimeInterval(-1)
    var isActive = true

    var quarters: [Int] {
        Array(0 ..< 96)
    }

    var hourTicks: [Int] {
        stride(from: 0, to: 96, by: 16).map { $0 }
    }

    var today: [Int] = []

    var priceData: [NordPoolPriceData] = []
    var tomorrow: [Int] = []

    var tomorrowValid = false

    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case state
        case attributes
    }

    init(entityId: EntityId, state: String = "Loading") {
        self.entityId = entityId
        self.state = state
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entityId = try EntityId(rawValue: container.decode(String.self, forKey: .entityId))
        self.entityId = entityId ?? EntityId.unknown
        state = try container.decode(String.self, forKey: .state)

        let attributes = try container.decode(Attributes.self, forKey: .attributes)
        today = attributes.today.map { Int($0?.rounded() ?? 0) }
        tomorrow = attributes.tomorrow.map { Int($0?.rounded() ?? 0) }
        tomorrowValid = attributes.tomorrowValid
        populatePriceData()
    }

    func price(quarter: Int) -> Int {
        guard quarter >= 0, quarter < priceData.count else { return 0 }
        return priceData[quarter].price
    }

    func priceTomorrow(quarter: Int) -> Int {
        guard quarter >= 0, quarter < tomorrow.count else { return 0 }
        return tomorrow[quarter]
    }

    private mutating func populatePriceData() {
        priceData = []
        var quarter = 0
        for price in today {
            priceData.append(.init(day: .today, quarter: quarter, price: price))
            quarter += 1
        }

        quarter = 0
        if tomorrowValid {
            for price in tomorrow {
                priceData.append(.init(day: .tomorrow, quarter: quarter, price: price))
                quarter += 1
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
            today = try data.decodeIfPresent([Float?].self, forKey: .today) ?? []
            tomorrow = try data.decodeIfPresent([Float?].self, forKey: .tomorrow) ?? []
            tomorrowValid = try data.decodeIfPresent(Bool.self, forKey: .tomorrowValid) ?? false
        }
    }

    mutating func setNextUpdateTime() {
        nextUpdate = Date().addingTimeInterval(0.5)
    }

    static func == (lhs: NordPoolEntity, rhs: NordPoolEntity) -> Bool {
        lhs.state == lhs.state
    }
}
