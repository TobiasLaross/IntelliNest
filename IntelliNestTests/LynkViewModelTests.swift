@testable import IntelliNest
import XCTest

@MainActor
// swiftlint:disable type_body_length
class LynkViewModelTests: XCTestCase {
    var viewModel: LynkViewModel!
    var restAPIService: RestAPIService!
    var urlCreator: URLCreator!

    override func setUp() async throws {
        URLProtocolStub.startInterceptingRequests()
        let stubbedSession = URLProtocolStub.createStubbedURLSession()
        urlCreator = URLCreator(session: stubbedSession)
        urlCreator.connectionState = .local
        restAPIService = RestAPIService(
            urlCreator: urlCreator,
            session: stubbedSession,
            setErrorBannerText: { _, _ in },
            repeatReloadAction: { _ in }
        )
        viewModel = LynkViewModel(restAPIService: restAPIService)
        // Seed both time keys so reload() skips forceUpdate and the 5-second sleep.
        UserDefaults.shared.setValue(Date.now, forKey: StorageKeys.lynkReloadTime.rawValue)
        UserDefaults.shared.setValue(Date.now, forKey: StorageKeys.leafReloadTime.rawValue)
    }

    override func tearDown() async throws {
        URLProtocolStub.stopInterceptingRequests()
        UserDefaults.shared.removeObject(forKey: StorageKeys.lynkReloadTime.rawValue)
        UserDefaults.shared.removeObject(forKey: StorageKeys.leafReloadTime.rawValue)
        viewModel = nil
        restAPIService = nil
        urlCreator = nil
    }

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertEqual(viewModel.lynkClimateHeating.state, "Loading")
        XCTAssertEqual(viewModel.isEngineRunning.state, "Loading")
        XCTAssertEqual(viewModel.lynkInteriorTemperature.state, "Loading")
        XCTAssertEqual(viewModel.lynkExteriorTemperature.state, "Loading")
        XCTAssertEqual(viewModel.lynkBattery.state, "Loading")
        XCTAssertEqual(viewModel.lynkBatteryDistance.state, "Loading")
        XCTAssertEqual(viewModel.fuel.state, "Loading")
        XCTAssertEqual(viewModel.fuelDistance.state, "Loading")
        XCTAssertEqual(viewModel.lynkDoorLock.state, "Loading")
        XCTAssertEqual(viewModel.lynkDoorLock.lockState, .unknown)
        XCTAssertEqual(viewModel.address.state, "Loading")
        XCTAssertEqual(viewModel.lynkChargerState.state, "Loading")
        XCTAssertEqual(viewModel.lynkChargerConnectionStatus.state, "Loading")
        XCTAssertEqual(viewModel.lynkTimeUntilCharged.state, "Loading")
        XCTAssertEqual(viewModel.lynkCarUpdatedAt.state, "Loading")
        XCTAssertEqual(viewModel.lynkClimateUpdatedAt.state, "Loading")
        XCTAssertEqual(viewModel.doorLockUpdatedAt.state, "Loading")
        XCTAssertEqual(viewModel.batteryUpdatedAt.state, "Loading")
        XCTAssertEqual(viewModel.fuelUpdatedAt.state, "Loading")
        XCTAssertEqual(viewModel.addressUpdatedAt.state, "Loading")
        XCTAssertEqual(viewModel.chargerUpdatedAt.state, "Loading")
        XCTAssertEqual(viewModel.leafClimateTimer.state, "Loading")
        XCTAssertEqual(viewModel.leafBattery.state, "Loading")
        XCTAssertEqual(viewModel.leafRangeAC.state, "Loading")
        XCTAssertEqual(viewModel.isLeafCharging.state, "Loading")
        XCTAssertEqual(viewModel.isLeafPluggedIn.state, "Loading")
        XCTAssertEqual(viewModel.leafLastPoll.state, "Loading")
        XCTAssertFalse(viewModel.isLynkFlashing)
        XCTAssertFalse(viewModel.isShowingHeaterOptions)
        XCTAssertNil(viewModel.lynkAirConditionInitiatedTime)
        XCTAssertNil(viewModel.engineInitiatedTime)
        XCTAssertNil(viewModel.leafAirConditionInitiatedTime)
    }

    // MARK: - reload(entityID:state:) dispatch

    func testReloadUpdatesLynkClimateHeating() {
        viewModel.reload(entityID: .lynkClimateHeating, state: "on")
        XCTAssertEqual(viewModel.lynkClimateHeating.state, "on")
    }

    func testReloadUpdatesLynkClimateHeatingLastChanged() {
        let date = Date(timeIntervalSinceReferenceDate: 700_000_000)
        viewModel.reload(entityID: .lynkClimateHeating, state: "on", lastChanged: date)
        XCTAssertEqual(viewModel.lynkClimateHeating.lastChanged, date)
    }

    func testReloadDoesNotOverwriteLynkClimateHeatingLastChangedWhenNil() {
        let original = viewModel.lynkClimateHeating.lastChanged
        viewModel.reload(entityID: .lynkClimateHeating, state: "off", lastChanged: nil)
        XCTAssertEqual(viewModel.lynkClimateHeating.lastChanged, original)
    }

    func testReloadUpdatesEngineRunning() {
        viewModel.reload(entityID: .lynkEngineRunning, state: "on")
        XCTAssertEqual(viewModel.isEngineRunning.state, "on")
    }

    func testReloadUpdatesEngineRunningLastChanged() {
        let date = Date(timeIntervalSinceReferenceDate: 700_000_001)
        viewModel.reload(entityID: .lynkEngineRunning, state: "on", lastChanged: date)
        XCTAssertEqual(viewModel.isEngineRunning.lastChanged, date)
    }

    func testReloadUpdatesTemperatureInterior() {
        viewModel.reload(entityID: .lynkTemperatureInterior, state: "21.5")
        XCTAssertEqual(viewModel.lynkInteriorTemperature.state, "21.5")
    }

    func testReloadUpdatesTemperatureInteriorLastChanged() {
        let date = Date(timeIntervalSinceReferenceDate: 700_000_002)
        viewModel.reload(entityID: .lynkTemperatureInterior, state: "21.5", lastChanged: date)
        XCTAssertEqual(viewModel.lynkInteriorTemperature.lastChanged, date)
    }

    func testReloadUpdatesTemperatureExterior() {
        viewModel.reload(entityID: .lynkTemperatureExterior, state: "5.2")
        XCTAssertEqual(viewModel.lynkExteriorTemperature.state, "5.2")
    }

    func testReloadUpdatesTemperatureExteriorLastChanged() {
        let date = Date(timeIntervalSinceReferenceDate: 700_000_003)
        viewModel.reload(entityID: .lynkTemperatureExterior, state: "5.2", lastChanged: date)
        XCTAssertEqual(viewModel.lynkExteriorTemperature.lastChanged, date)
    }

    func testReloadUpdatesLynkDoorLock() {
        viewModel.reload(entityID: .lynkDoorLock, state: "locked")
        XCTAssertEqual(viewModel.lynkDoorLock.state, "locked")
        XCTAssertEqual(viewModel.lynkDoorLock.lockState, .locked)
    }

    func testReloadUpdatesLynkBattery() {
        viewModel.reload(entityID: .lynkBattery, state: "75")
        XCTAssertEqual(viewModel.lynkBattery.state, "75")
    }

    func testReloadUpdatesLynkBatteryDistance() {
        viewModel.reload(entityID: .lynkBatteryDistance, state: "120 km")
        XCTAssertEqual(viewModel.lynkBatteryDistance.state, "120 km")
    }

    func testReloadUpdatesLynkFuel() {
        viewModel.reload(entityID: .lynkFuel, state: "40")
        XCTAssertEqual(viewModel.fuel.state, "40")
    }

    func testReloadUpdatesLynkFuelDistance() {
        viewModel.reload(entityID: .lynkFuelDistance, state: "300 km")
        XCTAssertEqual(viewModel.fuelDistance.state, "300 km")
    }

    func testReloadUpdatesLynkAddress() {
        viewModel.reload(entityID: .lynkAddress, state: "Main Street 1")
        XCTAssertEqual(viewModel.address.state, "Main Street 1")
    }

    func testReloadUpdatesLynkChargeState() {
        viewModel.reload(entityID: .lynkChargeState, state: "Charging")
        XCTAssertEqual(viewModel.lynkChargerState.state, "Charging")
    }

    func testReloadUpdatesLynkChargerConnectionStatus() {
        viewModel.reload(entityID: .lynkChargerConnectionStatus, state: "Connected")
        XCTAssertEqual(viewModel.lynkChargerConnectionStatus.state, "Connected")
    }

    func testReloadUpdatesLynkTimeUntilCharged() {
        viewModel.reload(entityID: .lynkTimeUntilCharged, state: "45")
        XCTAssertEqual(viewModel.lynkTimeUntilCharged.state, "45")
    }

    func testReloadUpdatesLynkCarUpdatedAt() {
        viewModel.reload(entityID: .lynkCarUpdatedAt, state: "2024-01-01T10:00:00")
        XCTAssertEqual(viewModel.lynkCarUpdatedAt.state, "2024-01-01T10:00:00")
    }

    func testReloadUpdatesLynkClimateUpdatedAt() {
        viewModel.reload(entityID: .lynkClimateUpdatedAt, state: "2024-01-01T10:05:00")
        XCTAssertEqual(viewModel.lynkClimateUpdatedAt.state, "2024-01-01T10:05:00")
    }

    func testReloadUpdatesLynkDoorLockUpdatedAt() {
        viewModel.reload(entityID: .lynkDoorLockUpdatedAt, state: "2024-01-01T10:10:00")
        XCTAssertEqual(viewModel.doorLockUpdatedAt.state, "2024-01-01T10:10:00")
    }

    func testReloadUpdatesLynkBatteryUpdatedAt() {
        viewModel.reload(entityID: .lynkBatteryUpdatedAt, state: "2024-01-01T10:15:00")
        XCTAssertEqual(viewModel.batteryUpdatedAt.state, "2024-01-01T10:15:00")
    }

    func testReloadUpdatesLynkFuelUpdatedAt() {
        viewModel.reload(entityID: .lynkFuelUpdatedAt, state: "2024-01-01T10:20:00")
        XCTAssertEqual(viewModel.fuelUpdatedAt.state, "2024-01-01T10:20:00")
    }

    func testReloadUpdatesLynkAddressUpdatedAt() {
        viewModel.reload(entityID: .lynkAddressUpdatedAt, state: "2024-01-01T10:25:00")
        XCTAssertEqual(viewModel.addressUpdatedAt.state, "2024-01-01T10:25:00")
    }

    func testReloadUpdatesLynkChargerUpdatedAt() {
        viewModel.reload(entityID: .lynkChargerUpdatedAt, state: "2024-01-01T10:30:00")
        XCTAssertEqual(viewModel.chargerUpdatedAt.state, "2024-01-01T10:30:00")
    }

    func testReloadUpdatesLeafACTimer() {
        viewModel.reload(entityID: .leafACTimer, state: "2024-01-01T11:00:00+00:00")
        XCTAssertEqual(viewModel.leafClimateTimer.state, "2024-01-01T11:00:00+00:00")
    }

    func testReloadUpdatesLeafACTimerLastChanged() {
        let date = Date(timeIntervalSinceReferenceDate: 700_000_004)
        viewModel.reload(entityID: .leafACTimer, state: "2024-01-01T11:00:00+00:00", lastChanged: date)
        XCTAssertEqual(viewModel.leafClimateTimer.lastChanged, date)
    }

    func testReloadDoesNotOverwriteLeafACTimerLastChangedWhenNil() {
        let original = viewModel.leafClimateTimer.lastChanged
        viewModel.reload(entityID: .leafACTimer, state: "2024-01-01T11:00:00+00:00", lastChanged: nil)
        XCTAssertEqual(viewModel.leafClimateTimer.lastChanged, original)
    }

    func testReloadUpdatesLeafBattery() {
        viewModel.reload(entityID: .leafBattery, state: "80")
        XCTAssertEqual(viewModel.leafBattery.state, "80")
    }

    func testReloadUpdatesLeafRangeAC() {
        viewModel.reload(entityID: .leafRangeAC, state: "200")
        XCTAssertEqual(viewModel.leafRangeAC.state, "200")
    }

    func testReloadUpdatesLeafCharging() {
        viewModel.reload(entityID: .leafCharging, state: "on")
        XCTAssertEqual(viewModel.isLeafCharging.state, "on")
    }

    func testReloadUpdatesLeafPluggedIn() {
        viewModel.reload(entityID: .leafPluggedIn, state: "on")
        XCTAssertEqual(viewModel.isLeafPluggedIn.state, "on")
    }

    func testReloadUpdatesLeafLastPoll() {
        viewModel.reload(entityID: .leafLastPoll, state: "2024-01-01T12:00:00")
        XCTAssertEqual(viewModel.leafLastPoll.state, "2024-01-01T12:00:00")
    }

    func testReloadUnknownEntityIDDoesNotCrash() {
        // .coffeeMachine is not in LynkViewModel's switch — exercises the default/error branch
        viewModel.reload(entityID: .coffeeMachine, state: "on")
        // No crash; no lynk state mutated
        XCTAssertEqual(viewModel.lynkClimateHeating.state, "Loading")
    }

    // MARK: - Computed Properties

    func testIsLynkAirConditionActive_whenOn() {
        viewModel.reload(entityID: .lynkClimateHeating, state: "on")
        XCTAssertTrue(viewModel.isLynkAirConditionActive)
    }

    func testIsLynkAirConditionActive_whenOff() {
        viewModel.reload(entityID: .lynkClimateHeating, state: "off")
        XCTAssertFalse(viewModel.isLynkAirConditionActive)
    }

    func testIsLynkUnlocked_whenUnlocked() {
        // Must use reload() to exercise the state didSet → lockState assignment
        viewModel.reload(entityID: .lynkDoorLock, state: "unlocked")
        XCTAssertTrue(viewModel.isLynkUnlocked)
    }

    func testIsLynkUnlocked_whenLocked() {
        viewModel.reload(entityID: .lynkDoorLock, state: "locked")
        XCTAssertFalse(viewModel.isLynkUnlocked)
    }

    func testDoorLockTitle_whenUnlocked() {
        viewModel.reload(entityID: .lynkDoorLock, state: "unlocked")
        XCTAssertEqual(viewModel.doorLockTitle, "Lås")
    }

    func testDoorLockTitle_whenLocked() {
        viewModel.reload(entityID: .lynkDoorLock, state: "locked")
        XCTAssertEqual(viewModel.doorLockTitle, "Lås upp")
    }

    func testLynkClimateTitle_whenActive() {
        viewModel.reload(entityID: .lynkClimateHeating, state: "on")
        XCTAssertEqual(viewModel.lynkClimateTitle, "Stäng av")
    }

    func testLynkClimateTitle_whenLoadingWindow() {
        // AC is off but initiated recently → loading branch also returns "Stäng av"
        viewModel.reload(entityID: .lynkClimateHeating, state: "off")
        viewModel.lynkAirConditionInitiatedTime = Date()
        XCTAssertEqual(viewModel.lynkClimateTitle, "Stäng av")
    }

    func testLynkClimateTitle_whenInactiveAndNotLoading() {
        XCTAssertEqual(viewModel.lynkClimateTitle, "Starta")
    }

    func testIsCharging_whenExactlyCharging() {
        viewModel.reload(entityID: .lynkChargeState, state: "Charging")
        XCTAssertTrue(viewModel.isCharging)
    }

    func testIsCharging_caseSensitive_lowercaseReturnsFalse() {
        // LynkViewModel does NOT lowercase — exact match required
        viewModel.reload(entityID: .lynkChargeState, state: "charging")
        XCTAssertFalse(viewModel.isCharging)
    }

    func testIsCharging_whenNotCharging() {
        viewModel.reload(entityID: .lynkChargeState, state: "Not Charging")
        XCTAssertFalse(viewModel.isCharging)
    }

    func testChargerStateDescription_whenCharging() {
        viewModel.reload(entityID: .lynkChargeState, state: "Charging")
        viewModel.reload(entityID: .lynkTimeUntilCharged, state: "45")
        XCTAssertTrue(viewModel.chargerStateDescription.contains("45"))
        XCTAssertTrue(viewModel.chargerStateDescription.contains("Laddar"))
    }

    func testChargerStateDescription_whenNotCharging() {
        viewModel.reload(entityID: .lynkChargeState, state: "Not Charging")
        XCTAssertEqual(viewModel.chargerStateDescription, "Laddar inte")
    }

    func testLynkChargerConnectionDescription_whenCharging() {
        viewModel.reload(entityID: .lynkChargeState, state: "Charging")
        XCTAssertEqual(viewModel.lynkChargerConnectionDescription, "laddar")
    }

    func testLynkChargerConnectionDescription_whenPowerNotActivated() {
        viewModel.reload(entityID: .lynkChargerConnectionStatus, state: "Power Not Activated")
        XCTAssertEqual(viewModel.lynkChargerConnectionDescription, "är inkopplad med ström tillgänglig")
    }

    func testLynkChargerConnectionDescription_whenConnected() {
        viewModel.reload(entityID: .lynkChargerConnectionStatus, state: "Connected")
        XCTAssertEqual(viewModel.lynkChargerConnectionDescription, "är inkopplad med ström tillgänglig")
    }

    func testLynkChargerConnectionDescription_whenDisconnected() {
        viewModel.reload(entityID: .lynkChargerConnectionStatus, state: "Disconnected")
        XCTAssertEqual(viewModel.lynkChargerConnectionDescription, "är inte inkopplad")
    }

    func testLynkChargerConnectionDescription_unknownStateFallback() {
        viewModel.reload(entityID: .lynkChargeState, state: "Unknown")
        viewModel.reload(entityID: .lynkChargerConnectionStatus, state: "SomeNewState")
        XCTAssertTrue(viewModel.lynkChargerConnectionDescription.contains("SomeNewState"))
    }

    func testLeafClimateTimerRemaining_futureDate_returnsPositiveMinutes() {
        let futureDate = Date().addingTimeInterval(30 * 60)
        let formatter = ISO8601DateFormatter()
        viewModel.reload(entityID: .leafACTimer, state: formatter.string(from: futureDate))
        let remaining = viewModel.leafClimateTimerRemaining
        XCTAssertNotNil(remaining)
        XCTAssertGreaterThan(remaining!, 0)
    }

    func testLeafClimateTimerRemaining_pastDate_returnsNil() {
        let pastDate = Date().addingTimeInterval(-60)
        let formatter = ISO8601DateFormatter()
        viewModel.reload(entityID: .leafACTimer, state: formatter.string(from: pastDate))
        XCTAssertNil(viewModel.leafClimateTimerRemaining)
    }

    func testLeafClimateTimerRemaining_unavailable_returnsNil() {
        viewModel.reload(entityID: .leafACTimer, state: "unavailable")
        XCTAssertNil(viewModel.leafClimateTimerRemaining)
    }

    func testLeafClimateTimerRemaining_malformedString_returnsNil() {
        viewModel.reload(entityID: .leafACTimer, state: "not-a-date")
        XCTAssertNil(viewModel.leafClimateTimerRemaining)
    }

    func testIsLeafAirConditionActive_whenTimerInFuture() {
        let futureDate = Date().addingTimeInterval(20 * 60)
        let formatter = ISO8601DateFormatter()
        viewModel.reload(entityID: .leafACTimer, state: formatter.string(from: futureDate))
        XCTAssertTrue(viewModel.isLeafAirConditionActive)
    }

    func testIsLeafAirConditionActive_whenTimerExpired() {
        viewModel.reload(entityID: .leafACTimer, state: "unavailable")
        XCTAssertFalse(viewModel.isLeafAirConditionActive)
    }

    func testIsLynkAirConditionLoading_withRecentInitiatedTime() {
        viewModel.reload(entityID: .lynkClimateHeating, state: "off")
        viewModel.lynkAirConditionInitiatedTime = Date()
        XCTAssertTrue(viewModel.isLynkAirConditionLoading)
    }

    func testIsLynkAirConditionLoading_afterFiveMinutes_returnsFalse() {
        viewModel.reload(entityID: .lynkClimateHeating, state: "off")
        viewModel.lynkAirConditionInitiatedTime = Date().addingTimeInterval(-(5 * 60 + 1))
        XCTAssertFalse(viewModel.isLynkAirConditionLoading)
    }

    func testIsEngineLoading_withRecentInitiatedTime() {
        viewModel.reload(entityID: .lynkEngineRunning, state: "off")
        viewModel.engineInitiatedTime = Date()
        XCTAssertTrue(viewModel.isEngineLoading)
    }

    func testIsEngineLoading_afterFiveMinutes_returnsFalse() {
        viewModel.reload(entityID: .lynkEngineRunning, state: "off")
        viewModel.engineInitiatedTime = Date().addingTimeInterval(-(5 * 60 + 1))
        XCTAssertFalse(viewModel.isEngineLoading)
    }

    // MARK: - Toggle Actions

    func testLockDoors_setsExpectedStateLocked() {
        viewModel.lockDoors()
        XCTAssertEqual(viewModel.lynkDoorLock.expectedState, .locked)
    }

    func testUnlockDoors_setsExpectedStateUnlocked() {
        viewModel.unlockDoors()
        XCTAssertEqual(viewModel.lynkDoorLock.expectedState, .unlocked)
    }

    func testToggleDoorLock_whenLocked_callsUnlock() {
        viewModel.reload(entityID: .lynkDoorLock, state: "locked")
        viewModel.toggleDoorLock()
        XCTAssertEqual(viewModel.lynkDoorLock.expectedState, .unlocked)
    }

    func testToggleDoorLock_whenUnlocked_callsLock() {
        viewModel.reload(entityID: .lynkDoorLock, state: "unlocked")
        viewModel.toggleDoorLock()
        XCTAssertEqual(viewModel.lynkDoorLock.expectedState, .locked)
    }

    func testStartLynkClimate_setsInitiatedTimeAndHidesOptions() {
        viewModel.isShowingHeaterOptions = true
        viewModel.startLynkClimate()
        XCTAssertNotNil(viewModel.lynkAirConditionInitiatedTime)
        XCTAssertFalse(viewModel.isShowingHeaterOptions)
    }

    func testStopLynkClimate_clearsInitiatedTime() {
        viewModel.startLynkClimate()
        viewModel.stopLynkClimate()
        XCTAssertNil(viewModel.lynkAirConditionInitiatedTime)
    }

    func testToggleLynkClimate_whenActive_callsStop() {
        viewModel.reload(entityID: .lynkClimateHeating, state: "on")
        viewModel.toggleLynkClimate()
        XCTAssertNil(viewModel.lynkAirConditionInitiatedTime)
    }

    func testToggleLynkClimate_whenInactive_callsStart() {
        viewModel.reload(entityID: .lynkClimateHeating, state: "off")
        viewModel.lynkAirConditionInitiatedTime = nil
        viewModel.toggleLynkClimate()
        XCTAssertNotNil(viewModel.lynkAirConditionInitiatedTime)
    }

    func testStartEngine_setsEngineInitiatedTimeAndHidesOptions() {
        viewModel.isShowingHeaterOptions = true
        viewModel.startEngine()
        XCTAssertNotNil(viewModel.engineInitiatedTime)
        XCTAssertFalse(viewModel.isShowingHeaterOptions)
    }

    func testStopEngine_clearsEngineInitiatedTime() {
        viewModel.startEngine()
        viewModel.stopEngine()
        XCTAssertNil(viewModel.engineInitiatedTime)
    }

    func testStartFlashLights_setsIsLynkFlashingTrue() {
        viewModel.startFlashLights()
        XCTAssertTrue(viewModel.isLynkFlashing)
    }

    func testStopFlashLights_setsIsLynkFlashingFalse() {
        viewModel.startFlashLights()
        viewModel.stopFlashLights()
        XCTAssertFalse(viewModel.isLynkFlashing)
    }

    // MARK: - Network Reload

    func testReloadFetchesAllEntitiesFromNetwork() async {
        for entityID in viewModel.entityIDs {
            stubEntityURL(entityID: entityID, state: "test_\(entityID.rawValue)")
        }
        await viewModel.reload()
        XCTAssertEqual(viewModel.lynkClimateHeating.state, "test_\(EntityId.lynkClimateHeating.rawValue)")
        XCTAssertEqual(viewModel.isEngineRunning.state, "test_\(EntityId.lynkEngineRunning.rawValue)")
        XCTAssertEqual(viewModel.lynkInteriorTemperature.state, "test_\(EntityId.lynkTemperatureInterior.rawValue)")
        XCTAssertEqual(viewModel.lynkBattery.state, "test_\(EntityId.lynkBattery.rawValue)")
        XCTAssertEqual(viewModel.leafBattery.state, "test_\(EntityId.leafBattery.rawValue)")
        XCTAssertEqual(viewModel.leafLastPoll.state, "test_\(EntityId.leafLastPoll.rawValue)")
    }

    func testReloadSilentlyHandlesNetworkFailure() async {
        // No stubs — all requests fail; entities stay at "Loading"
        await viewModel.reload()
        XCTAssertEqual(viewModel.lynkClimateHeating.state, "Loading")
        XCTAssertEqual(viewModel.fuel.state, "Loading")
    }

    // MARK: - Concurrent Reload Guard

    func testReloadGuard_preventsConcurrentReload() async {
        // Stub with small delay so first reload() is in-flight when second starts
        for entityID in viewModel.entityIDs {
            stubEntityURL(entityID: entityID, state: "on", delay: 0.05)
        }

        let lock = NSLock()
        var requestCount = 0
        URLProtocolStub.observerRequests { request in
            guard request.httpMethod == "GET" else { return }
            lock.lock()
            requestCount += 1
            lock.unlock()
        }

        async let first: () = viewModel.reload()
        async let second: () = viewModel.reload()
        _ = await (first, second)

        // Guard allows only one pass through reloadEntities() = 26 GETs
        XCTAssertEqual(requestCount, viewModel.entityIDs.count,
                       "Expected \(viewModel.entityIDs.count) GETs (1 pass); got \(requestCount)")
    }
}

// MARK: - Helpers

private func stubEntityURL(entityID: EntityId, state: String, delay: TimeInterval = 0) {
    var components = URLComponents(string: GlobalConstants.baseInternalUrlString)!
    components.path = "/api/states/\(entityID.rawValue)"
    let url = components.url!
    let data = makeEntityJSON(entityId: entityID.rawValue, state: state)
    let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
    URLProtocolStub.setStub(for: url, data: data, response: response, error: nil, delay: delay)
}
