@testable import IntelliNest
import XCTest

@MainActor
class RoborockViewModelTests: XCTestCase {
    var viewModel: RoborockViewModel!
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
        viewModel = RoborockViewModel(restAPIService: restAPIService)
    }

    override func tearDown() async throws {
        URLProtocolStub.stopInterceptingRequests()
        viewModel = nil
        restAPIService = nil
        urlCreator = nil
    }

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertEqual(viewModel.roborock.state, "Loading")
        XCTAssertEqual(viewModel.roborockBattery.state, "Loading")
        XCTAssertEqual(viewModel.roborockAutomation.state, "Loading")
        XCTAssertEqual(viewModel.roborockLastCleanArea.state, "Loading")
        XCTAssertEqual(viewModel.roborockAreaWhenEmptied.state, "Loading")
        XCTAssertEqual(viewModel.roborockTotalCleaningArea.state, "Loading")
        XCTAssertEqual(viewModel.roborockEmptiedAtDate.state, "Loading")
        // roborockWaterShortage starts "off", not "Loading"
        XCTAssertEqual(viewModel.roborockWaterShortage.state, "off")
        XCTAssertFalse(viewModel.isShowingMapView)
        XCTAssertFalse(viewModel.isShowingrooms)
    }

    // MARK: - reload(entityID:state:) dispatch

    func testReloadUpdatesRoborockAutomation() {
        viewModel.reload(entityID: .roborockAutomation, state: "on")
        XCTAssertEqual(viewModel.roborockAutomation.state, "on")
        XCTAssertTrue(viewModel.roborockAutomation.isActive)
    }

    func testReloadUpdatesRoborockBattery() {
        viewModel.reload(entityID: .roborockBattery, state: "87")
        XCTAssertEqual(viewModel.roborockBattery.state, "87")
    }

    func testReloadUpdatesRoborockLastCleanArea() {
        viewModel.reload(entityID: .roborockLastCleanArea, state: "45.5")
        XCTAssertEqual(viewModel.roborockLastCleanArea.state, "45.5")
    }

    func testReloadUpdatesRoborockAreaWhenEmptied() {
        viewModel.reload(entityID: .roborockAreaWhenEmptied, state: "1000")
        XCTAssertEqual(viewModel.roborockAreaWhenEmptied.state, "1000")
    }

    func testReloadUpdatesRoborockTotalCleaningArea() {
        viewModel.reload(entityID: .roborockTotalCleaningArea, state: "1500")
        XCTAssertEqual(viewModel.roborockTotalCleaningArea.state, "1500")
    }

    func testReloadUpdatesRoborockEmptiedAtDate() {
        viewModel.reload(entityID: .roborockEmptiedAtDate, state: "2024-01-15")
        XCTAssertEqual(viewModel.roborockEmptiedAtDate.state, "2024-01-15")
    }

    func testReloadUpdatesRoborockWaterShortage() {
        viewModel.reload(entityID: .roborockWaterShortage, state: "on")
        XCTAssertEqual(viewModel.roborockWaterShortage.state, "on")
    }

    func testReloadUpdatesRoborockMapImage() {
        viewModel.reload(entityID: .roborockMapImage, state: "ok")
        XCTAssertEqual(viewModel.roborockMapImage.state, "ok")
    }

    func testReloadUnknownEntityIDDoesNotCrash() {
        // .coffeeMachine is not in RoborockViewModel's switch
        viewModel.reload(entityID: .coffeeMachine, state: "on")
        // No crash; no roborock state mutated
        XCTAssertEqual(viewModel.roborockBattery.state, "Loading")
    }

    // MARK: - Computed Properties

    func testCleaningAreaSinceEmptied_returnsCorrectDifference() {
        viewModel.reload(entityID: .roborockTotalCleaningArea, state: "1500")
        viewModel.reload(entityID: .roborockAreaWhenEmptied, state: "1000")
        XCTAssertEqual(viewModel.cleaningAreaSinceEmptied, 500.0)
    }

    func testCleaningAreaSinceEmptied_nonNumericState_returnsZero() {
        // Default "Loading" state for both — Double("Loading") == nil → 0
        XCTAssertEqual(viewModel.cleaningAreaSinceEmptied, 0.0)
    }

    func testCleaningAreaSinceEmptied_onlyTotalIsNumeric() {
        viewModel.reload(entityID: .roborockTotalCleaningArea, state: "800")
        // roborockAreaWhenEmptied stays "Loading" → 0
        XCTAssertEqual(viewModel.cleaningAreaSinceEmptied, 800.0)
    }

    // status branches require direct property injection — RoborockEntity does not decode
    // the `status` field from JSON attributes, so these cannot be tested via network stubs.

    func testStatus_whenStatusEqualsState() {
        viewModel.roborock.status = "cleaning"
        viewModel.roborock.state = "cleaning"
        XCTAssertEqual(viewModel.status, "Cleaning")
    }

    func testStatus_whenStatusContainsState() {
        viewModel.roborock.status = "segment cleaning"
        viewModel.roborock.state = "cleaning"
        XCTAssertEqual(viewModel.status, "Segment Cleaning")
    }

    func testStatus_whenStatusIsEmpty() {
        viewModel.roborock.status = ""
        viewModel.roborock.state = "docked"
        XCTAssertEqual(viewModel.status, "Docked")
    }

    func testStatus_whenStatusAndStateDiffer() {
        viewModel.roborock.status = "Mopping"
        viewModel.roborock.state = "Cleaning"
        XCTAssertEqual(viewModel.status, "Cleaning - Mopping")
    }

    // MARK: - Toggle Actions

    func testToggleCleaning_whenNotCleaning_sendsStartAction() async {
        // roborock.isCleaning == false by default (state "Loading")
        let expectation = XCTestExpectation(description: "POST vacuum start")
        URLProtocolStub.observerRequests { request in
            if request.httpMethod == "POST",
               let path = request.url?.path,
               path.contains("/vacuum/start") {
                expectation.fulfill()
            }
        }
        stubPostURL(path: "/api/services/vacuum/start")
        viewModel.toggleCleaning()
        await fulfillment(of: [expectation], timeout: 2.0)
    }

    func testToggleCleaning_whenCleaning_sendsStopAction() async {
        viewModel.roborock.status = "cleaning"
        viewModel.roborock.state = "cleaning"
        let expectation = XCTestExpectation(description: "POST vacuum stop")
        URLProtocolStub.observerRequests { request in
            if request.httpMethod == "POST",
               let path = request.url?.path,
               path.contains("/vacuum/stop") {
                expectation.fulfill()
            }
        }
        stubPostURL(path: "/api/services/vacuum/stop")
        viewModel.toggleCleaning()
        await fulfillment(of: [expectation], timeout: 2.0)
    }

    func testToggleRoborockAutomation_whenInactive_sendsExpectedAction() async {
        // isActive == false (state "Loading" → not "on")
        let expectation = XCTestExpectation(description: "POST automation action")
        URLProtocolStub.observerRequests { request in
            if request.httpMethod == "POST",
               let path = request.url?.path,
               path.contains("/automation/") {
                expectation.fulfill()
            }
        }
        stubPostURL(path: "/api/services/automation/turn_on")
        stubPostURL(path: "/api/services/automation/turn_off")
        viewModel.toggleRoborockAutomation()
        await fulfillment(of: [expectation], timeout: 2.0)
    }

    // MARK: - Network Reload

    func testReloadSilentlyHandlesNetworkFailure() async {
        // No stubs — all requests fail; entities stay at initial state
        await viewModel.reload()
        XCTAssertEqual(viewModel.roborockBattery.state, "Loading")
        XCTAssertEqual(viewModel.roborockAutomation.state, "Loading")
        // roborockWaterShortage stays at its custom initial value "off"
        XCTAssertEqual(viewModel.roborockWaterShortage.state, "off")
    }

    // MARK: - Concurrent Reload Guard

    func testReloadGuard_preventsConcurrentReload() async {
        for entityID in viewModel.entityIDs where entityID != .roborock && entityID != .roborockMapImage {
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

        // Second call must have returned early via the guard; request count
        // should be ≤ entityIDs.count (one pass), not double
        XCTAssertLessThanOrEqual(requestCount, viewModel.entityIDs.count,
                                 "Concurrent guard failed: \(requestCount) requests > \(viewModel.entityIDs.count)")
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

private func stubPostURL(path: String) {
    var components = URLComponents(string: GlobalConstants.baseInternalUrlString)!
    components.path = path
    let url = components.url!
    let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
    URLProtocolStub.setStub(for: url, data: Data(), response: response, error: nil)
}
