//
//  URLProtocolStub.swift
//  IntelliNestTests
//
//  Created by Tobias on 2023-05-06.
//

import Foundation

class URLProtocolStub: URLProtocol {
    private static var stubs: [URL: Stub] = [:]
    private static var requestObserver: ((URLRequest) -> Void)?

    private struct Stub {
        let data: Data?
        let response: URLResponse?
        let error: Error?
    }

    static func setStub(for url: URL, data: Data?, response: URLResponse?, error: Error?) {
        let stub = Stub(data: data, response: response, error: error)
        stubs[url] = stub
    }

    static func observerRequests(observer: @escaping (URLRequest) -> Void) {
        requestObserver = observer
    }

    static func startInterceptingRequests() {
        URLProtocolStub.registerClass(URLProtocolStub.self)
    }

    static func stopInterceptingRequests() {
        URLProtocolStub.unregisterClass(URLProtocolStub.self)
        stubs.removeAll()
        requestObserver = nil
    }

    override class func canInit(with request: URLRequest) -> Bool {
        requestObserver?(request)
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        if let url = request.url, let stub = URLProtocolStub.stubs[url] {
            if let data = stub.data {
                client?.urlProtocol(self, didLoad: data)
            }

            if let response = stub.response {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }

            if let error = stub.error {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func createStubbedURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let urlSession = URLSession(configuration: configuration)
        return urlSession
    }
}
