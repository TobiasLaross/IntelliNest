@testable import IntelliNest
import XCTest

// Tests for the Lockable protocol extension, using LockEntity as the concrete type.
class LockableTests: XCTestCase {
    // MARK: - actionText

    func testActionTextWhenUnlocked() {
        var entity = LockEntity(entityId: .storageLock)
        entity.state = "unlocked"
        XCTAssertEqual(entity.actionText, "Lås")
    }

    func testActionTextWhenLocked() {
        var entity = LockEntity(entityId: .storageLock)
        entity.state = "locked"
        XCTAssertEqual(entity.actionText, "Lås upp")
    }

    func testActionTextWhenUnlocking() {
        var entity = LockEntity(entityId: .storageLock)
        entity.state = "unlocking"
        XCTAssertEqual(entity.actionText, "Låser upp")
    }

    func testActionTextWhenLocking() {
        var entity = LockEntity(entityId: .storageLock)
        entity.state = "locking"
        XCTAssertEqual(entity.actionText, "Låser")
    }

    func testActionTextWhenUnknownDefaultsToUnlock() {
        let entity = LockEntity(entityId: .storageLock, state: "Loading")
        XCTAssertEqual(entity.actionText, "Lås upp")
    }

    // MARK: - isActive

    func testIsActiveWhenUnlocked() {
        var entity = LockEntity(entityId: .storageLock)
        entity.state = "unlocked"
        XCTAssertTrue(entity.isActive)
    }

    func testIsActiveWhenUnlocking() {
        var entity = LockEntity(entityId: .storageLock)
        entity.state = "unlocking"
        XCTAssertTrue(entity.isActive)
    }

    func testIsActiveWhenLocking() {
        var entity = LockEntity(entityId: .storageLock)
        entity.state = "locking"
        XCTAssertTrue(entity.isActive)
    }

    func testIsActiveIsFalseWhenLocked() {
        var entity = LockEntity(entityId: .storageLock)
        entity.state = "locked"
        XCTAssertFalse(entity.isActive)
    }

    func testIsActiveIsFalseWhenUnknown() {
        let entity = LockEntity(entityId: .storageLock, state: "Loading")
        XCTAssertFalse(entity.isActive)
    }

    // MARK: - isLoading

    // When expectedState differs from lockState and expectedState is set → isLoading = true
    func testIsLoadingWhenExpectedStateDiffers() {
        var entity = LockEntity(entityId: .storageLock)
        entity.state = "locked"             // lockState = .locked
        entity.expectedState = .unlocked    // expecting unlock
        XCTAssertTrue(entity.isLoading)
    }

    // When expectedState matches lockState → isLoading = false
    func testIsLoadingFalseWhenExpectedStateMatches() {
        var entity = LockEntity(entityId: .storageLock)
        entity.state = "locked"
        // Setting state triggers: if lockState == expectedState → expectedState = .unknown
        // So we can't set expectedState = .locked and expect isLoading = true.
        // Instead test: expectedState == .unknown → isLoading depends on lockState != .unknown
        XCTAssertFalse(entity.isLoading) // expectedState is .unknown, lockState is .locked → not loading
    }

    // When lockState is .unknown and expectedStateSetDate is recent → isLoading = true
    func testIsLoadingTrueWhenLockStateUnknownAndExpectedStateDateIsRecent() {
        var entity = LockEntity(entityId: .storageLock, state: "Loading") // lockState = .unknown
        // Set expectedState to .unknown but simulate a recent expectedStateSetDate
        entity.expectedStateSetDate = Date() // just set
        entity.expectedState = .unknown
        // isLoading = (expectedState != .unknown && lockState != expectedState)
        //              || (lockState == .unknown && !expectedStateIsOld)
        // = false || (true && !false) = true
        XCTAssertTrue(entity.isLoading)
    }

    // When lockState is .unknown and expectedStateSetDate is old (>30s ago) → isLoading = false
    func testIsLoadingFalseWhenLockStateUnknownAndExpectedStateDateIsOld() {
        var entity = LockEntity(entityId: .storageLock, state: "Loading") // lockState = .unknown
        entity.expectedStateSetDate = Date().addingTimeInterval(-31) // 31 seconds ago
        entity.expectedState = .unknown
        // isLoading = false || (true && !true) = false
        XCTAssertFalse(entity.isLoading)
    }

    // MARK: - expectedStateIsOld

    func testExpectedStateIsOldWhenSetDateIsNil() {
        let entity = LockEntity(entityId: .storageLock)
        // No expectedState has been set → expectedStateSetDate is nil
        XCTAssertFalse(entity.expectedStateIsOld)
    }

