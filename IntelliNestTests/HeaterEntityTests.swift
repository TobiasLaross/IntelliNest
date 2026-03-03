@testable import IntelliNest
import XCTest

class HeaterEntityTests: XCTestCase {
    // MARK: - Helpers

    private func makeHeaterJSON(
        entityId: String = "climate.varmepump",
        state: String = "heat",
        currentTemperature: Double = 21.5,
        targetTemperature: Double = 22.0,
        fanMode: String = "auto",
        swingMode: String = "off",
        vaneHorizontal: String = "auto",
        vaneVertical: String = "auto"
    ) -> Data {
        Data("""
        {
            "entity_id": "\(entityId)",
            "state": "\(state)",
            "attributes": {
                "current_temperature": \(currentTemperature),
                "temperature": \(targetTemperature),
                "fan_mode": "\(fanMode)",
                "swing_mode": "\(swingMode)",
                "vane_horizontal": "\(vaneHorizontal)",
                "vane_vertical": "\(vaneVertical)"
            }
        }
        """.utf8)
    }

    // MARK: - Default Init

    func testDefaultInit() {
        let entity = HeaterEntity(entityId: .heaterCorridor)
        XCTAssertEqual(entity.entityId, .heaterCorridor)
        XCTAssertEqual(entity.state, "Loading")
        XCTAssertEqual(entity.currentTemperature, 0)
        XCTAssertEqual(entity.targetTemperature, 0)
        XCTAssertEqual(entity.fanMode, .auto)
    }

    // MARK: - JSON Decoding

    func testDecodeFromJSONWithCorridorHeater() throws {
        let json = makeHeaterJSON(
            entityId: "climate.varmepump",
            state: "heat",
            currentTemperature: 21.5,
            targetTemperature: 22.0,
            fanMode: "auto",
            swingMode: "off",
            vaneHorizontal: "auto",
            vaneVertical: "auto"
        )
        let entity = try JSONDecoder().decode(HeaterEntity.self, from: json)

        XCTAssertEqual(entity.entityId, .heaterCorridor)
        XCTAssertEqual(entity.state, "heat")
        XCTAssertEqual(entity.currentTemperature, 21.5)
        XCTAssertEqual(entity.targetTemperature, 22.0)
        XCTAssertEqual(entity.fanMode, .auto)
        XCTAssertEqual(entity.swingMode, "off")
        XCTAssertEqual(entity.vaneHorizontal, .auto)
        XCTAssertEqual(entity.vaneVertical, .auto)
    }

    func testDecodeFromJSONWithPlayroomHeater() throws {
        let json = makeHeaterJSON(entityId: "climate.mellanrummet", state: "cool")
        let entity = try JSONDecoder().decode(HeaterEntity.self, from: json)

        XCTAssertEqual(entity.entityId, .heaterPlayroom)
        XCTAssertEqual(entity.state, "cool")
    }

    func testDecodeWithFanModeNumber() throws {
        let json = makeHeaterJSON(fanMode: "3")
        let entity = try JSONDecoder().decode(HeaterEntity.self, from: json)
        XCTAssertEqual(entity.fanMode, .three)
    }

    func testDecodeWithHorizontalVanePosition() throws {
        let json = makeHeaterJSON(vaneHorizontal: "1_left")
        let entity = try JSONDecoder().decode(HeaterEntity.self, from: json)
        XCTAssertEqual(entity.vaneHorizontal, .oneLeft)
    }

    func testDecodeWithVerticalVanePosition() throws {
        let json = makeHeaterJSON(vaneVertical: "1_up")
        let entity = try JSONDecoder().decode(HeaterEntity.self, from: json)
        XCTAssertEqual(entity.vaneVertical, .highest)
    }

    func testDecodeWithUnknownVanePositionFallsBackToUnknown() throws {
        let json = makeHeaterJSON(vaneHorizontal: "invalid_mode", vaneVertical: "invalid_mode")
        let entity = try JSONDecoder().decode(HeaterEntity.self, from: json)
        XCTAssertEqual(entity.vaneHorizontal, .unknown)
        XCTAssertEqual(entity.vaneVertical, .unknown)
    }

