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

    private func stubAPIURL(baseURLString: String, statusCode: Int = 200, gate: StubGate? = nil) {
        var components = URLComponents(string: baseURLString)!
        components.path = "/api"
        let url = components.url!
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        URLProtocolStub.setStub(for: url, data: Data(), response: response, error: nil, gate: gate)
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
        // The external URL is gated and never released, so it cannot answer at all.
        // Returning is therefore proof that the local result was enough — stronger
        // than the old "finished in under 3 seconds", and it can't be swayed by how
        // busy the machine is.
        let neverAnswers = StubGate()
        stubAPIURL(baseURLString: GlobalConstants.baseInternalUrlString)
        stubAPIURL(baseURLString: GlobalConstants.baseExternalUrlString, gate: neverAnswers)

        await urlCreator.updateConnectionState(ignoreLocalSSID: true)

        XCTAssertEqual(urlCreator.connectionState, .local)
    }

    func testUpdateConnectionState_externalSucceedsFirst_doesNotWaitForSlowLocal() async {
        let neverAnswers = StubGate()
        stubAPIURL(baseURLString: GlobalConstants.baseInternalUrlString, gate: neverAnswers)
        stubAPIURL(baseURLString: GlobalConstants.baseExternalUrlString)

        await urlCreator.updateConnectionState(ignoreLocalSSID: true)

        XCTAssertEqual(urlCreator.connectionState, .internet)
    }
}
