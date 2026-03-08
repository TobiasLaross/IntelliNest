@testable import IntelliNest
import XCTest

@MainActor
class RestAPIServiceTests: XCTestCase {
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
    }

    override func tearDown() async throws {
        URLProtocolStub.stopInterceptingRequests()
        restAPIService = nil
        urlCreator = nil
    }

    // MARK: - Helpers

    private func stubInternalEntityURL(entityID: EntityId, state: String) {
        var components = URLComponents(string: GlobalConstants.baseInternalUrlString)!
        components.path = "/api/states/\(entityID.rawValue)"
        let url = components.url!
        let data = makeEntityJSON(entityId: entityID.rawValue, state: state)
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        URLProtocolStub.setStub(for: url, data: data, response: response, error: nil)
    }

    private func stubExternalEntityURL(entityID: EntityId, state: String) {
        var components = URLComponents(string: GlobalConstants.baseExternalUrlString)!
        components.path = "/api/states/\(entityID.rawValue)"
        let url = components.url!
        let data = makeEntityJSON(entityId: entityID.rawValue, state: state)
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        URLProtocolStub.setStub(for: url, data: data, response: response, error: nil)
    }

    // MARK: - get<T>() tests

    func testGetSucceedsWithLocalURL() async throws {
        stubInternalEntityURL(entityID: .pulsePower, state: "1500")

        let entity: Entity = try await restAPIService.get(entityId: .pulsePower, entityType: Entity.self)

        XCTAssertEqual(entity.state, "1500")
    }

    func testGetFallsBackToExternalURLWhenLocalFails() async throws {
        // Local URL has no stub — URLProtocolStub returns notConnectedToInternet by default
        stubExternalEntityURL(entityID: .coffeeMachine, state: "on")

        let entity: Entity = try await restAPIService.get(entityId: .coffeeMachine, entityType: Entity.self)

        XCTAssertEqual(entity.state, "on")
    }

    func testGetThrowsWhenBothURLsFail() async {
        // No stubs registered — both internal and external return notConnectedToInternet
        do {
            let _: Entity = try await restAPIService.get(entityId: .coffeeMachine, entityType: Entity.self)
            XCTFail("Expected get() to throw when both URLs fail")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    // MARK: - reloadState() tests

    func testReloadStateSucceedsWithLocalURL() async throws {
        stubInternalEntityURL(entityID: .washerState, state: "run")

        let entity = try await restAPIService.reloadState(entityID: .washerState)

        XCTAssertEqual(entity.state, "run")
    }

    func testReloadStateFallsBackToExternalURLWhenLocalFails() async throws {
        // Local URL has no stub — URLProtocolStub returns notConnectedToInternet by default
        stubExternalEntityURL(entityID: .coffeeMachine, state: "off")

        let entity = try await restAPIService.reloadState(entityID: .coffeeMachine)

        XCTAssertEqual(entity.state, "off")
    }

    func testReloadStateThrowsWhenBothURLsFail() async {
        // No stubs registered — both internal and external return notConnectedToInternet
        do {
            _ = try await restAPIService.reloadState(entityID: .coffeeMachine)
            XCTFail("Expected reloadState() to throw when both URLs fail")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    // MARK: - POST tests

    func testCallServiceInvokesCorrectURL() async {
        var components = URLComponents(string: GlobalConstants.baseInternalUrlString)!
        components.path = "/api/services/switch/turn_on"
        let url = components.url!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        URLProtocolStub.setStub(for: url, data: Data(), response: response, error: nil)

        var capturedPath: String?
        URLProtocolStub.observerRequests { request in
            if request.httpMethod == "POST" {
                capturedPath = request.url?.path
            }
        }

        await restAPIService.setState(for: .coffeeMachine, in: .switchDomain, using: .turnOn)

        XCTAssertTrue(capturedPath?.contains("/switch/turn_on") == true,
                      "Expected POST to /switch/turn_on, got \(capturedPath ?? "nil")")
    }

    func testSendPostRequest_fallsBackToExternalURL() async {
        // Internal URL has no stub — only external succeeds
        var components = URLComponents(string: GlobalConstants.baseExternalUrlString)!
        components.path = "/api/services/switch/turn_on"
        let url = components.url!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        URLProtocolStub.setStub(for: url, data: Data(), response: response, error: nil)

        var errorBannerCalled = false
        let localService = RestAPIService(
            urlCreator: urlCreator,
            session: URLProtocolStub.createStubbedURLSession(),
            setErrorBannerText: { _, _ in errorBannerCalled = true },
            repeatReloadAction: { _ in }
        )

        await localService.setState(for: .coffeeMachine, in: .switchDomain, using: .turnOn)

        XCTAssertFalse(errorBannerCalled, "Error banner should not be shown when external POST succeeds")
    }

    func testSendPostRequest_bothFailure_setsErrorBanner() async {
        // No stubs — both internal and external POST requests fail
        var errorBannerCallCount = 0
        let localService = RestAPIService(
            urlCreator: urlCreator,
            session: URLProtocolStub.createStubbedURLSession(),
            setErrorBannerText: { _, _ in errorBannerCallCount += 1 },
            repeatReloadAction: { _ in }
        )

        await localService.setState(for: .coffeeMachine, in: .switchDomain, using: .turnOn)

        XCTAssertGreaterThanOrEqual(errorBannerCallCount, 1, "Error banner should be shown when both POST URLs fail")
    }

    // MARK: - sendRequest tests

    func testSendRequest_nonHTTPResponse_returnsBadResponse() async {
        var components = URLComponents(string: GlobalConstants.baseInternalUrlString)!
        components.path = "/api/test/nonhttp"
        let url = components.url!
        // Return a plain URLResponse (not HTTPURLResponse) to trigger the bad-response path
        let nonHttpResponse = URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        URLProtocolStub.setStub(for: url, data: nil, response: nonHttpResponse, error: nil)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (statusCode, _) = await restAPIService.sendRequest(request)

        // statusCodeBadResponse == 2
        XCTAssertEqual(statusCode, 2)
    }

    func testSendRequest_HTTP500_propagatesStatusCode() async {
        var components = URLComponents(string: GlobalConstants.baseInternalUrlString)!
        components.path = "/api/test/500"
        let url = components.url!
        let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
        URLProtocolStub.setStub(for: url, data: nil, response: response, error: nil)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (statusCode, _) = await restAPIService.sendRequest(request)

        XCTAssertEqual(statusCode, 500)
    }
}
