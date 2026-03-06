@testable import IntelliNest
import XCTest

@MainActor
class URLCreatorTests: XCTestCase {
    var urlCreator: URLCreator!

    override func setUp() async throws {
        URLProtocolStub.startInterceptingRequests()
        let stubbedSession = URLProtocolStub.createStubbedURLSession()
        urlCreator = URLCreator(session: stubbedSession)
    }

    override func tearDown() async throws {
        URLProtocolStub.stopInterceptingRequests()
        urlCreator = nil
    }

    // MARK: - Helpers

    private func stubAPIURL(baseURLString: String, statusCode: Int = 200, delay: TimeInterval = 0) {
        var components = URLComponents(string: baseURLString)!
        components.path = "/api"
        let url = components.url!
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        URLProtocolStub.setStub(for: url, data: Data(), response: response, error: nil, delay: delay)
    }

    // MARK: - Connection State Tests

    func testUpdateConnectionState_localURLSuccess_setsLocalState() async {
        stubAPIURL(baseURLString: GlobalConstants.baseInternalUrlString)

        await urlCreator.updateConnectionState(ignoreLocalSSID: true)

        XCTAssertEqual(urlCreator.connectionState, .local)
    }

    func testUpdateConnectionState_externalURLSuccess_whenLocalFails_setsInternetState() async {
        // Only external is stubbed; internal is unstubbed → fails immediately
        stubAPIURL(baseURLString: GlobalConstants.baseExternalUrlString)

        await urlCreator.updateConnectionState(ignoreLocalSSID: true)

        XCTAssertEqual(urlCreator.connectionState, .internet)
    }

    func testUpdateConnectionState_bothURLsFail_setsDisconnectedState() async {
        // No stubs → both URLs fail immediately with notConnectedToInternet

        await urlCreator.updateConnectionState(ignoreLocalSSID: true)

        XCTAssertEqual(urlCreator.connectionState, .disconnected)
    }

    func testUpdateConnectionState_localSucceedsFirst_doesNotWaitForSlowExternal() async {
        // Local URL responds immediately; external has a 10-second delay
        stubAPIURL(baseURLString: GlobalConstants.baseInternalUrlString, delay: 0)
        stubAPIURL(baseURLString: GlobalConstants.baseExternalUrlString, delay: 10)

        let start = Date()
        await urlCreator.updateConnectionState(ignoreLocalSSID: true)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertEqual(urlCreator.connectionState, .local)
        XCTAssertLessThan(elapsed, 3.0, "Should not wait for the slow external URL – got \(elapsed)s")
    }

    func testUpdateConnectionState_externalSucceedsFirst_doesNotWaitForSlowLocal() async {
        // Internal URL has a 10-second delay; external responds immediately
        stubAPIURL(baseURLString: GlobalConstants.baseInternalUrlString, delay: 10)
        stubAPIURL(baseURLString: GlobalConstants.baseExternalUrlString, delay: 0)

        let start = Date()
        await urlCreator.updateConnectionState(ignoreLocalSSID: true)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertEqual(urlCreator.connectionState, .internet)
        XCTAssertLessThan(elapsed, 3.0, "Should not wait for the slow internal URL – got \(elapsed)s")
    }
}
