@testable import IntelliNest
import XCTest

class DoubleExtensionTests: XCTestCase {
    // MARK: - roundedWithOneDecimal

    func testRoundedWithOneDecimalRoundsDown() {
        XCTAssertEqual((1.24).roundedWithOneDecimal, 1.2)
    }

    func testRoundedWithOneDecimalRoundsUp() {
        XCTAssertEqual((1.25).roundedWithOneDecimal, 1.3)
    }

    func testRoundedWithOneDecimalWholeNumber() {
        XCTAssertEqual((5.0).roundedWithOneDecimal, 5.0)
    }

    func testRoundedWithOneDecimalNegative() {
        // round() uses .toNearestOrAwayFromZero: -12.5 rounds to -13, giving -1.3
        XCTAssertEqual((-1.25).roundedWithOneDecimal, -1.3, accuracy: 0.001)
        XCTAssertEqual((-1.24).roundedWithOneDecimal, -1.2, accuracy: 0.001)
    }

    func testRoundedWithOneDecimalZero() {
        XCTAssertEqual((0.0).roundedWithOneDecimal, 0.0)
    }

    // MARK: - toPercent

    func testToPercentBelowThresholdReturnsZeroPercent() {
        // toPercent applies the threshold to the *rounded* value.
        // Only values whose roundedWithOneDecimal is 0.0 (raw < 0.05) return "0%".
        XCTAssertEqual((0.0).toPercent, "0%")
        XCTAssertEqual((0.04).toPercent, "0%")
    }

    func testToPercentSmallNonZeroValues() {
        // 0.05 rounds to 0.1 (≥ 0.06), so toPercent returns "0.1%", not "0%"
        XCTAssertEqual((0.05).toPercent, "0.1%")
        XCTAssertEqual((0.059).toPercent, "0.1%")
    }

    func testToPercentAtThresholdReturnsFormattedValue() {
        XCTAssertEqual((0.06).toPercent, "0.1%")
    }

    func testToPercentNormalValue() {
        XCTAssertEqual((50.0).toPercent, "50.0%")
    }

    func testToPercentRoundsToOneDecimal() {
        XCTAssertEqual((12.345).toPercent, "12.3%")
    }

    // MARK: - toKW

    func testToKWSmallValueReturnsZero() {
        // abs(watts) < 60 → toKW returns 0.0
        XCTAssertEqual((59.0).toKW, 0.0)
        XCTAssertEqual((-59.0).toKW, 0.0)
        XCTAssertEqual((0.0).toKW, 0.0)
    }

    func testToKWNormalValue() {
        // 1000W = 1.0kW
        XCTAssertEqual((1000.0).toKW, 1.0)
    }

    func testToKWRoundsToOneDecimal() {
        // 1234W = 1.234kW → rounds to 1.2kW
        XCTAssertEqual((1234.0).toKW, 1.2)
    }

    func testToKWNegativeValue() {
        // -1000W = -1.0kW
        XCTAssertEqual((-1000.0).toKW, -1.0)
    }

    // MARK: - toKWString

    func testToKWStringZeroReturnsIntegerFormat() {
        // Values producing 0 should be formatted as "0kW" (no decimal)
        XCTAssertEqual((59.0).toKWString, "0kW")
        XCTAssertEqual((0.0).toKWString, "0kW")
    }

    func testToKWStringNonZeroReturnsDecimalFormat() {
        XCTAssertEqual((1000.0).toKWString, "1.0kW")
        XCTAssertEqual((2500.0).toKWString, "2.5kW")
    }

    func testToKWStringNegativeValue() {
        XCTAssertEqual((-1000.0).toKWString, "-1.0kW")
    }

    // MARK: - toFanSpeedPercentage

    func testToFanSpeedPercentageZeroInput() {
        XCTAssertEqual((0.0).toFanSpeedPercentage, 0.0)
    }

    func testToFanSpeedPercentageOneInput() {
        // 1 → 11 (special case)
        XCTAssertEqual((1.0).toFanSpeedPercentage, 11.0)
    }

    func testToFanSpeedPercentageTwoInput() {
        // 2 → (2+2)*10 = 40
        XCTAssertEqual((2.0).toFanSpeedPercentage, 40.0)
    }

    func testToFanSpeedPercentageThreeInput() {
        // 3 → (3+2)*10 = 50
        XCTAssertEqual((3.0).toFanSpeedPercentage, 50.0)
    }

    func testToFanSpeedPercentageEightInput() {
        // 8 → (8+2)*10 = 100
        XCTAssertEqual((8.0).toFanSpeedPercentage, 100.0)
    }

    // MARK: - toFanSpeedTargetNumber

    func testToFanSpeedTargetNumberKnownValues() {
        XCTAssertEqual((11.0).toFanSpeedTargetNumber, 1.0)
        XCTAssertEqual((33.0).toFanSpeedTargetNumber, 2.0)
        XCTAssertEqual((44.0).toFanSpeedTargetNumber, 3.0)
        XCTAssertEqual((55.0).toFanSpeedTargetNumber, 4.0)
        XCTAssertEqual((66.0).toFanSpeedTargetNumber, 5.0)
        XCTAssertEqual((77.0).toFanSpeedTargetNumber, 6.0)
        XCTAssertEqual((88.0).toFanSpeedTargetNumber, 7.0)
        XCTAssertEqual((100.0).toFanSpeedTargetNumber, 8.0)
    }

    func testToFanSpeedTargetNumberUnknownValueReturnsZero() {
        XCTAssertEqual((0.0).toFanSpeedTargetNumber, 0.0)
        XCTAssertEqual((50.0).toFanSpeedTargetNumber, 0.0)
        XCTAssertEqual((99.0).toFanSpeedTargetNumber, 0.0)
    }

    // MARK: - toFanSpeedPercentage / toFanSpeedTargetNumber round-trip

    // Verifies that converting a target number to percentage and back yields the original
    func testFanSpeedRoundTripForKnownValues() {
        // Target 1 → percentage 11 → target 1
        XCTAssertEqual((1.0).toFanSpeedPercentage.toFanSpeedTargetNumber, 1.0)
        // Target 2 → percentage 40 — note: 40 is not in the toFanSpeedTargetNumber switch,
        // so this intentionally returns 0, revealing a gap in the mapping.
        // This test documents the current (potentially incorrect) behavior:
        XCTAssertEqual((2.0).toFanSpeedPercentage.toFanSpeedTargetNumber, 0.0,
            "toFanSpeedPercentage(2) = 40, but toFanSpeedTargetNumber has no case for 40 — round-trip is broken for speed 2")
    }
}
