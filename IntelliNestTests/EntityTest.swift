import XCTest
@testable import IntelliNest

class EntityTests: XCTestCase {
    func testInit() {
        let entityId = EntityId.coffeeMachine
        let entity = Entity(entityId: entityId)

        XCTAssertEqual(entity.entityId, entityId)
        XCTAssertEqual(entity.state, "Loading")
        XCTAssertEqual(entity.lastChanged, .distantPast)
        XCTAssertEqual(entity.lastUpdated, .distantPast)
        XCTAssertEqual(entity.isActive, false)
        XCTAssertEqual(entity.date, .distantPast)
    }

    func testInitFromDecoder() throws {
        let json = """
        {
            "entity_id": "switch.kaffemaskinen",
            "state": "off",
            "attributes": {
                "icon": "mdi:coffee",
                "friendly_name": "Kaffemaskinen"
            },
            "last_changed": "2023-06-17T13:30:00.215607+00:00",
            "last_updated": "2023-06-17T13:30:00.215607+00:00",
            "context": {
                "id": "01H34RRR0S44WDDDFED4GF9DVG",
                "parent_id": null,
                "user_id": null
            }
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        let date = try XCTUnwrap(Date.fromISO8601("2023-06-17T13:30:00.215607+00:00"))
        let entity = try decoder.decode(Entity.self, from: json)

        XCTAssertEqual(entity.entityId, EntityId.coffeeMachine)
        XCTAssertEqual(entity.state, "off")
        XCTAssertEqual(entity.lastChanged, date)
        XCTAssertEqual(entity.lastUpdated, date)
        XCTAssertEqual(entity.isActive, false)
        XCTAssertEqual(entity.date, .distantPast)
    }

    func testDecodeWithStateAsDateTime() throws {
        let json = """
        {
            "entity_id": "input_datetime.kia_climate3",
            "state": "2023-06-22 19:25:00",
            "last_changed": "2023-06-21T22:00:00.300355+00:00",
            "last_updated": "2023-06-21T22:00:00.300355+00:00"
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        let entity = try decoder.decode(Entity.self, from: json)

        // Convert the entity.date to a string format to compare
        let localDateFormatter = DateFormatter()
        localDateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let dateString = localDateFormatter.string(from: entity.date)

        let expectedDateString = "2023-06-22 19:25:00"

        XCTAssertEqual(dateString, expectedDateString)
    }

    func testRecentlyUpdated() {
        var entity = Entity(entityId: .coffeeMachine)
        let now = Date()
        entity.lastUpdated = now
        XCTAssertTrue(entity.recentlyUpdated())

        let recentPastDate = Date().addingTimeInterval(-11 * 60)
        entity.lastUpdated = recentPastDate
        XCTAssertTrue(entity.recentlyUpdated())

        let pastDate = Date().addingTimeInterval(-21 * 60)
        entity.lastUpdated = pastDate
        XCTAssertFalse(entity.recentlyUpdated())
    }

    func testUpdateIsActive() {
        var entity = Entity(entityId: .coffeeMachine)
        entity.state = "On"
        entity.updateIsActive()
        XCTAssertTrue(entity.isActive)

        entity.state = "Off"
        entity.updateIsActive()
        XCTAssertFalse(entity.isActive)
    }

    func testSetNextUpdateTime() {
        var entity = Entity(entityId: .coffeeMachine)
        entity.setNextUpdateTime()
        XCTAssertGreaterThan(entity.nextUpdate.timeIntervalSinceNow, 0.0)
    }

    func testInitWithDifferentStates() {
        let entityId = EntityId.coffeeMachine
        let entity = Entity(entityId: entityId, state: "On")

        XCTAssertEqual(entity.entityId, entityId)
        XCTAssertEqual(entity.state, "On")
        XCTAssertEqual(entity.isActive, true)
    }

    func testDecodeWithDifferentDateFormats() throws {
        let json = """
        {
            "entity_id": "switch.kaffemaskinen",
            "state": "off",
            "last_changed": "2023-06-17T13:30:00.215607+00:00",
            "last_updated": "2023-06-17T13:30:00.215607+00:00"
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        let entity = try decoder.decode(Entity.self, from: json)

        // Convert the dates to a common format that doesn't include milliseconds
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")

        let lastChangedString = dateFormatter.string(from: entity.lastChanged)
        let lastUpdatedString = dateFormatter.string(from: entity.lastUpdated)

        let expectedDateString = "2023-06-17 13:30:00"

        XCTAssertEqual(lastChangedString, expectedDateString)
        XCTAssertEqual(lastUpdatedString, expectedDateString)
    }

    func testDecodeWithIncompleteData() throws {
        // A test case with missing data
        let json = """
        {
            "entity_id": "switch.kaffemaskinen",
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        let entity = try decoder.decode(Entity.self, from: json)

        XCTAssertEqual(entity.entityId, EntityId.coffeeMachine)
        XCTAssertEqual(entity.state, "Loading")
        XCTAssertEqual(entity.lastChanged, .distantPast)
        XCTAssertEqual(entity.lastUpdated, .distantPast)
        XCTAssertEqual(entity.isActive, false)
        XCTAssertEqual(entity.date, .distantPast)
    }

    func testEqualityOperator() {
        let entity1 = Entity(entityId: .coffeeMachine, state: "On")
        let entity2 = Entity(entityId: .coffeeMachine, state: "On")
        let entity3 = Entity(entityId: .coffeeMachine, state: "Off")

        XCTAssertTrue(entity1 == entity2)
        XCTAssertFalse(entity1 == entity3)
    }
}
