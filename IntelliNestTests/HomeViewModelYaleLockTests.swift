@testable import IntelliNest
import XCTest

/// Covers the two behaviours the Yale doors gained: a write that falls back to Home Assistant when the
/// direct cloud call fails, and a read that only chases state while we are expecting it to change.
@MainActor
class HomeViewModelYaleLockTests: XCTestCase {
    var viewModel: HomeViewModel!
    var restAPIService: RestAPIService!
    var yaleAPIService: YaleApiService!
    var urlCreator: URLCreator!
    var requestedURLs: [URL]!
    var bannerTitles: [String] = []

    override func setUp() async throws {
        URLProtocolStub.startInterceptingRequests()
        let stubbedSession = URLProtocolStub.createStubbedURLSession()
        urlCreator = URLCreator(session: stubbedSession)
        urlCreator.connectionState = .local
        restAPIService = RestAPIService(
            urlCreator: urlCreator,
            session: stubbedSession,
            setErrorBannerText: { [weak self] title, _ in self?.bannerTitles.append(title) },
            repeatReloadAction: { _ in }
        )
        yaleAPIService = YaleApiService(hassAPIService: restAPIService, session: stubbedSession)
        viewModel = HomeViewModel(
            restAPIService: restAPIService,
            yaleApiService: yaleAPIService,
            urlCreator: urlCreator,
            showHeatersAction: {},
            showLynkAction: {},
            showPowerGridAction: {},
            showLightsAction: {},
            showMusicAction: {},
            toolbarReloadAction: {}
        )

        requestedURLs = []
        URLProtocolStub.observerRequests { [self] request in
            if let url = request.url {
                requestedURLs.append(url)
            }
        }
    }

    override func tearDown() async throws {
        URLProtocolStub.stopInterceptingRequests()
        viewModel = nil
        restAPIService = nil
        yaleAPIService = nil
        urlCreator = nil
        requestedURLs = nil
        bannerTitles = []
    }

    private func yaleOperateURL(lockID: LockID, action: Action) -> URL {
        var components = URLComponents(string: GlobalConstants.secretYaleAPIURL)!
        components.path = "/remoteoperate/\(lockID.rawValue)/\(action.rawValue)"
        return components.url!
    }

