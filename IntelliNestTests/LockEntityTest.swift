//
//  LockEntityTest.swift
//  IntelliNestTests
//
//  Created by Tobias on 2022-05-23.
//

import XCTest

@testable import IntelliNest
class LockEntityTest: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testStateToString() {
        // Given
        var lockEntity = LockEntity(entityId: EntityId.framdorren, state: "Loading")
        lockEntity.state = "unlocked"
        let translatedStateUnlocked = lockEntity.stateToString()
        lockEntity.state = "locked"
        let translatedStateLocked = lockEntity.stateToString()
        lockEntity.state = "locking"
        let translatedStateLocking = lockEntity.stateToString()
        lockEntity.state = "unlocking"
        let translatedStateUnlocking = lockEntity.stateToString()

        // When

        // Then
        XCTAssertEqual("olåst", translatedStateUnlocked)
        XCTAssertEqual("låst", translatedStateLocked)
        XCTAssertEqual("låser", translatedStateLocking)
        XCTAssertEqual("låser upp", translatedStateUnlocking)
    }

    func testActionText() {
        // Given
        var lockEntity = LockEntity(entityId: EntityId.framdorren, state: "Loading")
        lockEntity.state = "unlocked"
        let lockEntityUnlocked = lockEntity
        lockEntity.state = "locked"
        let lockEntityLocked = lockEntity
        lockEntity.state = "unlocking"
        let lockEntityUnlocking = lockEntity
        lockEntity.state = "locking"
        let lockEntityLocking = lockEntity

        // When

        // Then
        XCTAssertEqual("Lås", lockEntityUnlocked.actionText)
        XCTAssertEqual("Lås upp", lockEntityLocked.actionText)
        XCTAssertEqual("Låser upp", lockEntityUnlocking.actionText)
        XCTAssertEqual("Låser", lockEntityLocking.actionText)
    }

    func testCalculateIsActive() {
        // Given
        var lockEntity = LockEntity(entityId: EntityId.framdorren, state: "Loading")
        lockEntity.state = "unlocked"
        let lockEntityUnlocked = lockEntity
        lockEntity.state = "locked"
        let lockEntityLocked = lockEntity
        lockEntity.state = "unlocking"
        let lockEntityUnlocking = lockEntity
        lockEntity.state = "locking"
        let lockEntityLocking = lockEntity
        // When
        // ...

        // Then
        XCTAssertTrue(lockEntityUnlocked.isActive)
        XCTAssertFalse(lockEntityLocked.isActive)
        XCTAssertTrue(lockEntityUnlocking.isActive)
        XCTAssertTrue(lockEntityLocking.isActive)
    }
}
