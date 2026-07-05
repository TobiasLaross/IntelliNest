@testable import IntelliNest
import XCTest

@MainActor
class HeatersViewModelTests: XCTestCase {
    var viewModel: HeatersViewModel!
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
        viewModel = HeatersViewModel(restAPIService: restAPIService, showHeaterDetails: { _ in })
    }

    override func tearDown() async throws {
        URLProtocolStub.stopInterceptingRequests()
        viewModel = nil
        restAPIService = nil
        urlCreator = nil
    }

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertEqual(viewModel.heaterCorridor.state, "Loading")
        XCTAssertEqual(viewModel.heaterPlayroom.state, "Loading")
        XCTAssertEqual(viewModel.heaterCorridorTimerMode.state, "Loading")
        XCTAssertEqual(viewModel.heaterPlayroomTimerMode.state, "Loading")
        XCTAssertEqual(viewModel.resetCorridorHeaterTime.state, "Loading")
        XCTAssertEqual(viewModel.resetPlayroomHeaterTime.state, "Loading")
        XCTAssertEqual(viewModel.purifierTimerMode.state, "Loading")
        XCTAssertEqual(viewModel.purifier.fanMode, .off)
        XCTAssertEqual(viewModel.purifier.speed, 0)
        XCTAssertEqual(viewModel.purifier.temperature, 0)
        XCTAssertEqual(viewModel.purifier.humidity, 0)
        XCTAssertEqual(viewModel.purifier500TimerMode.state, "Loading")
        XCTAssertEqual(viewModel.purifier500.speed, 0)
        XCTAssertEqual(viewModel.purifier500.pm25, 0)
    }

    // MARK: - reload(entityID:state:)

    func testReloadUpdatesResetCorridorHeaterTime() {
        viewModel.reload(entityID: .resetCorridorHeaterTime, state: "2023-06-17T15:30:00")
        XCTAssertEqual(viewModel.resetCorridorHeaterTime.state, "2023-06-17T15:30:00")
    }

    func testReloadUpdatesResetPlayroomHeaterTime() {
        viewModel.reload(entityID: .resetPlayroomHeaterTime, state: "2023-06-17T16:00:00")
        XCTAssertEqual(viewModel.resetPlayroomHeaterTime.state, "2023-06-17T16:00:00")
    }

    func testReloadUpdatesHeaterCorridorTimerMode() {
        viewModel.reload(entityID: .heaterCorridorTimerMode, state: "on")
        XCTAssertEqual(viewModel.heaterCorridorTimerMode.state, "on")
        XCTAssertTrue(viewModel.heaterCorridorTimerMode.isActive)
    }

    func testReloadUpdatesHeaterPlayroomTimerMode() {
        viewModel.reload(entityID: .heaterPlayroomTimerMode, state: "off")
        XCTAssertEqual(viewModel.heaterPlayroomTimerMode.state, "off")
        XCTAssertFalse(viewModel.heaterPlayroomTimerMode.isActive)
    }

    func testReloadUpdatesPurifierMode() {
        viewModel.reload(entityID: .purifierMode, state: "auto")
        XCTAssertEqual(viewModel.purifier.fanMode, .auto)
    }

    func testReloadUpdatesPurifierModeOff() {
        viewModel.reload(entityID: .purifierMode, state: "off")
        XCTAssertEqual(viewModel.purifier.fanMode, .off)
    }

    func testReloadUpdatesPurifierModeUnknownFallsBackToOff() {
        viewModel.reload(entityID: .purifierMode, state: "turbo_unknown")
        XCTAssertEqual(viewModel.purifier.fanMode, .off)
    }

    func testReloadUpdatesPurifierFanSpeedKnownValue() {
        // 11 % → PurifierFanScale.pure → level 1
        viewModel.reload(entityID: .purifierFanSpeed, state: "11")
        XCTAssertEqual(viewModel.purifier.speed, 1.0)
    }

    func testReloadUpdatesPurifierFanSpeedRoundsToNearestLevel() {
        // 50 % → level 5 (round(50 · 9 / 100)); the old lossy mapping wrongly returned 0 here.
        viewModel.reload(entityID: .purifierFanSpeed, state: "50")
        XCTAssertEqual(viewModel.purifier.speed, 5.0)
    }

    func testReloadUpdatesPurifierFanSpeedInvalidStringZero() {
        viewModel.reload(entityID: .purifierFanSpeed, state: "not-a-number")
        XCTAssertEqual(viewModel.purifier.speed, 0.0)
    }

    func testReloadUpdatesPurifier500FanSpeed() {
        // 40 % → PurifierFanScale.pure500 → level 2
        viewModel.reload(entityID: .purifier500FanSpeed, state: "40")
        XCTAssertEqual(viewModel.purifier500.speed, 2.0)
    }

    func testReloadUpdatesPurifier500FanSpeedClampsAboveMax() {
        // 100 % would map to level 5, but Pure 500 has only 3 levels, so it clamps to 3.
        viewModel.reload(entityID: .purifier500FanSpeed, state: "100")
        XCTAssertEqual(viewModel.purifier500.speed, 3.0)
    }

    func testReloadUpdatesPurifier500PM25() {
        viewModel.reload(entityID: .purifier500PM25, state: "7")
        XCTAssertEqual(viewModel.purifier500.pm25, 7)
    }

    func testReloadUpdatesPurifier500TimerMode() {
        viewModel.reload(entityID: .purifier500TimerMode, state: "on")
        XCTAssertEqual(viewModel.purifier500TimerMode.state, "on")
        XCTAssertTrue(viewModel.purifier500TimerMode.isActive)
    }

    func testReloadUpdatesResetPurifier500Time() {
        viewModel.reload(entityID: .resetPurifier500Time, state: "2023-06-17T12:00:00")
        XCTAssertEqual(viewModel.resetPurifier500Time.state, "2023-06-17T12:00:00")
    }

    func testReloadUpdatesPurifierTemperature() {
        viewModel.reload(entityID: .purifierTemperature, state: "21.5")
        XCTAssertEqual(viewModel.purifier.temperature, 21.5)
    }

    func testReloadUpdatesPurifierTemperatureInvalidStringZero() {
        viewModel.reload(entityID: .purifierTemperature, state: "unavailable")
        XCTAssertEqual(viewModel.purifier.temperature, 0.0)
    }

    func testReloadUpdatesPurifierHumidity() {
        viewModel.reload(entityID: .purifierHumidity, state: "45")
        XCTAssertEqual(viewModel.purifier.humidity, 45)
    }

    func testReloadUpdatesPurifierHumidityInvalidStringZero() {
        viewModel.reload(entityID: .purifierHumidity, state: "abc")
        XCTAssertEqual(viewModel.purifier.humidity, 0)
    }

    func testReloadUpdatesResetPurifierTime() {
        viewModel.reload(entityID: .resetPurifierTime, state: "2023-06-17T12:00:00")
        XCTAssertEqual(viewModel.resetPurifierTime.state, "2023-06-17T12:00:00")
    }

    func testReloadUpdatesPurifierTimerMode() {
        viewModel.reload(entityID: .purifierTimerMode, state: "on")
        XCTAssertEqual(viewModel.purifierTimerMode.state, "on")
        XCTAssertTrue(viewModel.purifierTimerMode.isActive)
    }

    // MARK: - toggleCorridorTimerMode

    func testToggleCorridorTimerMode_turnOnWhenInactive() {
        // heaterCorridorTimerMode starts as "Loading" (inactive)
        viewModel.reload(entityID: .heaterCorridorTimerMode, state: "off")
        // After toggle, the timer mode should transition to turnOn
        // (We can't easily observe the API call, but we can verify the state isn't mutated directly)
        // The call goes through to the API service — state remains "off" in the VM since it waits for reload
        viewModel.toggleCorridorTimerMode()
        XCTAssertEqual(viewModel.heaterCorridorTimerMode.state, "off") // unchanged until API responds
    }

    // MARK: - updateHeater(from:)

    func testUpdateHeaterUpdatesCorridorHeater() {
        var updatedHeater = HeaterEntity(entityId: .heaterCorridor, state: "cool")
        updatedHeater.targetTemperature = 24.0
        viewModel.updateHeater(from: updatedHeater)

        XCTAssertEqual(viewModel.heaterCorridor.state, "cool")
        XCTAssertEqual(viewModel.heaterCorridor.targetTemperature, 24.0)
    }

    func testUpdateHeaterUpdatesPlayroomHeater() {
        let updatedHeater = HeaterEntity(entityId: .heaterPlayroom, state: "heat")
        viewModel.updateHeater(from: updatedHeater)

        XCTAssertEqual(viewModel.heaterPlayroom.state, "heat")
    }

    func testUpdateHeaterDoesNotAffectOtherHeater() {
        let corridorHeater = HeaterEntity(entityId: .heaterCorridor, state: "cool")
        let playroomOriginalState = viewModel.heaterPlayroom.state
        viewModel.updateHeater(from: corridorHeater)

        XCTAssertEqual(viewModel.heaterPlayroom.state, playroomOriginalState)
    }

    // MARK: - setFanMode guard (no-op when same mode)

    func testSetFanModeNoOp_whenSameMode() {
        // heaterCorridor defaults to .auto fan mode
        // Calling setFanMode with .auto should be a no-op (the guard prevents the API call)
        // We verify this doesn't crash and the state is unchanged
        viewModel.setFanMode(viewModel.heaterCorridor, .auto)
        XCTAssertEqual(viewModel.heaterCorridor.fanMode, .auto)
    }

    // MARK: - Network Reload (entityIDs loop only — therm async let bypassed in CI)

    func testReloadFetchesEntityIDEntitiesFromNetwork() async {
        // Stub all entityIDs except the two fan speeds (they need attributes JSON, stubbed below)
        for entityID in viewModel.entityIDs where entityID != .purifierFanSpeed && entityID != .purifier500FanSpeed {
            stubEntityURL(entityID: entityID, state: "on")
        }
        stubFanSpeed(.purifierFanSpeed, percentage: 100.0)
        stubFanSpeed(.purifier500FanSpeed, percentage: 40.0)

        await viewModel.reload()

        XCTAssertEqual(viewModel.heaterCorridorTimerMode.state, "on")
        XCTAssertEqual(viewModel.heaterPlayroomTimerMode.state, "on")
        XCTAssertEqual(viewModel.purifierTimerMode.state, "on")
        XCTAssertEqual(viewModel.purifier500TimerMode.state, "on")
        XCTAssertEqual(viewModel.resetCorridorHeaterTime.state, "on")
        XCTAssertEqual(viewModel.resetPlayroomHeaterTime.state, "on")
        XCTAssertEqual(viewModel.purifier.speed, 9.0)
        XCTAssertEqual(viewModel.purifier500.speed, 2.0)
    }

    func testReloadFetchesPurifierSpeed() async {
        stubFanSpeed(.purifierFanSpeed, percentage: 100.0)
        stubFanSpeed(.purifier500FanSpeed, percentage: 60.0)

        await viewModel.reload()

        XCTAssertEqual(viewModel.purifier.speed, 9.0)
        XCTAssertEqual(viewModel.purifier500.speed, 3.0)
    }

    func testReloadSilentlyHandlesNetworkFailure() async {
        // No stubs — all requests fail; entities stay at initial state
        await viewModel.reload()
        XCTAssertEqual(viewModel.heaterCorridorTimerMode.state, "Loading")
        XCTAssertEqual(viewModel.purifierTimerMode.state, "Loading")
        XCTAssertEqual(viewModel.purifier.speed, 0.0)
    }

    // MARK: - Concurrent Reload Guard

    func testReloadGuard_preventsConcurrentReload() async {
        for entityID in viewModel.entityIDs where entityID != .purifierFanSpeed && entityID != .purifier500FanSpeed {
            stubEntityURL(entityID: entityID, state: "on", delay: 0.05)
        }
        stubFanSpeed(.purifierFanSpeed, percentage: 100.0)
        stubFanSpeed(.purifier500FanSpeed, percentage: 40.0)

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

        XCTAssertLessThanOrEqual(requestCount, viewModel.entityIDs.count,
                                 "Concurrent guard failed: \(requestCount) requests > \(viewModel.entityIDs.count)")
    }

    // MARK: - Helpers

    private func stubFanSpeed(_ entityID: EntityId, percentage: Double) {
        let data = makeEntityJSON(entityId: entityID.rawValue, state: "on", attributes: ["percentage": percentage])
        stubEntityURL(entityID: entityID, data: data)
    }
}
