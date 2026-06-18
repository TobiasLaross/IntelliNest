@testable import IntelliNest
import XCTest

/// Covers how ElectricityViewModel reconciles the real-time Tibber Pulse against the laggy SolarEdge
/// cloud sensor: solar is lifted to the live net export when the inverter reading is stale, and house
/// power is clamped so the laggy data never makes the house look like it is exporting power.
@MainActor
class ElectricityViewModelSensorLagTests: XCTestCase {
    private var viewModel: ElectricityViewModel!
    private var restAPIService: RestAPIService!
    private var urlCreator: URLCreator!

    private let staleTimestamp = "2023-06-17T13:30:00.000000+00:00"
    private let freshTimestamp = "2023-06-17T13:43:00.000000+00:00"

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

    // MARK: - House clamp (no timestamps needed)

    func testHousePower_clampsToZeroWhenExportExceedsSolar() {
        // Given: a fresh Pulse export of 5 kW against a 3 kW solar reading (equal timestamps, so no
        // recency lift). solar + gridPower = 3000 + (0 - 5000) = -2000, which is physically
        // impossible — a house never exports on its own.
        viewModel.reload(entityID: .solarPower, state: "3000")
        viewModel.reload(entityID: .pulsePower, state: "0")
        viewModel.reload(entityID: .pulsePowerProduction, state: "5000")
        // Then: clamped to zero rather than shown as the house producing 2 kW
        XCTAssertEqual(viewModel.housePower, 0)
    }

    // MARK: - Solar lift across sensor lag

    func testSolarPower_liftsStaleSolarToFreshExport() async {
        // Given: the screenshot scenario — SolarEdge stuck at a stale 3.2 kW while the Pulse freshly
        // reports 5.7 kW exported and nothing imported. The panels must be making at least what is
        // being exported, so solar is lifted to the live net export.
        await reload(
            solar: ("3200", staleTimestamp),
            gridImport: ("0", freshTimestamp),
            gridExport: ("5700", freshTimestamp)
        )
        // Then: solar reflects the live export, grid stays accurate, house settles at ~0 (all exported)
        XCTAssertEqual(viewModel.solarPower, 5700)
        XCTAssertEqual(viewModel.gridPower, -5700)
        XCTAssertEqual(viewModel.housePower, 0)
    }

    func testSolarPower_keepsInverterValueWhenItIsFresher() async {
        // Given: the inverter reading is the newer of the two, so a stale-high export must not drag
        // the solar figure up — the fresh inverter value is authoritative.
        await reload(
            solar: ("3200", freshTimestamp),
            gridImport: ("0", staleTimestamp),
            gridExport: ("5700", staleTimestamp)
        )
        // Then: solar stays at the inverter value; house is still clamped away from negative
        XCTAssertEqual(viewModel.solarPower, 3200)
        XCTAssertEqual(viewModel.gridPower, -5700)
        XCTAssertEqual(viewModel.housePower, 0)
    }

    func testSolarPower_doesNotLiftWhenImporting() async {
        // Given: a fresher Pulse but the house is importing 2 kW (net export negative), so the lower
        // bound never exceeds the inverter reading and solar is left untouched.
        await reload(
            solar: ("1000", staleTimestamp),
            gridImport: ("2000", freshTimestamp),
            gridExport: ("0", freshTimestamp)
        )
        // Then: solar unchanged, house = solar + import = 3 kW
        XCTAssertEqual(viewModel.solarPower, 1000)
        XCTAssertEqual(viewModel.gridPower, 2000)
        XCTAssertEqual(viewModel.housePower, 3000)
    }

    // MARK: - Helpers

    /// Stubs the power trio with explicit timestamps plus the remaining entities, then reloads.
    private func reload(
        solar: (state: String, lastUpdated: String),
        gridImport: (state: String, lastUpdated: String),
        gridExport: (state: String, lastUpdated: String)
    ) async {
        stubEntityURL(entityID: .solarPower, state: solar.state, lastUpdated: solar.lastUpdated)
        stubEntityURL(entityID: .pulsePower, state: gridImport.state, lastUpdated: gridImport.lastUpdated)
        stubEntityURL(entityID: .pulsePowerProduction, state: gridExport.state, lastUpdated: gridExport.lastUpdated)
        stubEntityURL(entityID: .tibberCostToday, state: "0")
        stubEntityURL(entityID: .pulseConsumptionToday, state: "0")
        stubEntityURL(entityID: .nordPool, data: nordPoolStub)
        await viewModel.reload()
    }

    private var nordPoolStub: Data {
        Data("""
        {
            "entity_id": "\(EntityId.nordPool.rawValue)",
            "state": "100",
            "attributes": { "today": [100], "tomorrow": [], "tomorrow_valid": false }
        }
        """.utf8)
    }
}
