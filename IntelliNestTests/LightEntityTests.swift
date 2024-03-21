//
//  LightEntityTests.swift
//  IntelliNestTests
//
//  Created by Tobias on 2023-06-17.
//

@testable import IntelliNest
import XCTest

final class LightEntityTests: XCTestCase {
    var light: LightEntity!

    override func setUpWithError() throws {
        try? super.setUpWithError()

        light = LightEntity(entityId: .sofa, state: "off")
        light.brightness = 103
    }

    override func tearDownWithError() throws {
        light = nil
        try super.tearDownWithError()
    }

    func testDecode() throws {
        XCTAssertEqual(light.entityId, .sofa, "Failed to decode 'entityId'")
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
