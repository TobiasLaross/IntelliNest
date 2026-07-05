@testable import IntelliNest
import XCTest

class DoubleExtensionTests: XCTestCase {
    // MARK: - roundedWithOneDecimal

    func testRoundedWithOneDecimalRoundsDown() {
        XCTAssertEqual(1.24.roundedWithOneDecimal, 1.2)
    }

    func testRoundedWithOneDecimalRoundsUp() {
        XCTAssertEqual(1.25.roundedWithOneDecimal, 1.3)
    }

    func testRoundedWithOneDecimalWholeNumber() {
        XCTAssertEqual(5.0.roundedWithOneDecimal, 5.0)
    }

    func testRoundedWithOneDecimalNegative() {
        // round() uses .toNearestOrAwayFromZero: -12.5 rounds to -13, giving -1.3
        XCTAssertEqual((-1.25).roundedWithOneDecimal, -1.3, accuracy: 0.001)
        XCTAssertEqual((-1.24).roundedWithOneDecimal, -1.2, accuracy: 0.001)
    }

    func testRoundedWithOneDecimalZero() {
        XCTAssertEqual(0.0.roundedWithOneDecimal, 0.0)
    }

    // MARK: - toPercent

    func testToPercentBelowThresholdReturnsZeroPercent() {
        // toPercent applies the threshold to the *rounded* value.
        // Only values whose roundedWithOneDecimal is 0.0 (raw < 0.05) return "0%".
        XCTAssertEqual(0.0.toPercent, "0%")
        XCTAssertEqual(0.04.toPercent, "0%")
    }

    func testToPercentSmallNonZeroValues() {
        // 0.05 rounds to 0.1 (≥ 0.06), so toPercent returns "0.1%", not "0%"
        XCTAssertEqual(0.05.toPercent, "0.1%")
        XCTAssertEqual(0.059.toPercent, "0.1%")
    }

    func testToPercentAtThresholdReturnsFormattedValue() {
        XCTAssertEqual(0.06.toPercent, "0.1%")
    }

    func testToPercentNormalValue() {
        XCTAssertEqual(50.0.toPercent, "50.0%")
    }

    func testToPercentRoundsToOneDecimal() {
        XCTAssertEqual(12.345.toPercent, "12.3%")
    }

    // MARK: - toKW

    func testToKWSmallValueReturnsZero() {
        // abs(watts) < 60 → toKW returns 0.0
        XCTAssertEqual(59.0.toKW, 0.0)
        XCTAssertEqual((-59.0).toKW, 0.0)
        XCTAssertEqual(0.0.toKW, 0.0)
    }

    func testToKWNormalValue() {
        // 1000W = 1.0kW
        XCTAssertEqual(1000.0.toKW, 1.0)
    }

    func testToKWRoundsToOneDecimal() {
        // 1234W = 1.234kW → rounds to 1.2kW
        XCTAssertEqual(1234.0.toKW, 1.2)
    }

    func testToKWNegativeValue() {
        // -1000W = -1.0kW
        XCTAssertEqual((-1000.0).toKW, -1.0)
    }

    // MARK: - toKWString

    func testToKWStringZeroReturnsIntegerFormat() {
        // Values producing 0 should be formatted as "0kW" (no decimal)
        XCTAssertEqual(59.0.toKWString, "0kW")
        XCTAssertEqual(0.0.toKWString, "0kW")
    }

    func testToKWStringNonZeroReturnsDecimalFormat() {
        XCTAssertEqual(1000.0.toKWString, "1.0kW")
        XCTAssertEqual(2500.0.toKWString, "2.5kW")
    }

    func testToKWStringNegativeValue() {
        XCTAssertEqual((-1000.0).toKWString, "-1.0kW")
    }

    // MARK: - PurifierFanScale (original Pure, 9 speeds)

    func testPureFanScalePercentageForLevel() {
        let cases: [(level: Double, percentage: Double)] = [
            (0, 0), (1, 11), (2, 22), (3, 33), (4, 44), (5, 56), (6, 67), (7, 78), (8, 89), (9, 100)
        ]
        for testCase in cases {
            XCTAssertEqual(PurifierFanScale.pure.percentage(forLevel: testCase.level), testCase.percentage,
                           "Pure level \(testCase.level) should map to \(testCase.percentage)%")
        }
    }

    func testPureFanScaleLevelForPercentage() {
        // The device reports its own snapped percentages (multiples of 100/9); each maps back to its level.
        let cases: [(percentage: Double, level: Double)] = [
            (0, 0), (11, 1), (22, 2), (33, 3), (44, 4), (56, 5), (67, 6), (78, 7), (89, 8), (100, 9)
        ]
        for testCase in cases {
            XCTAssertEqual(PurifierFanScale.pure.level(forPercentage: testCase.percentage), testCase.level,
                           "Pure \(testCase.percentage)% should map to level \(testCase.level)")
        }
    }

    func testPureFanScaleRoundTripIsStable() {
        for level in stride(from: 0.0, through: 9.0, by: 1) {
            let percentage = PurifierFanScale.pure.percentage(forLevel: level)
            XCTAssertEqual(PurifierFanScale.pure.level(forPercentage: percentage), level,
                           "Pure round-trip broke for level \(level) (percentage \(percentage))")
        }
    }

    // MARK: - PurifierFanScale (Pure 500, 3 speeds)

    func testPure500FanScalePercentageForLevel() {
        let cases: [(level: Double, percentage: Double)] = [(0, 0), (1, 20), (2, 40), (3, 60)]
        for testCase in cases {
            XCTAssertEqual(PurifierFanScale.pure500.percentage(forLevel: testCase.level), testCase.percentage,
                           "Pure 500 level \(testCase.level) should map to \(testCase.percentage)%")
        }
    }

    func testPure500FanScaleClampsAboveMax() {
        // The device only accepts Fanspeed 1-3, so the app never emits 80/100 % (which the API rejects with 406).
        XCTAssertEqual(PurifierFanScale.pure500.percentage(forLevel: 4), 60)
        XCTAssertEqual(PurifierFanScale.pure500.level(forPercentage: 80), 3)
        XCTAssertEqual(PurifierFanScale.pure500.level(forPercentage: 100), 3)
    }

    func testPure500FanScaleRoundTripIsStable() {
        for level in stride(from: 0.0, through: 3.0, by: 1) {
            let percentage = PurifierFanScale.pure500.percentage(forLevel: level)
            XCTAssertEqual(PurifierFanScale.pure500.level(forPercentage: percentage), level,
                           "Pure 500 round-trip broke for level \(level) (percentage \(percentage))")
        }
    }
}
