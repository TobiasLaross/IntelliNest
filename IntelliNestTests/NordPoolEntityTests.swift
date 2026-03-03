@testable import IntelliNest
import XCTest

class NordPoolEntityTests: XCTestCase {
    // MARK: - Helpers

    private func makeJSON(state: String = "42.5", today: [Float?] = [], tomorrow: [Float?] = [], tomorrowValid: Bool = false) -> Data {
        let todayStr = today.map { val -> String in
            if let v = val { return "\(v)" } else { return "null" }
        }.joined(separator: ", ")
        let tomorrowStr = tomorrow.map { val -> String in
            if let v = val { return "\(v)" } else { return "null" }
        }.joined(separator: ", ")
        return Data("""
        {
            "entity_id": "sensor.nordpool_kwh_se4_sek_2_10_025",
            "state": "\(state)",
            "attributes": {
                "today": [\(todayStr)],
                "tomorrow": [\(tomorrowStr)],
                "tomorrow_valid": \(tomorrowValid ? "true" : "false")
            }
        }
        """.utf8)
    }

    // MARK: - Init

    func testDefaultInit() {
        let entity = NordPoolEntity(entityId: .nordPool)
        XCTAssertEqual(entity.entityId, .nordPool)
        XCTAssertEqual(entity.state, "Loading")
        XCTAssertTrue(entity.today.isEmpty)
        XCTAssertTrue(entity.tomorrow.isEmpty)
        XCTAssertFalse(entity.tomorrowValid)
        XCTAssertTrue(entity.priceData.isEmpty)
    }

    func testInitWithCustomState() {
        let entity = NordPoolEntity(entityId: .nordPool, state: "99.5")
        XCTAssertEqual(entity.state, "99.5")
    }

    // MARK: - Title

    func testTitleStripsDecimalPart() {
        let entity = NordPoolEntity(entityId: .nordPool, state: "42.876")
        XCTAssertEqual(entity.title, "42 öre")
    }

    func testTitleWithWholeNumber() {
        let entity = NordPoolEntity(entityId: .nordPool, state: "100")
        XCTAssertEqual(entity.title, "100 öre")
    }

    // MARK: - Quarters / HourTicks

    func testQuartersContains96Elements() {
        let entity = NordPoolEntity(entityId: .nordPool)
        XCTAssertEqual(entity.quarters.count, 96)
        XCTAssertEqual(entity.quarters.first, 0)
        XCTAssertEqual(entity.quarters.last, 95)
    }

    func testHourTicksHave6Elements() {
        let entity = NordPoolEntity(entityId: .nordPool)
        // stride(from: 0, to: 96, by: 16) => [0, 16, 32, 48, 64, 80]
        XCTAssertEqual(entity.hourTicks, [0, 16, 32, 48, 64, 80])
    }

    // MARK: - JSON Decoding

    func testDecodeWithTodayPrices() throws {
        let todayPrices: [Float?] = [100, 200, 300]
        let json = makeJSON(today: todayPrices)
        let entity = try JSONDecoder().decode(NordPoolEntity.self, from: json)

        XCTAssertEqual(entity.today, [100, 200, 300])
        XCTAssertTrue(entity.tomorrow.isEmpty)
        XCTAssertFalse(entity.tomorrowValid)
        XCTAssertEqual(entity.priceData.count, 3)
    }

    func testDecodeWithTomorrowValidTrue() throws {
        let todayPrices: [Float?] = [100, 200]
        let tomorrowPrices: [Float?] = [150, 250]
        let json = makeJSON(today: todayPrices, tomorrow: tomorrowPrices, tomorrowValid: true)
        let entity = try JSONDecoder().decode(NordPoolEntity.self, from: json)

        XCTAssertEqual(entity.today.count, 2)
        XCTAssertEqual(entity.tomorrow.count, 2)
        XCTAssertTrue(entity.tomorrowValid)
        // priceData should include both today (2) and tomorrow (2)
        XCTAssertEqual(entity.priceData.count, 4)
        XCTAssertEqual(entity.priceData[0].day, .today)
        XCTAssertEqual(entity.priceData[2].day, .tomorrow)
    }

    func testDecodeWithTomorrowValidFalse() throws {
        let todayPrices: [Float?] = [100, 200]
        let tomorrowPrices: [Float?] = [150, 250]
        let json = makeJSON(today: todayPrices, tomorrow: tomorrowPrices, tomorrowValid: false)
        let entity = try JSONDecoder().decode(NordPoolEntity.self, from: json)

        XCTAssertFalse(entity.tomorrowValid)
        // priceData should only include today's 2 entries, tomorrow is ignored
        XCTAssertEqual(entity.priceData.count, 2)
        XCTAssertTrue(entity.priceData.allSatisfy { $0.day == .today })
    }

