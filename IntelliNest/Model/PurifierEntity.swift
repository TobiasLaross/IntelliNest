import Foundation

enum PurifierFanMode: String, Decodable {
    case off
    case manual
    case auto
}

struct PurifierEntity: Decodable {
    var fanMode: PurifierFanMode = .off
    var speed: Double = 0
    var temperature: Double = 0
    var humidity: Int = 0
    var isActive: Bool {
        fanMode != .off
    }

    init() {}
}
