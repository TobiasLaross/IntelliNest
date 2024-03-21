//
//  URLCreatorTests.swift
//  IntelliNestTests
//
//  Created by Tobias on 2023-05-06.
//

@testable import IntelliNest
import XCTest

class URLCreatorTestDelegate: URLCreatorDelegate {
    var expectation: XCTestExpectation?
    var expectedURL: String?
    var expectedState: ConnectionState?

    func baseURLChanged(urlString: String) {
        if urlString == expectedURL {
            expectation?.fulfill()
        }
    }

    func connectionStateChanged(state: ConnectionState) {
        if state == expectedState {
            expectation?.fulfill()
        }
    }
}

class URLCreatorTests: XCTestCase {
    private var stubbedSession: URLSession!
    private var urlCreator: URLCreator!
    private let apiPath = "api"

    override func setUp() {
        super.setUp()

        URLProtocolStub.startInterceptingRequests()
        stubbedSession = URLProtocolStub.createStubbedURLSession()
        urlCreator = URLCreator(session: stubbedSession)
        urlCreator.nextUpdate = Date().addingTimeInterval(-1)
    }

    override func tearDown() {
        URLProtocolStub.stopInterceptingRequests()
        urlCreator = nil
        stubbedSession = nil

        super.tearDown()
    }

    func test_updateConnectionState_whenInternalRequestSucceeds_shouldSetStateToLocal() async {
        // Set the stub data, response, and error for the internal URL
        let internalData = Data() // Empty data
        let internalResponse = HTTPURLResponse(url: URL(string: GlobalConstants.baseInternalUrlString)!,
                                               statusCode: 200,
                                               httpVersion: nil,
                                               headerFields: nil)!
        let internalUrl = URL(string: GlobalConstants.baseInternalUrlString + apiPath)!
        URLProtocolStub.setStub(for: internalUrl, data: internalData, response: internalResponse, error: nil)

        // Test the connection state
        await urlCreator.updateConnectionState()
        XCTAssertEqual(urlCreator.connectionState, .local)
    }

    func test_updateConnectionState_whenInternalRequestFailesAndExternalRequestSucceeds_shouldSetStateToInternet() async {
        // Set the stub data, response, and error for the internal URL
        let internalError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: nil)
        let internalUrl = URL(string: GlobalConstants.baseInternalUrlString + apiPath)!
        URLProtocolStub.setStub(for: internalUrl, data: nil, response: nil, error: internalError)

        // Set the stub data, response, and error for the external URL
        let externalData = Data() // Empty data
        let externalResponse = HTTPURLResponse(url: URL(string: GlobalConstants.baseExternalUrlString)!,
                                               statusCode: 200,
                                               httpVersion: nil,
                                               headerFields: nil)!
        let externalUrl = URL(string: GlobalConstants.baseExternalUrlString + apiPath)!
        URLProtocolStub.setStub(for: externalUrl, data: externalData, response: externalResponse, error: nil)

        let testDelegate = URLCreatorTestDelegate()
        urlCreator.delegate = testDelegate
        let expectation = XCTestExpectation(description: "Connection state updates to .internet")
        testDelegate.expectation = expectation
        testDelegate.expectedState = .internet

        await urlCreator.updateConnectionState()
        await fulfillment(of: [expectation], timeout: 0.2)
        XCTAssertEqual(urlCreator.connectionState, .internet)
    }

    func test_updateConnectionState_whenBothInternalAndExternalFailes_shouldSetStateToDisconnected() async {
        // Set the stub data, response, and error for the internal URL
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: nil)
        let internalUrl = URL(string: GlobalConstants.baseInternalUrlString + apiPath)!
        URLProtocolStub.setStub(for: internalUrl, data: nil, response: nil, error: error)
        let externalUrl = URL(string: GlobalConstants.baseExternalUrlString + apiPath)!
        URLProtocolStub.setStub(for: externalUrl, data: nil, response: nil, error: error)

        let testDelegate = URLCreatorTestDelegate()
        urlCreator.delegate = testDelegate
        let expectation = XCTestExpectation(description: "Connection state updates to .disconnected")
        testDelegate.expectation = expectation
        testDelegate.expectedState = .disconnected

        // Test the connection state
        await urlCreator.updateConnectionState()
        await fulfillment(of: [expectation], timeout: 0.2)
        XCTAssertEqual(urlCreator.connectionState, .disconnected)
    }

    func test_createURLRequest_withValidUrl_shouldReturnRequest() {
        let url = "http://example.com"
        let path = "/test"
        let method: HTTPMethod = .get
        let expectedUrl = URL(string: "\(url)\(path)")!

        let urlRequestParameters = URLRequestParameters(forceURLString: url, path: path, method: method)
        let request = urlCreator.createURLRequest(urlRequestParameters: urlRequestParameters)!

        XCTAssertEqual(request.url, expectedUrl)
        XCTAssertEqual(request.httpMethod?.lowercased(), method.rawValue.lowercased())
        XCTAssertNil(request.httpBody)
    }

    func test_createURLRequest_withQueryParams_shouldReturnRequestWithQueryParams() {
        let urlCreator = URLCreator()
        let path = "/test"
        let queryParams: [String: String] = ["param1": "value1", "param2": "value2"]

        let urlRequestParameters = URLRequestParameters(forceURLString: "http://example.com",
                                                        path: path,
                                                        queryParams: queryParams,
                                                        method: .get)
        let request = urlCreator.createURLRequest(urlRequestParameters: urlRequestParameters)
        XCTAssertNotNil(request)

        guard let url = request?.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            XCTFail("Invalid URL")
            return
        }

        XCTAssertEqual(components.host, "example.com")
        XCTAssertEqual(components.path, path)
        XCTAssertEqual(components.scheme, "http")

        guard let queryItems = components.queryItems else {
            XCTFail("Missing query items")
            return
        }

        let queryItemsDict = Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value) })

        XCTAssertEqual(queryItemsDict.count, queryParams.count)
        for (key, value) in queryParams {
            XCTAssertEqual(queryItemsDict[key], value)
        }
    }
}