    func testDecodeWithNullPrices() throws {
        let todayPrices: [Float?] = [nil, 200, nil]
        let json = makeJSON(today: todayPrices)
        let entity = try JSONDecoder().decode(NordPoolEntity.self, from: json)

        // nil values should be treated as 0 via `$0?.rounded() ?? 0`
        XCTAssertEqual(entity.today, [0, 200, 0])
    }

    // MARK: - Price Access

    func testPriceAtValidQuarter() throws {
        let prices: [Float?] = [100, 200, 300]
        let json = makeJSON(today: prices)
        let entity = try JSONDecoder().decode(NordPoolEntity.self, from: json)

        XCTAssertEqual(entity.price(quarter: 0), 100)
        XCTAssertEqual(entity.price(quarter: 1), 200)
        XCTAssertEqual(entity.price(quarter: 2), 300)
    }

    func testPriceAtNegativeQuarterReturnsZero() throws {
        let json = makeJSON(today: [100, 200])
        let entity = try JSONDecoder().decode(NordPoolEntity.self, from: json)
        XCTAssertEqual(entity.price(quarter: -1), 0)
    }

    func testPriceAtOutOfBoundsQuarterReturnsZero() throws {
        let json = makeJSON(today: [100, 200])
        let entity = try JSONDecoder().decode(NordPoolEntity.self, from: json)
        XCTAssertEqual(entity.price(quarter: 99), 0)
    }

    func testPriceTomorrowAtValidQuarter() throws {
        let json = makeJSON(tomorrow: [500, 600, 700], tomorrowValid: true)
        let entity = try JSONDecoder().decode(NordPoolEntity.self, from: json)
        XCTAssertEqual(entity.priceTomorrow(quarter: 0), 500)
        XCTAssertEqual(entity.priceTomorrow(quarter: 2), 700)
    }

    func testPriceTomorrowAtOutOfBoundsReturnsZero() throws {
        let json = makeJSON(tomorrow: [500], tomorrowValid: true)
        let entity = try JSONDecoder().decode(NordPoolEntity.self, from: json)
        XCTAssertEqual(entity.priceTomorrow(quarter: 5), 0)
    }

    // MARK: - populatePriceData quarter numbering

    func testPriceDataQuarterNumbering() throws {
        let prices: [Float?] = [10, 20, 30, 40, 50]
        let json = makeJSON(today: prices)
        let entity = try JSONDecoder().decode(NordPoolEntity.self, from: json)

        for (index, data) in entity.priceData.enumerated() {
            XCTAssertEqual(data.quarter, index, "Quarter at index \(index) should equal \(index)")
        }
    }

    func testTomorrowPriceDataQuarterNumberingRestartsFromZero() throws {
        let todayPrices: [Float?] = [10, 20]
        let tomorrowPrices: [Float?] = [30, 40]
        let json = makeJSON(today: todayPrices, tomorrow: tomorrowPrices, tomorrowValid: true)
        let entity = try JSONDecoder().decode(NordPoolEntity.self, from: json)

        // first 2 are today with quarters 0,1; next 2 are tomorrow starting from 0 again
        XCTAssertEqual(entity.priceData[2].quarter, 0)
        XCTAssertEqual(entity.priceData[3].quarter, 1)
        XCTAssertEqual(entity.priceData[2].day, .tomorrow)
    }

    // MARK: - Equality (BUG: lhs.state == lhs.state always returns true)

    // This test is expected to FAIL with the current implementation, revealing the bug:
    // `lhs.state == lhs.state` always evaluates to true, making entities with
    // different states incorrectly appear equal.
    func testEqualityWithDifferentStates() {
        let entity1 = NordPoolEntity(entityId: .nordPool, state: "100")
        let entity2 = NordPoolEntity(entityId: .nordPool, state: "200")
        // With the bug, entity1 == entity2 returns true even though states differ.
        // The correct result should be false.
        XCTAssertFalse(entity1 == entity2, "Entities with different states should not be equal. " +
            "NOTE: This test exposes a bug in the == operator: 'lhs.state == lhs.state' should be 'lhs.state == rhs.state'")
    }

    func testEqualityWithSameState() {
        let entity1 = NordPoolEntity(entityId: .nordPool, state: "100")
        let entity2 = NordPoolEntity(entityId: .nordPool, state: "100")
        XCTAssertTrue(entity1 == entity2)
    }

    // MARK: - setNextUpdateTime

    func testSetNextUpdateTime() {
        var entity = NordPoolEntity(entityId: .nordPool)
        entity.setNextUpdateTime()
        XCTAssertGreaterThan(entity.nextUpdate.timeIntervalSinceNow, 0)
    }
}
