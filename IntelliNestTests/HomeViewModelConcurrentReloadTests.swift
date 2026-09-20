@testable import IntelliNest
import XCTest

extension HomeViewModelTests {
    func testReloadObservesCorrectURLs() async {
        // Given
        let lock = NSLock()
        var observedPaths: [String] = []
        XCTAssertTrue(observedPaths.isEmpty)
        // Requests arrive from URLSession's internal threads concurrently after parallelisation,
        // so access to observedPaths must be protected.
        URLProtocolStub.observerRequests { request in
            if let path = request.url?.path {
                lock.lock()
                observedPaths.append(path)
                lock.unlock()
            }
        }
        for entityID in viewModel.entityIDs {
            stubEntityURL(entityID: entityID, state: "off")
        }

        // When
        await viewModel.reload()

        // Then: a request was made for every entity in entityIDs
        let expectedPaths = viewModel.entityIDs.map { "/api/states/\($0.rawValue)" }
        for path in expectedPaths {
            XCTAssertTrue(observedPaths.contains(path), "Expected request for path \(path)")
        }
    }

    func testReloadFetchesEntitiesInParallel() async {
        // Every entity stub is held at the same gate, so none of them can answer
        // until this test opens it. A sequential reload would block on the first
        // request and the rest would never arrive — so all of them reaching the gate
        // at once *is* the proof of parallelism. The old version inferred it from
        // elapsed time instead, which measured how busy the machine was.
        let gate = StubGate()
        XCTAssertNotEqual(viewModel.coffeeMachine.state, "on")
        XCTAssertNotEqual(viewModel.easeeStatus.state, "on")
        XCTAssertNotEqual(viewModel.allLights.state, "on")
        for entityID in viewModel.entityIDs {
            var components = URLComponents(string: GlobalConstants.baseInternalUrlString)!
            components.path = "/api/states/\(entityID.rawValue)"
            let url = components.url!
            let data = makeEntityJSON(entityId: entityID.rawValue, state: "on")
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            URLProtocolStub.setStub(for: url, data: data, response: response, error: nil, gate: gate)
        }

        let reload = Task { await viewModel.reload() }
        await gate.waitForRequests(count: viewModel.entityIDs.count)
        gate.open()
        await reload.value

        XCTAssertEqual(viewModel.coffeeMachine.state, "on")
        XCTAssertEqual(viewModel.easeeStatus.state, "on")
        XCTAssertEqual(viewModel.allLights.state, "on")
    }
}
