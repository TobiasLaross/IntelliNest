@testable import IntelliNest
import XCTest

extension HomeViewModelTests {
    func testReloadObservesCorrectURLs() async {
        // Given
        let lock = NSLock()
        var observedPaths: [String] = []
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
        // Given: each entity stub has a 0.1 s delay.
        // Sequential execution would take 20 × 0.1 s = 2 s; parallel should be well under 1 s.
        let delayPerEntity = 0.1
        for entityID in viewModel.entityIDs {
            var components = URLComponents(string: GlobalConstants.baseInternalUrlString)!
            components.path = "/api/states/\(entityID.rawValue)"
            let url = components.url!
            let data = makeEntityJSON(entityId: entityID.rawValue, state: "on")
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            URLProtocolStub.setStub(for: url, data: data, response: response, error: nil, delay: delayPerEntity)
        }

        // When
        let start = Date()
        await viewModel.reload()
        let elapsed = Date().timeIntervalSince(start)

        // Then: all entities loaded, and total time is much less than sequential would require
        let sequentialTime = Double(viewModel.entityIDs.count) * delayPerEntity
        XCTAssertLessThan(elapsed, sequentialTime, "Parallel: \(elapsed)s; sequential would be \(sequentialTime)s")
        XCTAssertEqual(viewModel.coffeeMachine.state, "on")
        XCTAssertEqual(viewModel.easeeStatus.state, "on")
        XCTAssertEqual(viewModel.allLights.state, "on")
    }
}
