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

    // MARK: - System log reporting

    private func stubInternalSystemLogURL() -> URL {
        var components = URLComponents(string: GlobalConstants.baseInternalUrlString)!
        components.path = "/api/services/system_log/create"
        let url = components.url!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        URLProtocolStub.setStub(for: url, data: Data(), response: response, error: nil)
        return url
    }

    func testReportToSystemLog_postsMessageLevelAndLoggerToSystemLogCreate() async {
        _ = stubInternalSystemLogURL()

        let requestObserved = expectation(description: "system_log.create POST observed")
        var capturedPath: String?
        var capturedBody: [String: Any]?
        URLProtocolStub.observerRequests { request in
            guard request.httpMethod == "POST" else { return }
            capturedPath = request.url?.path
            if let body = request.httpBodyStreamData() ?? request.httpBody,
               let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                capturedBody = json
            }
            requestObserved.fulfill()
        }

        restAPIService.reportToSystemLog(message: "Something broke", level: "error")

        await fulfillment(of: [requestObserved], timeout: 2)
        XCTAssertEqual(capturedPath, "/api/services/system_log/create")
        XCTAssertEqual(capturedBody?["message"] as? String, "Something broke")
        XCTAssertEqual(capturedBody?["level"] as? String, "error")
        XCTAssertEqual(capturedBody?["logger"] as? String, "intellinest")
    }

    func testReportToSystemLog_fallsBackToExternalURLWhenLocalFails() async {
        // Local URL has no stub — only external is reachable.
        var components = URLComponents(string: GlobalConstants.baseExternalUrlString)!
        components.path = "/api/services/system_log/create"
        let externalURL = components.url!
        let response = HTTPURLResponse(url: externalURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
        URLProtocolStub.setStub(for: externalURL, data: Data(), response: response, error: nil)

        let externalObserved = expectation(description: "external system_log.create POST observed")
        URLProtocolStub.observerRequests { request in
            if request.httpMethod == "POST",
               request.url?.absoluteString.contains(GlobalConstants.baseExternalUrlString) == true {
                externalObserved.fulfill()
            }
        }

        restAPIService.reportToSystemLog(message: "Fallback please", level: "warning")

        await fulfillment(of: [externalObserved], timeout: 2)
    }

    // MARK: - Log → Home Assistant forwarding

    /// Emitted from a single call site so repeated calls produce an identical formatted
    /// line, which is what the dedupe cache keys on.
    private func emitDuplicateError() {
        Log.error("Recurring failure")
    }

    func testLogError_isForwardedToReporter() async {
        Log.resetRemoteReporting()
        defer { Log.resetRemoteReporting() }

        let forwarded = expectation(description: "error forwarded")
        var capturedLevel: String?
        Log.remoteReporter = { level, _ in
            capturedLevel = level
            forwarded.fulfill()
        }

        Log.error("Boom")

        await fulfillment(of: [forwarded], timeout: 2)
        XCTAssertEqual(capturedLevel, "error")
    }

    func testLogInfo_isNotForwardedToReporter() async {
        Log.resetRemoteReporting()
        defer { Log.resetRemoteReporting() }

        var forwardCount = 0
        Log.remoteReporter = { _, _ in forwardCount += 1 }

        Log.info("Just info")
        // Let the @MainActor logging Task drain.
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(forwardCount, 0, "info-level logs must not be forwarded to Home Assistant")
    }

    func testLogError_duplicateWithinCooldownIsForwardedOnce() async {
        Log.resetRemoteReporting()
        defer { Log.resetRemoteReporting() }

        var forwardCount = 0
        Log.remoteReporter = { _, _ in forwardCount += 1 }

        emitDuplicateError()
        emitDuplicateError()
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(forwardCount, 1, "an identical log must only reach Home Assistant once per cooldown")
    }
}

private extension URLRequest {
    /// `URLProtocol` strips `httpBody` into a stream for POSTs, so read it back out.
    func httpBodyStreamData() -> Data? {
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data.isEmpty ? nil : data
    }
}