    // MARK: - hvacMode computed property

    func testHvacModeHeat() {
        let entity = HeaterEntity(entityId: .heaterCorridor, state: "heat")
        XCTAssertEqual(entity.hvacMode, .heat)
    }

    func testHvacModeCool() {
        let entity = HeaterEntity(entityId: .heaterCorridor, state: "cool")
        XCTAssertEqual(entity.hvacMode, .cool)
    }

    func testHvacModeOff() {
        let entity = HeaterEntity(entityId: .heaterCorridor, state: "off")
        XCTAssertEqual(entity.hvacMode, .off)
    }

    func testHvacModeUnknownStateDefaultsToOff() {
        let entity = HeaterEntity(entityId: .heaterCorridor, state: "unknown_mode")
        XCTAssertEqual(entity.hvacMode, .off)
    }

    // MARK: - isActive

    func testIsActiveOnlyWhenStateIsOn() {
        let active = HeaterEntity(entityId: .heaterCorridor, state: "on")
        XCTAssertTrue(active.isActive)

        let inactive = HeaterEntity(entityId: .heaterCorridor, state: "heat")
        XCTAssertFalse(inactive.isActive)
    }

    // MARK: - setTitles (entityId-based name assignment)

    func testSetTitlesForCorridorHeater() {
        let entity = HeaterEntity(entityId: .heaterCorridor)
        XCTAssertEqual(entity.heaterName, "Korridoren")
        XCTAssertEqual(entity.leftVaneTitle, "Vardagsrummet")
        XCTAssertEqual(entity.rightVaneTitle, "Sovrummet")
    }

    func testSetTitlesForPlayroomHeater() {
        let entity = HeaterEntity(entityId: .heaterPlayroom)
        XCTAssertEqual(entity.heaterName, "Lekrummet")
        XCTAssertEqual(entity.leftVaneTitle, "Gästrummet")
        XCTAssertEqual(entity.rightVaneTitle, "Förrådet")
    }

    // MARK: - Equality

    func testEqualityRequiresSameEntityIdAndState() {
        let entity1 = HeaterEntity(entityId: .heaterCorridor, state: "heat")
        let entity2 = HeaterEntity(entityId: .heaterCorridor, state: "heat")
        XCTAssertEqual(entity1, entity2)
    }

    func testInequalityForDifferentState() {
        let entity1 = HeaterEntity(entityId: .heaterCorridor, state: "heat")
        let entity2 = HeaterEntity(entityId: .heaterCorridor, state: "cool")
        XCTAssertNotEqual(entity1, entity2)
    }

    func testInequalityForDifferentEntityId() {
        let entity1 = HeaterEntity(entityId: .heaterCorridor, state: "heat")
        let entity2 = HeaterEntity(entityId: .heaterPlayroom, state: "heat")
        XCTAssertNotEqual(entity1, entity2)
    }

    // MARK: - setNextUpdateTime

    func testSetNextUpdateTimeSetsUpdateInFuture() {
        var entity = HeaterEntity(entityId: .heaterCorridor)
        entity.setNextUpdateTime()
        XCTAssertGreaterThan(entity.nextUpdate.timeIntervalSinceNow, 0)
    }

    func testDefaultNextUpdateIsInThePast() {
        let entity = HeaterEntity(entityId: .heaterCorridor)
        XCTAssertLessThan(entity.nextUpdate.timeIntervalSinceNow, 0)
        XCTAssertTrue(entity.canUpdate())
    }

    // MARK: - currentTemperatureFormatted

    func testCurrentTemperatureFormatted() {
        let entity = HeaterEntity(entityId: .heaterCorridor, state: "heat")
        // Default is 0
        XCTAssertEqual(entity.currentTemperatureFormatted, NSNumber(value: 0.0))
    }
}
