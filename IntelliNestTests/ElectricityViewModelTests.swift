@testable import IntelliNest
import XCTest

@MainActor
class ElectricityViewModelTests: XCTestCase {
    var viewModel: ElectricityViewModel!
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
        viewModel = ElectricityViewModel(restAPIService: restAPIService)
    }

    override func tearDown() async throws {
        URLProtocolStub.stopInterceptingRequests()
        viewModel = nil
        restAPIService = nil
        urlCreator = nil
    }

    // MARK: - Helpers

    private func makeNordPoolJSON(state: String, today: [Int], tomorrow: [Int], tomorrowValid: Bool) -> Data {
        let todayJSON = today.map(String.init).joined(separator: ", ")
        let tomorrowJSON = tomorrow.map(String.init).joined(separator: ", ")
        return Data("""
        {
            "entity_id": "\(EntityId.nordPool.rawValue)",
            "state": "\(state)",
            "attributes": {
                "today": [\(todayJSON)],
                "tomorrow": [\(tomorrowJSON)],
                "tomorrow_valid": \(tomorrowValid)
            }
        }
        """.utf8)
    }

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertEqual(viewModel.nordPool.state, "Loading")
        XCTAssertEqual(viewModel.tibberCostToday.state, "Loading")
        XCTAssertEqual(viewModel.pulseConsumptionToday.state, "Loading")
        XCTAssertEqual(viewModel.housePower, 0)
        XCTAssertEqual(viewModel.solarPower, 0)
    }

    // MARK: - reload(entityID:state:) Dispatch

    func testReloadEntityIDUpdatesPulsePower() {
        // Given / When
        viewModel.reload(entityID: .pulsePower, state: "2500")
        // Then
        XCTAssertEqual(viewModel.housePower, 2500)
    }

    func testReloadEntityIDUpdatesTibberCostToday() {
        // Given / When
        viewModel.reload(entityID: .tibberCostToday, state: "42.5")
        // Then
        XCTAssertEqual(viewModel.tibberCostToday.state, "42.5")
    }

    func testReloadEntityIDUpdatesPulseConsumptionToday() {
        // Given / When
        viewModel.reload(entityID: .pulseConsumptionToday, state: "18.3")
        // Then
        XCTAssertEqual(viewModel.pulseConsumptionToday.state, "18.3")
    }

    func testReloadEntityIDUpdatesSolarPower() {
        // Given / When
        viewModel.reload(entityID: .solarPower, state: "3000")
        // Then
        XCTAssertEqual(viewModel.solarPower, 3000)
    }

    // MARK: - Computed Property: solarPower

    func testSolarPower_whenStateIsNumeric() {
        // Given / When
        viewModel.reload(entityID: .solarPower, state: "4500")
        // Then
        XCTAssertEqual(viewModel.solarPower, 4500)
    }

    func testSolarPower_whenStateIsNonNumeric() {
        // Given / When
        viewModel.reload(entityID: .solarPower, state: "unavailable")
        // Then
        XCTAssertEqual(viewModel.solarPower, 0)
    }

    // MARK: - Computed Property: housePower

    func testHousePower_whenStateIsNumeric() {
        // Given / When
        viewModel.reload(entityID: .pulsePower, state: "1800")
        // Then
        XCTAssertEqual(viewModel.housePower, 1800)
    }

    func testHousePower_whenStateIsNonNumeric() {
        // Given / When
        viewModel.reload(entityID: .pulsePower, state: "unavailable")
        // Then
        XCTAssertEqual(viewModel.housePower, 0)
    }

    // MARK: - Computed Property: gridPower

    func testGridPower_equalsPulsePower() {
        // Given / When
        viewModel.reload(entityID: .pulsePower, state: "3000")
        viewModel.reload(entityID: .solarPower, state: "1000")
        // Then
        XCTAssertEqual(viewModel.gridPower, 3000)
        XCTAssertEqual(viewModel.housePower, 4000)
    }

    func testGridPower_isNegativeWhenExportingToGrid() {
        // Given / When: exporting 3 kW to grid
        viewModel.reload(entityID: .pulsePower, state: "-3000")
        viewModel.reload(entityID: .solarPower, state: "4000")
        // Then
        XCTAssertEqual(viewModel.gridPower, -3000)
        XCTAssertEqual(viewModel.housePower, 1000)
    }

    // MARK: - Computed Property: isSolarToGrid

    func testIsSolarToGrid_whenSolarExceedsHouseConsumption() {
        // Given: solar produces 5 kW, house consumes 1 kW → exporting 4 kW to grid
        viewModel.reload(entityID: .solarPower, state: "5000")
        viewModel.reload(entityID: .pulsePower, state: "-4000")
        // Then
        XCTAssertTrue(viewModel.isSolarToGrid)
    }

    func testIsSolarToGrid_whenSolarIsBelowHouseConsumption() {
        // Given: solar produces 1 kW, house consumes 3 kW → drawing 2 kW from grid
        viewModel.reload(entityID: .solarPower, state: "1000")
        viewModel.reload(entityID: .pulsePower, state: "3000")
        // Then
        XCTAssertFalse(viewModel.isSolarToGrid)
    }

    func testIsSolarToGrid_whenNoSolarProduction() {
        // Given: no solar production
        viewModel.reload(entityID: .solarPower, state: "0")
        viewModel.reload(entityID: .pulsePower, state: "2000")
        // Then
        XCTAssertFalse(viewModel.isSolarToGrid)
    }

    // MARK: - Computed Property: isSolarToHouse

    func testIsSolarToHouse_whenSolarPartiallyCoversConsumption() {
        // Given: solar covers 1.5 kW of a 3 kW load
        viewModel.reload(entityID: .solarPower, state: "1500")
        viewModel.reload(entityID: .pulsePower, state: "3000")
        // Then
        XCTAssertTrue(viewModel.isSolarToHouse)
    }

    func testIsSolarToHouse_whenSolarFullyCoversPlusExports() {
        // Given: solar produces 5 kW, house consumes 1 kW → exporting 4 kW to grid
        viewModel.reload(entityID: .solarPower, state: "5000")
        viewModel.reload(entityID: .pulsePower, state: "-4000")
        // Then
        XCTAssertTrue(viewModel.isSolarToHouse)
    }

    func testIsSolarToHouse_whenNoSolarProduction() {
        // Given: no solar production
        viewModel.reload(entityID: .solarPower, state: "0")
        viewModel.reload(entityID: .pulsePower, state: "2000")
        // Then
        XCTAssertFalse(viewModel.isSolarToHouse)
    }

    // MARK: - Computed Property: isGridToHouse

    func testIsGridToHouse_whenDrawingFromGrid() {
        // Given: house draws 2 kW from grid (no solar)
        viewModel.reload(entityID: .solarPower, state: "0")
        viewModel.reload(entityID: .pulsePower, state: "2000")
        // Then
        XCTAssertTrue(viewModel.isGridToHouse)
    }

    func testIsGridToHouse_whenSolarCoversAllConsumption() {
        // Given: solar produces 5 kW, house consumes 1 kW → exporting 4 kW to grid
        viewModel.reload(entityID: .solarPower, state: "5000")
        viewModel.reload(entityID: .pulsePower, state: "-4000")
        // Then
        XCTAssertFalse(viewModel.isGridToHouse)
    }

    func testIsGridToHouse_whenSolarPartiallyCoversConsumption() {
        // Given: solar covers 1 kW, house needs 3 kW → drawing 2 kW from grid
        viewModel.reload(entityID: .solarPower, state: "1000")
        viewModel.reload(entityID: .pulsePower, state: "2000")
        // Then
        XCTAssertTrue(viewModel.isGridToHouse)
    }

    // MARK: - Network Reload

    func testReloadFetchesRegularEntitiesFromNetwork() async {
        // Given: stub all non-NordPool entity URLs
        let entityStates: [EntityId: String] = [
            .pulsePower: "2000",
            .tibberCostToday: "55.0",
            .pulseConsumptionToday: "20.5",
            .solarPower: "1000"
        ]
        for (entityID, state) in entityStates {
            stubEntityURL(entityID: entityID, state: state)
        }
        // Stub NordPool with valid JSON so reload() doesn't fail for it
        let nordPoolData = makeNordPoolJSON(
            state: "120",
            today: [80, 90, 100, 110],
            tomorrow: [],
            tomorrowValid: false
        )
        stubEntityURL(entityID: .nordPool, data: nordPoolData)

        // When
        await viewModel.reload()

        // Then
        XCTAssertEqual(viewModel.housePower, 3000)
        XCTAssertEqual(viewModel.solarPower, 1000)
        XCTAssertEqual(viewModel.tibberCostToday.state, "55.0")
        XCTAssertEqual(viewModel.pulseConsumptionToday.state, "20.5")
    }

    func testReloadFetchesNordPoolEntityFromNetwork() async {
        // Given: stub NordPool URL with price data
        let today = Array(1 ... 96).map { $0 * 10 }
        let tomorrow = Array(1 ... 96).map { $0 * 12 }
        let nordPoolData = makeNordPoolJSON(
            state: "250",
            today: today,
            tomorrow: tomorrow,
            tomorrowValid: true
        )
        stubEntityURL(entityID: .nordPool, data: nordPoolData)
        // Stub remaining entities so the reload loop doesn't stall on them
        for entityID in viewModel.entityIDs where entityID != .nordPool {
            stubEntityURL(entityID: entityID, state: "0")
        }

        // When
        await viewModel.reload()

        // Then
        XCTAssertEqual(viewModel.nordPool.state, "250")
        XCTAssertFalse(viewModel.nordPool.today.isEmpty)
        XCTAssertFalse(viewModel.nordPool.tomorrow.isEmpty)
        XCTAssertTrue(viewModel.nordPool.tomorrowValid)
    }

    func testReloadSilentlyHandlesNetworkFailure() async {
        // Given: no stubs registered – all requests will fail
        // When
        await viewModel.reload()
        // Then: entities remain in their initial Loading state
        XCTAssertEqual(viewModel.nordPool.state, "Loading")
        XCTAssertEqual(viewModel.tibberCostToday.state, "Loading")
        XCTAssertEqual(viewModel.pulseConsumptionToday.state, "Loading")
    }

    func testReloadObservesCorrectURLs() async {
        // Given
        var observedPaths: [String] = []
        URLProtocolStub.observerRequests { request in
            if let path = request.url?.path {
                observedPaths.append(path)
            }
        }
        for entityID in viewModel.entityIDs {
            if entityID == .nordPool {
                stubEntityURL(entityID: entityID, data: makeNordPoolJSON(state: "100", today: [100], tomorrow: [], tomorrowValid: false))
            } else {
                stubEntityURL(entityID: entityID, state: "0")
            }
        }

        // When
        await viewModel.reload()

        // Then: a request was made for every entity in entityIDs
        let expectedPaths = viewModel.entityIDs.map { "/api/states/\($0.rawValue)" }
        for path in expectedPaths {
            XCTAssertTrue(observedPaths.contains(path), "Expected request for path \(path)")
        }
    }
}
