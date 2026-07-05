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
    var pm25: Int = 0
    var isActive: Bool {
        fanMode != .off
    }

    init() {}
}

/// Maps a purifier's discrete fan levels to the Home Assistant `fan.set_percentage` scale and back.
///
/// The Wellbeing/Electrolux fans expose their speed as a percentage whose granularity is fixed by the
/// device (`percentage_step`). The picker in the app works in whole levels (0 = off), so every level has
/// to convert to the exact percentage the device rests on and every reported percentage has to snap back
/// to the same level. `percentage(forLevel:)` and `level(forPercentage:)` are inverses over `0...levelCount`,
/// which is what keeps the picker from jumping when the fan reports its state back.
struct PurifierFanScale {
    /// Number of usable manual fan levels (the picker shows `0...levelCount`).
    let levelCount: Int
    /// Percentage the device advances per level. Derived from the device's `percentage_step`.
    let percentagePerLevel: Double

    func percentage(forLevel level: Double) -> Double {
        guard level > 0 else { return 0 }
        let clamped = min(level, Double(levelCount))
        return (clamped * percentagePerLevel).rounded()
    }

    func level(forPercentage percentage: Double) -> Double {
        guard percentage > 0 else { return 0 }
        let level = (percentage / percentagePerLevel).rounded()
        return min(max(level, 0), Double(levelCount))
    }

    /// The original Pure has 9 manual speeds (percentage_step ≈ 11.11).
    static let pure = PurifierFanScale(levelCount: 9, percentagePerLevel: 100.0 / 9.0)
    /// Pure 500 has 3 usable manual speeds resting on 20 / 40 / 60 % (percentage_step 20, top steps clamp).
    static let pure500 = PurifierFanScale(levelCount: 3, percentagePerLevel: 20)
}
