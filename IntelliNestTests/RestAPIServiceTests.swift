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
}
