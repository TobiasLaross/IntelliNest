//
//  URLProtocolStub.swift
//  IntelliNestTests
//
//  Created by Tobias on 2023-05-06.
//

import Foundation

/// Holds stubbed responses open until a test releases them.
///
/// This replaces the stub's old `delay:` parameter. A delay bought request overlap
/// with wall-clock time, which is what made the tests using it racy: on a loaded
/// machine the "still in flight" window could close before the test looked, and the
/// assertions that measured elapsed time were really measuring the runner's mood. A
/// gate makes the overlap a fact — a held request cannot complete until `open()` —
/// and `waitForRequests(count:)` resumes the moment the requests actually arrive.
final class StubGate: @unchecked Sendable {
    private let lock = NSLock()
    private var isOpen = false
    private var heldWork: [DispatchWorkItem] = []
    private var arrivedCount = 0
    private var waiters: [(needed: Int, continuation: CheckedContinuation<Void, Never>)] = []

    /// Called by the stub when a request reaches this gate.
    func arrive(_ work: DispatchWorkItem) {
        lock.lock()
        arrivedCount += 1
        let ready = waiters.filter { arrivedCount >= $0.needed }
        waiters.removeAll { arrivedCount >= $0.needed }
        let runNow = isOpen
        if !runNow {
            heldWork.append(work)
        }
        lock.unlock()

        for waiter in ready {
            waiter.continuation.resume()
        }
        if runNow {
            work.perform()
        }
    }

    /// Resumes once `count` requests have reached the gate.
    ///
    /// Deliberately has no deadline. If the requests never arrive the test hangs and
    /// the run says so, which is the honest outcome — a short wait expiring instead
    /// would let the assertions that follow pass on a lie.
    func waitForRequests(count: Int) async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if arrivedCount >= count {
                lock.unlock()
                continuation.resume()
                return
            }
            waiters.append((count, continuation))
            lock.unlock()
        }
    }

    /// Lets every held request finish, and any later one straight through.
    func open() {
        lock.lock()
        isOpen = true
        let pending = heldWork
        heldWork = []
        lock.unlock()
        // Off the caller's thread, matching where a held response used to resume.
        for work in pending {
            DispatchQueue.global().async(execute: work)
        }
    }
}

/// Records intercepted requests matching a predicate, and lets a test await the
/// first match.
///
/// Some work is dispatched into a detached `Task` (logging, the system-log
/// forwarder) and so finishes after the call that started it has returned. Awaiting
/// the request itself is exact; the `XCTestExpectation` + `timeout:` this replaces
/// was a wall-clock deadline that a loaded machine could miss.
///
/// Installing a recorder replaces the stub's single request observer, so use one at
/// a time — which is how these tests already worked.
final class RequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private let matches: (URLRequest) -> Bool
    private var recorded: [URLRequest] = []
    private var waiters: [(count: Int, continuation: CheckedContinuation<[URLRequest], Never>)] = []

    init(where matches: @escaping (URLRequest) -> Bool) {
        self.matches = matches
        URLProtocolStub.observerRequests { [weak self] request in
            self?.record(request)
        }
    }

    /// Every matching request seen so far. Use this when the call under test is
    /// itself `await`ed, so the request has already been made by the time you look.
    var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    /// Suspends until a matching request arrives, returning the first one.
    ///
    /// Deliberately has no deadline: a request that never arrives hangs the test and
    /// the run says so, rather than a short wait expiring and letting the assertions
    /// after it pass on a lie.
    func first() async -> URLRequest {
        await waitForRequests(count: 1)[0]
    }

    /// Suspends until `count` matching requests have arrived. A test that fires
    /// several untracked requests awaits them all here, so a straggler can't land
    /// after the test ends and be counted by the next test's recorder.
    @discardableResult
    func waitForRequests(count: Int) async -> [URLRequest] {
        await withCheckedContinuation { continuation in
            lock.lock()
            if recorded.count >= count {
                let snapshot = recorded
                lock.unlock()
                continuation.resume(returning: snapshot)
                return
            }
            waiters.append((count, continuation))
            lock.unlock()
        }
    }

    private func record(_ request: URLRequest) {
        guard matches(request) else {
            return
        }
        lock.lock()
        recorded.append(request)
        let snapshot = recorded
        let ready = waiters.filter { $0.count <= snapshot.count }
        waiters.removeAll { $0.count <= snapshot.count }
        lock.unlock()
        for waiter in ready {
            waiter.continuation.resume(returning: snapshot)
        }
    }
}

class URLProtocolStub: URLProtocol {
    private static let stubLock = NSLock()
    private static var stubs: [URL: Stub] = [:]
    private static var requestObserver: ((URLRequest) -> Void)?

    private struct Stub {
        let data: Data?
        let response: URLResponse?
        let error: Error?
        let gate: StubGate?
    }

    private var pendingWork: DispatchWorkItem?

    static func setStub(for url: URL, data: Data?, response: URLResponse?, error: Error?, gate: StubGate? = nil) {
        let stub = Stub(data: data, response: response, error: error, gate: gate)
        stubLock.lock()
        stubs[url] = stub
        stubLock.unlock()
    }

    static func observerRequests(observer: @escaping (URLRequest) -> Void) {
        stubLock.lock()
        requestObserver = observer
        stubLock.unlock()
    }

    static func startInterceptingRequests() {
        URLProtocolStub.registerClass(URLProtocolStub.self)
    }

    static func stopInterceptingRequests() {
        URLProtocolStub.unregisterClass(URLProtocolStub.self)
        stubLock.lock()
        stubs.removeAll()
        requestObserver = nil
        stubLock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        stubLock.lock()
        let observer = requestObserver
        stubLock.unlock()
        observer?(request)
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        URLProtocolStub.stubLock.lock()
        let stub = URLProtocolStub.stubs[url]
        URLProtocolStub.stubLock.unlock()

        guard let stub else {
            // No stub registered – simulate a network failure so background Tasks
            // complete quickly and don't call urlProtocolDidFinishLoading without a
            // response (which violates the URLProtocol contract and can crash URLSession).
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if let response = stub.response {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            if let data = stub.data {
                client?.urlProtocol(self, didLoad: data)
            }
            if let error = stub.error {
                client?.urlProtocol(self, didFailWithError: error)
            } else {
                client?.urlProtocolDidFinishLoading(self)
            }
        }
        pendingWork = work

        if let gate = stub.gate {
            gate.arrive(work)
        } else {
            work.perform()
        }
    }

    override func stopLoading() {
        pendingWork?.cancel()
        pendingWork = nil
    }

    static func createStubbedURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let urlSession = URLSession(configuration: configuration)
        return urlSession
    }
}
