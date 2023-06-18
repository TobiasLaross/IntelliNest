//
//  LightEntityTests.swift
//  IntelliNestTests
//
//  Created by Tobias on 2023-06-17.
//

import XCTest
@testable import IntelliNest

final class LightEntityTests: XCTestCase {
    var light: LightEntity!

    override func setUpWithError() throws {
        try? super.setUpWithError()

        let json = """
        {
            "entity_id": "light.soffbordet",
            "state": "off",
            "attributes": {
                "brightness": 103
            }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        light = try decoder.decode(LightEntity.self, from: json)
    }

    override func tearDownWithError() throws {
        light = nil
        try super.tearDownWithError()
    }

    func testDecode() throws {
        XCTAssertEqual(light.entityId, .soffbordet, "Failed to decode 'entityId'")
        XCTAssertEqual(light.state, "off", "Failed to decode 'state'")
        XCTAssertEqual(light.brightness, 103, "Failed to decode 'brightness'")
        XCTAssertEqual(light.isActive, false, "Failed to decode 'isActive'")
        XCTAssertNotNil(light.nextUpdate, "Failed to decode 'nextUpdate'")
    }

    func testUpdateIsActive() {
        light.updateIsActive()
        XCTAssertEqual(light.isActive, false, "Failed to update 'isActive'")
    }

    func testSetNextUpdateTime() {
        light.setNextUpdateTime()
        XCTAssertNotNil(light.nextUpdate, "Failed to set 'nextUpdate'")
    }

    func testEquality() throws {
        let copy = light
        XCTAssertEqual(light, copy, "Failed to test equality")
    }
}