    func testExpectedStateIsOldWhenSetDateIsRecent() {
        var entity = LockEntity(entityId: .storageLock)
        entity.expectedStateSetDate = Date()
        XCTAssertFalse(entity.expectedStateIsOld)
    }

    func testExpectedStateIsOldWhenSetDateIsOver30SecondsAgo() {
        var entity = LockEntity(entityId: .storageLock)
        entity.expectedStateSetDate = Date().addingTimeInterval(-31)
        XCTAssertTrue(entity.expectedStateIsOld)
    }

    func testExpectedStateSetDateIsUpdatedWhenExpectedStateChanges() {
        var entity = LockEntity(entityId: .storageLock)
        XCTAssertNil(entity.expectedStateSetDate)
        entity.expectedState = .locked
        XCTAssertNotNil(entity.expectedStateSetDate)
        XCTAssertFalse(entity.expectedStateIsOld)
    }

    // MARK: - stateToString

    func testStateToStringForLockedState() {
        var entity = LockEntity(entityId: .storageLock)
        entity.state = "locked"
        XCTAssertEqual(entity.stateToString(), "låst")
    }

    func testStateToStringForUnlockedState() {
        var entity = LockEntity(entityId: .storageLock)
        entity.state = "unlocked"
        XCTAssertEqual(entity.stateToString(), "olåst")
    }

    func testStateToStringForUnlockingState() {
        var entity = LockEntity(entityId: .storageLock)
        entity.state = "unlocking"
        XCTAssertEqual(entity.stateToString(), "låser upp")
    }

    func testStateToStringForLockingState() {
        var entity = LockEntity(entityId: .storageLock)
        entity.state = "locking"
        XCTAssertEqual(entity.stateToString(), "låser")
    }

    func testStateToStringForUnknownStateFallsBackToRawValue() {
        let entity = LockEntity(entityId: .storageLock, state: "Loading")
        // lockState = .unknown, rawValue = "unknown"
        XCTAssertEqual(entity.stateToString(), LockState.unknown.rawValue)
    }

    // MARK: - LockEntity.state didSet clears expectedState when lockState matches

    func testStateDidSetClearsExpectedStateWhenMatched() {
        var entity = LockEntity(entityId: .storageLock)
        entity.expectedState = .locked
        // Setting state to "locked" → lockState = .locked == expectedState → expectedState cleared
        entity.state = "locked"
        XCTAssertEqual(entity.expectedState, .unknown)
    }

    func testStateDidSetClearsExpectedStateWhenExpectedStateIsOld() {
        var entity = LockEntity(entityId: .storageLock)
        entity.expectedState = .unlocked
        entity.expectedStateSetDate = Date().addingTimeInterval(-31) // mark as old
        // Setting any state when expectedStateIsOld → expectedState is also cleared
        entity.state = "locked"
        XCTAssertEqual(entity.expectedState, .unknown)
    }

    // MARK: - LockEntity.id mapping

    func testIDMappingForStorageLock() {
        let entity = LockEntity(entityId: .storageLock)
        XCTAssertEqual(entity.id, .storageDoor)
    }

    func testIDMappingForLynkDoorLock() {
        let entity = LockEntity(entityId: .lynkDoorLock)
        XCTAssertEqual(entity.id, .lynkDoor)
    }

    func testIDMappingForUnknownEntityDefaultsToStorageDoor() {
        let entity = LockEntity(entityId: .unknown)
        XCTAssertEqual(entity.id, .storageDoor)
    }

    // MARK: - shouldReload

    func testShouldReloadIsTrueWhenActive() {
        var entity = LockEntity(entityId: .storageLock)
        entity.state = "unlocked" // isActive = true
        XCTAssertTrue(entity.shouldReload())
    }

    func testShouldReloadIsTrueWhenLoading() {
        var entity = LockEntity(entityId: .storageLock)
        entity.state = "locked"
        entity.expectedState = .unlocked // triggers isLoading
        XCTAssertTrue(entity.shouldReload())
    }

    func testShouldReloadIsFalseWhenLockedAndNoExpectedState() {
        var entity = LockEntity(entityId: .storageLock)
        entity.state = "locked"
        XCTAssertFalse(entity.shouldReload())
    }

    // MARK: - setNextUpdateTime

    func testSetNextUpdateTimeSetsUpdateInFuture() {
        var entity = LockEntity(entityId: .storageLock)
        entity.setNextUpdateTime()
        XCTAssertGreaterThan(entity.nextUpdate.timeIntervalSinceNow, 0)
    }
}
