@testable import IntelliNest
import SwiftUI
import XCTest

class SwitchEntityTests: XCTestCase {
    // MARK: - isActive

    func testIsActiveWhenStateIsOn() {
        let entity = SwitchEntity(entityId: .coffeeMachine, state: "on")
        XCTAssertTrue(entity.isActive)
    }

    func testIsActiveWhenStateIsOff() {
        let entity = SwitchEntity(entityId: .coffeeMachine, state: "off")
        XCTAssertFalse(entity.isActive)
    }

    func testIsActiveCaseInsensitive() {
        XCTAssertTrue(SwitchEntity(entityId: .coffeeMachine, state: "ON").isActive)
        XCTAssertTrue(SwitchEntity(entityId: .coffeeMachine, state: "On").isActive)
        XCTAssertFalse(SwitchEntity(entityId: .coffeeMachine, state: "OFF").isActive)
    }

    // MARK: - activeColor state-based logic

    func testActiveColorIsRedWhenInactive() {
        let entity = SwitchEntity(entityId: .coffeeMachine, state: "off", lastChanged: .distantPast)
        // When inactive, color should always be red regardless of lastChanged
        XCTAssertEqual(entity.activeColor, .red)
    }

    // When active for less than 1 minute → still red (warming up period)
    func testActiveColorIsRedJustAfterActivation() {
        let thirtySecondsAgo = Date().addingTimeInterval(-30)
        let entity = SwitchEntity(entityId: .coffeeMachine, state: "on", lastChanged: thirtySecondsAgo)
        XCTAssertEqual(entity.activeColor, .red)
    }

    // When active for exactly 1 minute → blending starts, not yet red
    func testActiveColorStartsBlendingAfter1Minute() {
        let oneMinuteOneSecondAgo = Date().addingTimeInterval(-(60 + 1))
        let entity = SwitchEntity(entityId: .coffeeMachine, state: "on", lastChanged: oneMinuteOneSecondAgo)
        // After 1 minute, blending begins: color should be between red and orange (not plain red)
        XCTAssertNotEqual(entity.activeColor, .red)
        XCTAssertNotEqual(entity.activeColor, .yellow)
    }

    // When active for 15 or more minutes → yellow
    func testActiveColorIsYellowAfter15Minutes() {
        let fifteenMinutesAgo = Date().addingTimeInterval(-15 * 60)
        let entity = SwitchEntity(entityId: .coffeeMachine, state: "on", lastChanged: fifteenMinutesAgo)
        XCTAssertEqual(entity.activeColor, .yellow)
    }

    func testActiveColorIsYellowLongAfter15Minutes() {
        let oneHourAgo = Date().addingTimeInterval(-60 * 60)
        let entity = SwitchEntity(entityId: .coffeeMachine, state: "on", lastChanged: oneHourAgo)
        XCTAssertEqual(entity.activeColor, .yellow)
    }

    // MARK: - JSON Decoding

    func testDecodeFromJSON() throws {
        let json = Data("""
        {
            "entity_id": "switch.kaffemaskinen",
            "state": "on",
            "last_changed": "2023-06-17T13:30:00.000000+0000"
        }
        """.utf8)
        let entity = try JSONDecoder().decode(SwitchEntity.self, from: json)

        XCTAssertEqual(entity.entityId, .coffeeMachine)
        XCTAssertEqual(entity.state, "on")
        XCTAssertTrue(entity.isActive)
        XCTAssertNotEqual(entity.lastChanged, .distantFuture)
    }

    func testDecodeFromJSONWithInvalidDateFallsBackToDistantFuture() throws {
        let json = Data("""
        {
            "entity_id": "switch.kaffemaskinen",
            "state": "on",
            "last_changed": "not-a-valid-date"
        }
        """.utf8)
        let entity = try JSONDecoder().decode(SwitchEntity.self, from: json)

        // Invalid date should fall back to .distantFuture per SwitchEntity init(from:)
        XCTAssertEqual(entity.lastChanged, .distantFuture)
    }

    func testDecodeFromJSONWithOffState() throws {
        let json = Data("""
        {
            "entity_id": "switch.kaffemaskinen",
            "state": "off",
            "last_changed": "2023-06-17T13:30:00.000000+0000"
        }
        """.utf8)
        let entity = try JSONDecoder().decode(SwitchEntity.self, from: json)

        XCTAssertFalse(entity.isActive)
        XCTAssertEqual(entity.activeColor, .red)
    }

    // MARK: - Equality

    // SwitchEntity equality is based only on entityId, not state
    func testEqualityIsBasedOnEntityId() {
        let entity1 = SwitchEntity(entityId: .coffeeMachine, state: "on")
        let entity2 = SwitchEntity(entityId: .coffeeMachine, state: "off")
        XCTAssertEqual(entity1, entity2)
    }

    func testInequalityForDifferentEntityIds() {
        let entity1 = SwitchEntity(entityId: .coffeeMachine, state: "on")
        let entity2 = SwitchEntity(entityId: .unknown, state: "on")
        XCTAssertNotEqual(entity1, entity2)
    }

    // MARK: - Title

    func testTitleForCoffeeMachine() {
        let entity = SwitchEntity(entityId: .coffeeMachine)
        XCTAssertEqual(entity.title, "Kaffemaskinen")
    }

    func testTitleForUnknownEntity() {
        let entity = SwitchEntity(entityId: .unknown)
        XCTAssertEqual(entity.title, "")
    }

    // MARK: - setNextUpdateTime

    func testSetNextUpdateTime() {
        let entity = SwitchEntity(entityId: .coffeeMachine)
        // nextUpdate starts in the past (Date().addingTimeInterval(-1))
        XCTAssertLessThan(entity.nextUpdate.timeIntervalSinceNow, 0)

        // After calling setNextUpdateTime, it should be in the future... except SwitchEntity
        // doesn't define setNextUpdateTime — it relies on EntityProtocol's canUpdate()
        // This test just verifies the default nextUpdate is in the past so canUpdate returns true.
        XCTAssertTrue(entity.canUpdate())
    }
}
