@testable import IntelliNest
import XCTest

class InputNumberEntityTests: XCTestCase {
    func testInit() {
        let entity = InputNumberEntity(entityId: .thermKitchen)

        XCTAssertEqual(entity.entityId, .thermKitchen)
        XCTAssertEqual(entity.state, "Loading")
        XCTAssertEqual(entity.lastChanged, .distantPast)
        XCTAssertEqual(entity.lastUpdated, .distantPast)
        XCTAssertEqual(entity.isActive, false)
        XCTAssertEqual(entity.inputNumber, 0)
    }

    func testInitFromDecoder() throws {
        let json = Data("""
        {
            "entity_id": "input_number.kia_climate_temperature",
            "state": "21.0",
            "attributes": {
                "initial": null,
                "editable": true,
                "min": 16.0,
                "max": 26.0,
                "step": 0.5,
                "mode": "slider",
                "icon": "mdi:thermometer",
                "friendly_name": "Kia climate temperature"
            },
            "last_changed": "2023-02-24T05:40:30.846631+00:00",
            "last_updated": "2023-02-24T05:40:30.846631+00:00",
            "context": {
                "id": "01GT0YZVZY8XCG69BJ0HE9VAN1",
                "parent_id": null,
                "user_id": null
            }
        }
        """.utf8)
        let decoder = JSONDecoder()
        let date = try XCTUnwrap(Date.fromISO8601("2023-02-24T05:40:30.846631+00:00"))
        let entity = try decoder.decode(InputNumberEntity.self, from: json)

        XCTAssertEqual(entity.state, "21.0")
        XCTAssertEqual(entity.lastChanged, date)
        XCTAssertEqual(entity.lastUpdated, date)
        XCTAssertEqual(entity.isActive, false)
        XCTAssertEqual(entity.inputNumber, 21.0)
    }
}
