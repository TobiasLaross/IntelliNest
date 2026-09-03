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
}