    private func stubYaleOperate(lockID: LockID, action: Action, statusCode: Int) {
        let url = yaleOperateURL(lockID: lockID, action: action)
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)
        URLProtocolStub.setStub(for: url, data: Data(), response: response, error: nil)
    }

    private var homeAssistantServiceCallCount: Int {
        requestedURLs.filter { $0.path.contains("/api/services/lock/") }.count
    }

    private func stubHomeAssistantLockService(action: Action) {
        var components = URLComponents(string: GlobalConstants.baseInternalUrlString)!
        components.path = "/api/services/\(Domain.lock.rawValue)/\(action.rawValue)"
        let url = components.url!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        URLProtocolStub.setStub(for: url, data: Data(), response: response, error: nil)
    }

    private func stubYaleLockRead(lockID: LockID, status: String) {
        var components = URLComponents(string: GlobalConstants.secretYaleAPIURL)!
        components.path = "/locks/\(lockID.rawValue)"
        let lockURL = components.url!
        let body = Data("""
        {
            "LockStatus": {
                "status": "\(status)",
                "dateTime": "2026-09-03T08:24:38.000Z",
                "isLockStatusChanged": true,
                "valid": true,
                "doorState": "closed"
            }
        }
        """.utf8)
        let response = HTTPURLResponse(url: lockURL, statusCode: 200, httpVersion: nil, headerFields: nil)
        URLProtocolStub.setStub(for: lockURL, data: body, response: response, error: nil)
    }

    private struct WriteCase {
        let lockID: LockID
        let action: Action
        let statusCode: Int
    }

    func testSuccessfulYaleWriteDoesNotCallHomeAssistant() async {
        let cases = [
            WriteCase(lockID: .frontDoor, action: .unlock, statusCode: 200),
            WriteCase(lockID: .sideDoor, action: .unlock, statusCode: 202),
            WriteCase(lockID: .frontDoor, action: .lock, statusCode: 200),
            WriteCase(lockID: .sideDoor, action: .lock, statusCode: 202)
        ]

        for testCase in cases {
            requestedURLs = []
            stubYaleOperate(lockID: testCase.lockID, action: testCase.action, statusCode: testCase.statusCode)

            let success = await viewModel.setLockState(lockID: testCase.lockID, action: testCase.action)

            XCTAssertTrue(success, "Expected \(testCase.statusCode) to count as a successful Yale write")
            XCTAssertEqual(homeAssistantServiceCallCount, 0,
                           "A successful Yale write must not also go through Home Assistant")
        }
    }

    func testFailedYaleWriteFallsBackToHomeAssistant() async {
        let cases: [(lockID: LockID, action: Action)] = [
            (.frontDoor, .unlock),
            (.sideDoor, .unlock),
            (.frontDoor, .lock),
            (.sideDoor, .lock)
        ]

        for testCase in cases {
            requestedURLs = []
            stubYaleOperate(lockID: testCase.lockID, action: testCase.action, statusCode: 500)
            stubHomeAssistantLockService(action: testCase.action)

            let success = await viewModel.setLockState(lockID: testCase.lockID, action: testCase.action)

            XCTAssertTrue(success, "The Home Assistant fallback should still report the write as handled")
            XCTAssertEqual(homeAssistantServiceCallCount, 1,
                           "A failed Yale write must fall back to exactly one Home Assistant call")
        }
    }

    func testLocksWithoutAHomeAssistantCounterpartDoNotFallBack() async {
        for lockID in [LockID.storageDoor, LockID.lynkDoor] {
            requestedURLs = []
            stubYaleOperate(lockID: lockID, action: .unlock, statusCode: 500)

            let success = await viewModel.setLockState(lockID: lockID, action: .unlock)

            XCTAssertFalse(success, "\(lockID) has no Home Assistant lock entity to fall back to")
            XCTAssertEqual(homeAssistantServiceCallCount, 0)
        }
    }

    func testConfirmPollStopsOnceTheLockReportsTheExpectedState() async {
        stubYaleLockRead(lockID: .frontDoor, status: "unlocked")

        viewModel.frontDoor.lockState = .locked
        viewModel.frontDoor.expectedState = .unlocked

        await viewModel.reloadLockUntilExpectedState(lockID: .frontDoor, attempts: 5, pollInterval: 0)

        XCTAssertEqual(viewModel.frontDoor.lockState, .unlocked)
        let lockReads = requestedURLs.filter { $0.path.contains("/locks/") }.count
        XCTAssertEqual(lockReads, 1, "The poll must stop on the first read that matches the expected state")
    }

    func testConfirmPollGivesUpAfterTheAttemptLimit() async {
        stubYaleLockRead(lockID: .sideDoor, status: "locked")

        viewModel.sideDoor.lockState = .locked
        viewModel.sideDoor.expectedState = .unlocked

        await viewModel.reloadLockUntilExpectedState(lockID: .sideDoor, attempts: 3, pollInterval: 0)

        let lockReads = requestedURLs.filter { $0.path.contains("/locks/") }.count
        XCTAssertEqual(lockReads, 3, "A lock that never reaches the expected state must stop at the limit")
    }

    private struct UnknownTapCase {
        let lockID: LockID
        let readStatus: String
        let expectedState: LockState
        let expectsBanner: Bool
    }

    /// A tap on an unknown lock must only read it: the user had no state to decide on, so moving the bolt
    /// on the fresh read could unlock a door they never saw as locked.
    func testTapOnUnknownLockReloadsWithoutOperating() async {
        let cases = [
            UnknownTapCase(lockID: .frontDoor, readStatus: "locked", expectedState: .locked, expectsBanner: false),
            UnknownTapCase(lockID: .sideDoor, readStatus: "unlocked", expectedState: .unlocked, expectsBanner: false),
            UnknownTapCase(lockID: .frontDoor, readStatus: "garbled", expectedState: .unknown, expectsBanner: true)
        ]

        for testCase in cases {
            requestedURLs = []
            bannerTitles = []
            stubYaleLockRead(lockID: testCase.lockID, status: testCase.readStatus)
            let keyPath: ReferenceWritableKeyPath<HomeViewModel, YaleLock> = testCase.lockID == .frontDoor
                ? \.frontDoor
                : \.sideDoor
            viewModel[keyPath: keyPath].lockState = .unknown

            if testCase.lockID == .frontDoor {
                viewModel.toggleStateForFrontDoor()
            } else {
                viewModel.toggleStateForSideDoor()
            }
            await viewModel.pendingLockRefreshTask?.value

            XCTAssertEqual(viewModel[keyPath: keyPath].lockState, testCase.expectedState)
            XCTAssertEqual(viewModel[keyPath: keyPath].expectedState, .unknown,
                           "A refresh tap must not set an expected state, nothing was asked of the lock")
            let operateCalls = requestedURLs.filter { $0.path.contains("/remoteoperate/") }.count
            XCTAssertEqual(operateCalls, 0, "A tap on an unknown lock must never lock or unlock it")
            XCTAssertEqual(homeAssistantServiceCallCount, 0)
            let lockReads = requestedURLs.filter { $0.path == "/locks/\(testCase.lockID.rawValue)" }.count
            XCTAssertEqual(lockReads, 1, "The tap must actually read the lock before deciding what to show")
            XCTAssertEqual(bannerTitles.isEmpty, !testCase.expectsBanner,
                           "Only a lock that is still unreadable after the reload should show a banner")
        }
    }

    func testUnreadableLockStaysTappableUntilARead() {
        var lock = YaleLock(id: .frontDoor)
        XCTAssertFalse(lock.isLoading, "An unknown lock with nothing in flight must not disable its button")
        XCTAssertEqual(lock.actionText, "Uppdatera", "The button must not promise to unlock a door it will only read")

        lock.isReading = true
        XCTAssertTrue(lock.isLoading)
    }

    func testReadThatStartedBeforeAToggleIsDropped() async {
        var components = URLComponents(string: GlobalConstants.secretYaleAPIURL)!
        components.path = "/locks/\(LockID.sideDoor.rawValue)"
        let sideDoorURL = components.url!
        let gate = StubGate()
        let body = Data(#"{"LockStatus": {"status": "locked", "dateTime": "2026-09-03T08:24:38.000Z", "#.utf8)
            + Data(#""isLockStatusChanged": true, "valid": true, "doorState": "closed"}}"#.utf8)
        let response = HTTPURLResponse(url: sideDoorURL, statusCode: 200, httpVersion: nil, headerFields: nil)
        URLProtocolStub.setStub(for: sideDoorURL, data: body, response: response, error: nil, gate: gate)
        stubYaleLockRead(lockID: .frontDoor, status: "locked")

        let reloadTask = Task { await viewModel.reloadYaleLocks() }
        await gate.waitForRequests(count: 1)
        XCTAssertTrue(viewModel.sideDoor.isLoading, "A read in flight should show the door as busy")

        viewModel.discardPendingLockReads(at: \.sideDoor)
        viewModel.sideDoor.lockState = .unlocked
        gate.open()
        await reloadTask.value

        XCTAssertEqual(viewModel.sideDoor.lockState, .unlocked,
                       "A read from before the toggle must not overwrite the state the toggle confirmed")
        XCTAssertFalse(viewModel.sideDoor.isReading)
        XCTAssertEqual(viewModel.frontDoor.lockState, .locked)
    }
}

// MARK: - Storage lock refresh

@MainActor
extension HomeViewModelYaleLockTests {
    func testRefreshStorageLockAsksHomeAssistantToPollThenReadsTheFreshState() async throws {
        let internalRefresh = "192.168.1.205/api/services/homeassistant/update_entity"
        let externalRefresh = "192.218.223.123/api/services/homeassistant/update_entity"
        let stateRead = "192.168.1.205/api/states/lock.storage"
        let cases = [
            RefreshCase(name: "internal refresh succeeds", internalStatus: 200, externalStatus: nil,
                        expected: [internalRefresh, stateRead]),
            RefreshCase(name: "internal rejected, external succeeds", internalStatus: 500, externalStatus: 200,
                        expected: [internalRefresh, externalRefresh, stateRead]),
            RefreshCase(name: "internal unreachable, external succeeds", internalStatus: nil, externalStatus: 200,
                        expected: [internalRefresh, externalRefresh, stateRead]),
            RefreshCase(name: "both unreachable", internalStatus: nil, externalStatus: nil,
                        expected: [internalRefresh, externalRefresh, stateRead])
        ]
        var clock = Date(timeIntervalSince1970: 1_800_000_000)
        viewModel.now = { clock }
        for testCase in cases {
            clock.addTimeInterval(HomeViewModel.storageLockRefreshInterval + 1)
            URLProtocolStub.stopInterceptingRequests()
            URLProtocolStub.startInterceptingRequests()
            let recorder = RequestRecorder { request in
                request.url?.path.contains("update_entity") == true || request.url?.path == "/api/states/lock.storage"
            }
            if let statusCode = testCase.internalStatus {
                stubUpdateEntityService(baseURL: GlobalConstants.baseInternalUrlString, statusCode: statusCode)
            }
            if let statusCode = testCase.externalStatus {
                stubUpdateEntityService(baseURL: GlobalConstants.baseExternalUrlString, statusCode: statusCode)
            }
            stubEntityURL(entityID: .storageLock, state: "unlocked")
            viewModel.reload(entityID: .storageLock, state: "locked")
            bannerTitles = []

            await viewModel.refreshStorageLock()

            let requested = recorder.requests.compactMap { request in request.url.map { "\($0.host ?? "")\($0.path)" } }
            XCTAssertEqual(requested, testCase.expected, testCase.name)
            let refresh = try XCTUnwrap(recorder.requests.first, testCase.name)
            let body = try XCTUnwrap(refresh.httpBodyStreamData() ?? refresh.httpBody, testCase.name)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any], testCase.name)
            XCTAssertEqual(json["entity_id"] as? String, "lock.storage", testCase.name)
            XCTAssertEqual(viewModel.storageLock.lockState, .unlocked, testCase.name)
            // A background refresh that fails must not interrupt the user with a banner.
            XCTAssertEqual(bannerTitles, [], testCase.name)
        }
    }

    func testRefreshStorageLockReusesARecentOrRunningRefresh() async {
        var clock = Date(timeIntervalSince1970: 1_800_000_000)
        viewModel.now = { clock }
        let recorder = RequestRecorder { $0.url?.path.contains("update_entity") == true }
        stubUpdateEntityService(baseURL: GlobalConstants.baseInternalUrlString, statusCode: 200)
        stubEntityURL(entityID: .storageLock, state: "locked")

        // Launch: the foreground hook and the home screen's appear overlap.
        async let first: Void = viewModel.refreshStorageLock()
        async let second: Void = viewModel.refreshStorageLock()
        _ = await (first, second)
        XCTAssertEqual(recorder.requests.count, 1)

        clock.addTimeInterval(HomeViewModel.storageLockRefreshInterval - 1)
        await viewModel.refreshStorageLock()
        XCTAssertEqual(recorder.requests.count, 1)

        clock.addTimeInterval(2)
        await viewModel.refreshStorageLock()
        XCTAssertEqual(recorder.requests.count, 2)
    }

    /// `nil` status leaves that URL unstubbed, so the request fails as if the host were unreachable.
    private struct RefreshCase {
        let name: String
        let internalStatus: Int?
        let externalStatus: Int?
        let expected: [String]
    }

    private func stubUpdateEntityService(baseURL: String, statusCode: Int) {
        var components = URLComponents(string: baseURL)!
        components.path = "/api/services/homeassistant/update_entity"
        let url = components.url!
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        URLProtocolStub.setStub(for: url, data: Data(), response: response, error: nil)
    }
}
