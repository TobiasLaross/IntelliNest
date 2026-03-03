@testable import IntelliNest
import XCTest

class RoborockEntityTests: XCTestCase {
    // MARK: - Default Init

    func testDefaultInit() {
        let entity = RoborockEntity(entityId: .roborock)
        XCTAssertEqual(entity.entityId, .roborock)
        XCTAssertEqual(entity.state, "Loading")
        XCTAssertFalse(entity.isCleaning)
        XCTAssertFalse(entity.isReturning)
        XCTAssertFalse(entity.isActive)
        XCTAssertEqual(entity.batteryLevel, -1)
        XCTAssertEqual(entity.error, "")
    }

    // MARK: - isCleaning

    func testIsCleaningWhenStateCleaning() {
        let entity = RoborockEntity(entityId: .roborock, state: "cleaning")
        XCTAssertTrue(entity.isCleaning)
        XCTAssertTrue(entity.isActive)
    }

    func testIsCleaningCaseInsensitive() {
        let entity = RoborockEntity(entityId: .roborock, state: "Cleaning")
        XCTAssertTrue(entity.isCleaning)
    }

    func testIsCleaningWhenStateIsSegmentCleaning() {
        let entity = RoborockEntity(entityId: .roborock, state: "segment cleaning")
        XCTAssertTrue(entity.isCleaning)
        XCTAssertTrue(entity.isActive)
    }

    func testIsCleaningFalseWhenIdle() {
        let entity = RoborockEntity(entityId: .roborock, state: "idle")
        XCTAssertFalse(entity.isCleaning)
    }

    func testIsCleaningFalseWhenDocked() {
        let entity = RoborockEntity(entityId: .roborock, state: "docked")
        XCTAssertFalse(entity.isCleaning)
    }

    // MARK: - isReturning

    func testIsReturningWhenStateIsReturningHome() {
        let entity = RoborockEntity(entityId: .roborock, state: "returning home")
        XCTAssertTrue(entity.isReturning)
        XCTAssertTrue(entity.isActive)
    }

    func testIsReturningWhenStateIsReturning() {
        let entity = RoborockEntity(entityId: .roborock, state: "returning")
        XCTAssertTrue(entity.isReturning)
        XCTAssertTrue(entity.isActive)
    }

    func testIsReturningCaseInsensitive() {
        let entity = RoborockEntity(entityId: .roborock, state: "Returning Home")
        XCTAssertTrue(entity.isReturning)
    }

    func testIsReturningFalseWhenCleaning() {
        let entity = RoborockEntity(entityId: .roborock, state: "cleaning")
        XCTAssertFalse(entity.isReturning)
    }

    // MARK: - isActive

    func testIsActiveWhenCleaningOrReturning() {
        XCTAssertTrue(RoborockEntity(entityId: .roborock, state: "cleaning").isActive)
        XCTAssertTrue(RoborockEntity(entityId: .roborock, state: "segment cleaning").isActive)
        XCTAssertTrue(RoborockEntity(entityId: .roborock, state: "returning").isActive)
        XCTAssertTrue(RoborockEntity(entityId: .roborock, state: "returning home").isActive)
    }

    func testIsActiveIsFalseWhenIdleOrDocked() {
        XCTAssertFalse(RoborockEntity(entityId: .roborock, state: "idle").isActive)
        XCTAssertFalse(RoborockEntity(entityId: .roborock, state: "docked").isActive)
        XCTAssertFalse(RoborockEntity(entityId: .roborock, state: "error").isActive)
        XCTAssertFalse(RoborockEntity(entityId: .roborock, state: "Loading").isActive)
    }

    // MARK: - cleanButtonTitle

    func testCleanButtonTitleWhenCleaning() {
        let entity = RoborockEntity(entityId: .roborock, state: "cleaning")
        XCTAssertEqual(entity.cleanButtonTitle, "Pausa")
    }

    func testCleanButtonTitleWhenNotCleaning() {
        let entity = RoborockEntity(entityId: .roborock, state: "docked")
        XCTAssertEqual(entity.cleanButtonTitle, "Dammsug")
    }

    // MARK: - returnButtonTitle

    func testReturnButtonTitleWhenReturning() {
        let entity = RoborockEntity(entityId: .roborock, state: "returning")
        XCTAssertEqual(entity.returnButtonTitle, "Pausa")
    }

    func testReturnButtonTitleWhenNotReturning() {
        let entity = RoborockEntity(entityId: .roborock, state: "docked")
        XCTAssertEqual(entity.returnButtonTitle, "Docka")
    }

    // MARK: - JSON Decoding

    func testDecodeFromJSON() throws {
        let json = Data("""
        {
            "entity_id": "vacuum.bob",
            "state": "cleaning",
            "attributes": {}
        }
        """.utf8)
        let entity = try JSONDecoder().decode(RoborockEntity.self, from: json)

        XCTAssertEqual(entity.entityId, .roborock)
        XCTAssertEqual(entity.state, "cleaning")
        XCTAssertTrue(entity.isCleaning)
        XCTAssertTrue(entity.isActive)
    }

    func testDecodeFromJSONWithDockedState() throws {
        let json = Data("""
        {
            "entity_id": "vacuum.bob",
            "state": "docked",
            "attributes": {}
        }
        """.utf8)
        let entity = try JSONDecoder().decode(RoborockEntity.self, from: json)

        XCTAssertEqual(entity.state, "docked")
        XCTAssertFalse(entity.isActive)
        XCTAssertEqual(entity.cleanButtonTitle, "Dammsug")
        XCTAssertEqual(entity.returnButtonTitle, "Docka")
    }

    func testDecodeFromJSONWithUnknownEntityIdFallsBackToUnknown() throws {
        let json = Data("""
        {
            "entity_id": "vacuum.unknown_vacuum",
            "state": "idle",
            "attributes": {}
        }
        """.utf8)
        let entity = try JSONDecoder().decode(RoborockEntity.self, from: json)
        XCTAssertEqual(entity.entityId, .unknown)
    }

    // MARK: - canUpdate / setNextUpdateTime

    func testDefaultNextUpdateIsInPastSoCanUpdateReturnsTrue() {
        let entity = RoborockEntity(entityId: .roborock)
        XCTAssertTrue(entity.canUpdate())
    }
}
