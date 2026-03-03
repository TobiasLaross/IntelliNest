@testable import IntelliNest
import XCTest

@MainActor
class HomeViewModelTests: XCTestCase {
    var viewModel: HomeViewModel!
    var restAPIService: RestAPIService!
    var yaleAPIService: YaleApiService!
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
        yaleAPIService = YaleApiService(hassAPIService: restAPIService, session: stubbedSession)
        viewModel = HomeViewModel(
            restAPIService: restAPIService,
            yaleApiService: yaleAPIService,
            urlCreator: urlCreator,
            showHeatersAction: {},
            showLynkAction: {},
            showRoborockAction: {},
            showPowerGridAction: {},
            showLightsAction: {},
            toolbarReloadAction: {}
        )
    }

    override func tearDown() async throws {
        URLProtocolStub.stopInterceptingRequests()
        viewModel = nil
        restAPIService = nil
        yaleAPIService = nil
        urlCreator = nil
    }

    // MARK: - Helpers

    private func makeEntityJSON(entityId: String, state: String) -> Data {
        Data("""
        {
            "entity_id": "\(entityId)",
            "state": "\(state)",
            "last_changed": "2023-06-17T13:30:00.215607+00:00",
            "last_updated": "2023-06-17T13:30:00.215607+00:00"
        }
        """.utf8)
    }

    private func stubEntityURL(entityID: EntityId, state: String) {
        var components = URLComponents(string: GlobalConstants.baseInternalUrlString)!
        components.path = "/api/states/\(entityID.rawValue)"
        let url = components.url!
        let data = makeEntityJSON(entityId: entityID.rawValue, state: state)
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        URLProtocolStub.setStub(for: url, data: data, response: response, error: nil)
    }

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertEqual(viewModel.coffeeMachine.state, "Loading")
        XCTAssertEqual(viewModel.pulsePower.state, "Loading")
        XCTAssertEqual(viewModel.tibberPrice.state, "Loading")
        XCTAssertEqual(viewModel.pulseConsumptionToday.state, "Loading")
        XCTAssertEqual(viewModel.washerState.state, "Loading")
        XCTAssertEqual(viewModel.dryerState.state, "Loading")
        XCTAssertEqual(viewModel.easeeStatus.state, "Loading")
        XCTAssertEqual(viewModel.allLights.state, "Loading")
        XCTAssertEqual(viewModel.storageLock.state, "Loading")
        XCTAssertFalse(viewModel.noLocationAccess)
    }

    // MARK: - reload(entityID:state:) Dispatch

    func testReloadEntityIDUpdatesAllLights() {
        // Given / When
        viewModel.reload(entityID: .allLights, state: "on")
        // Then
        XCTAssertEqual(viewModel.allLights.state, "on")
        XCTAssertTrue(viewModel.allLights.isActive)
    }

    func testReloadEntityIDUpdatesCoffeeMachine() {
        // Given / When
        viewModel.reload(entityID: .coffeeMachine, state: "on")
        // Then
        XCTAssertEqual(viewModel.coffeeMachine.state, "on")
        XCTAssertTrue(viewModel.coffeeMachine.isActive)
    }

    func testReloadEntityIDUpdatesCoffeeMachineLastChanged() {
        // Given
        let lastChanged = Date(timeIntervalSinceReferenceDate: 700_000_000)
        // When
        viewModel.reload(entityID: .coffeeMachine, state: "on", lastChanged: lastChanged)
        // Then
        XCTAssertEqual(viewModel.coffeeMachine.lastChanged, lastChanged)
    }

    func testReloadEntityIDDoesNotOverwriteCoffeeMachineLastChangedWhenNil() {
        // Given
        let originalLastChanged = viewModel.coffeeMachine.lastChanged
        // When
        viewModel.reload(entityID: .coffeeMachine, state: "off", lastChanged: nil)
        // Then
        XCTAssertEqual(viewModel.coffeeMachine.lastChanged, originalLastChanged)
    }

    func testReloadEntityIDUpdatesStorageLock() {
        // Given / When
        viewModel.reload(entityID: .storageLock, state: "locked")
        // Then
        XCTAssertEqual(viewModel.storageLock.state, "locked")
        XCTAssertEqual(viewModel.storageLock.lockState, .locked)
    }

    func testReloadEntityIDUpdatesSarahsIphone() {
        // Given / When
        viewModel.reload(entityID: .hittaSarahsIphone, state: "on")
        // Then
        XCTAssertEqual(viewModel.sarahsIphone.state, "on")
        XCTAssertTrue(viewModel.sarahsIphone.isActive)
    }

    func testReloadEntityIDUpdatesCoffeeMachineStartTime() {
        // Given / When
        viewModel.reload(entityID: .coffeeMachineStartTime, state: "07:30:00")
        // Then
        XCTAssertEqual(viewModel.coffeeMachineStartTime.state, "07:30:00")
    }

    func testReloadEntityIDUpdatesCoffeeMachineStartTimeEnabled() {
        // Given / When
        viewModel.reload(entityID: .coffeeMachineStartTimeEnabled, state: "on")
        // Then
        XCTAssertEqual(viewModel.coffeeMachineStartTimeEnabled.state, "on")
        XCTAssertTrue(viewModel.coffeeMachineStartTimeEnabled.isActive)
    }

    func testReloadEntityIDUpdatesPulsePower() {
        // Given / When
        viewModel.reload(entityID: .pulsePower, state: "1234")
        // Then
        XCTAssertEqual(viewModel.pulsePower.state, "1234")
    }

    func testReloadEntityIDUpdatesTibberPrice() {
        // Given / When
        viewModel.reload(entityID: .tibberPrice, state: "0.85")
        // Then
        XCTAssertEqual(viewModel.tibberPrice.state, "0.85")
    }

    func testReloadEntityIDUpdatesPulseConsumptionToday() {
        // Given / When
        viewModel.reload(entityID: .pulseConsumptionToday, state: "15.3")
        // Then
        XCTAssertEqual(viewModel.pulseConsumptionToday.state, "15.3")
    }

    func testReloadEntityIDUpdatesSolarProductionToday() {
        // Given / When
        viewModel.reload(entityID: .solarProducdtionToday, state: "8.7")
        // Then
        XCTAssertEqual(viewModel.solarProducdtionToday.state, "8.7")
    }

    func testReloadEntityIDUpdatesWasherCompletionTime() {
        // Given / When
        viewModel.reload(entityID: .washerCompletionTime, state: "2023-06-17 15:30:00")
        // Then
        XCTAssertEqual(viewModel.washerCompletionTime.state, "2023-06-17 15:30:00")
    }

    func testReloadEntityIDUpdatesWasherState() {
        // Given / When
        viewModel.reload(entityID: .washerState, state: "run")
        // Then
        XCTAssertEqual(viewModel.washerState.state, "run")
    }

    func testReloadEntityIDUpdatesDryerCompletionTime() {
        // Given / When
        viewModel.reload(entityID: .dryerCompletionTime, state: "2023-06-17 17:30:00")
        // Then
        XCTAssertEqual(viewModel.dryerCompletionTime.state, "2023-06-17 17:30:00")
    }

    func testReloadEntityIDUpdatesDryerState() {
        // Given / When
        viewModel.reload(entityID: .dryerState, state: "drying")
        // Then
        XCTAssertEqual(viewModel.dryerState.state, "drying")
    }

    func testReloadEntityIDUpdatesEaseePower() {
        // Given / When
        viewModel.reload(entityID: .easeePower, state: "7200")
        // Then
        XCTAssertEqual(viewModel.easeePower.state, "7200")
    }

    func testReloadEntityIDUpdatesEaseeNoCurrentReason() {
        // Given / When
        viewModel.reload(entityID: .easeeNoCurrentReason, state: "pending_schedule")
        // Then
        XCTAssertEqual(viewModel.easeeNoCurrentReason.state, "pending_schedule")
    }

    func testReloadEntityIDUpdatesEaseeStatus() {
        // Given / When
        viewModel.reload(entityID: .easeeStatus, state: "charging")
        // Then
        XCTAssertEqual(viewModel.easeeStatus.state, "charging")
    }

    func testReloadEntityIDUpdatesGeneralWasteDate() {
        // Given / When
        viewModel.reload(entityID: .generalWasteDate, state: "2023-06-20")
        // Then
        XCTAssertEqual(viewModel.generalWasteDate.state, "2023-06-20")
    }

    func testReloadEntityIDUpdatesPlasticWasteDate() {
        // Given / When
        viewModel.reload(entityID: .plasticWasteDate, state: "2023-06-27")
        // Then
        XCTAssertEqual(viewModel.plasticWasteDate.state, "2023-06-27")
    }

    func testReloadEntityIDUpdatesGardenWasteDate() {
        // Given / When
        viewModel.reload(entityID: .gardenWasteDate, state: "2023-07-04")
        // Then
        XCTAssertEqual(viewModel.gardenWasteDate.state, "2023-07-04")
    }

    // MARK: - Computed Properties

    func testIsEaseeCharging_whenStatusIsCharging() {
        // Given / When
        viewModel.reload(entityID: .easeeStatus, state: "charging")
        // Then
        XCTAssertTrue(viewModel.isEaseeCharging)
    }

    func testIsEaseeCharging_whenStatusIsNotCharging() {
        // Given / When
        viewModel.reload(entityID: .easeeStatus, state: "awaiting_start")
        // Then
        XCTAssertFalse(viewModel.isEaseeCharging)
    }

    func testIsEaseeCharging_isCaseInsensitive() {
        // Given / When
        viewModel.reload(entityID: .easeeStatus, state: "Charging")
        // Then
        XCTAssertTrue(viewModel.isEaseeCharging)
    }

    func testIsEaseeAwaitingSchedule_whenNoCurrentReasonIsPendingSchedule() {
        // Given / When
        viewModel.reload(entityID: .easeeNoCurrentReason, state: "pending_schedule")
        // Then
        XCTAssertTrue(viewModel.isEaseeAwaitingSchedule)
    }

    func testIsEaseeAwaitingSchedule_whenStatusIsAwaitingStart() {
        // Given / When
        viewModel.reload(entityID: .easeeStatus, state: "awaiting_start")
        // Then
        XCTAssertTrue(viewModel.isEaseeAwaitingSchedule)
    }

    func testIsEaseeAwaitingSchedule_whenNeither() {
        // Given / When
        viewModel.reload(entityID: .easeeNoCurrentReason, state: "idle")
        viewModel.reload(entityID: .easeeStatus, state: "charging")
        // Then
        XCTAssertFalse(viewModel.isEaseeAwaitingSchedule)
    }

    // MARK: - Lock State

    func testResetExpectedLockStates() {
        // Given
        viewModel.storageLock.expectedState = .locked
        viewModel.frontDoor.expectedState = .locked
        viewModel.sideDoor.expectedState = .locked
        // When
        viewModel.resetExpectedLockStates()
        // Then
        XCTAssertEqual(viewModel.storageLock.expectedState, .unknown)
        XCTAssertEqual(viewModel.frontDoor.expectedState, .unknown)
        XCTAssertEqual(viewModel.sideDoor.expectedState, .unknown)
    }

    func testToggleStateForStorageLock_setsExpectedStateLocked() {
        // Given
        viewModel.reload(entityID: .storageLock, state: "unlocked")
        // When
        viewModel.toggleStateForStorageLock()
        // Then
        XCTAssertEqual(viewModel.storageLock.expectedState, .locked)
    }

    func testToggleStateForStorageLock_setsExpectedStateUnlocked() {
        // Given
        viewModel.reload(entityID: .storageLock, state: "locked")
        // When
        viewModel.toggleStateForStorageLock()
        // Then
        XCTAssertEqual(viewModel.storageLock.expectedState, .unlocked)
    }

    func testLockStorage_setsExpectedStateLocked() {
        // Given / When
        viewModel.lockStorage()
        // Then
        XCTAssertEqual(viewModel.storageLock.expectedState, .locked)
    }

    func testUnlockStorage_setsExpectedStateUnlocked() {
        // Given / When
        viewModel.unlockStorage()
        // Then
        XCTAssertEqual(viewModel.storageLock.expectedState, .unlocked)
    }

    // MARK: - Network Reload

    func testReloadFetchesAllEntitiesFromNetwork() async {
        // Given: stub all entity URLs with mock responses
        let entityStates: [EntityId: String] = [
            .hittaSarahsIphone: "off",
            .coffeeMachine: "on",
            .storageLock: "locked",
            .coffeeMachineStartTime: "07:30:00",
            .coffeeMachineStartTimeEnabled: "on",
            .pulsePower: "1500",
            .tibberPrice: "1.23",
            .pulseConsumptionToday: "12.5",
            .washerCompletionTime: "2023-06-17 15:30:00",
            .solarProducdtionToday: "5.2",
            .dryerCompletionTime: "2023-06-17 17:00:00",
            .washerState: "run",
            .dryerState: "cooling",
            .easeePower: "7200",
            .easeeNoCurrentReason: "idle",
            .easeeStatus: "charging",
            .generalWasteDate: "2023-06-20",
            .plasticWasteDate: "2023-06-27",
            .gardenWasteDate: "2023-07-04",
            .allLights: "off"
        ]
        for (entityID, state) in entityStates {
            stubEntityURL(entityID: entityID, state: state)
        }

        // When
        await viewModel.reload()

        // Then
        XCTAssertEqual(viewModel.coffeeMachine.state, "on")
        XCTAssertEqual(viewModel.pulsePower.state, "1500")
        XCTAssertEqual(viewModel.easeeStatus.state, "charging")
        XCTAssertEqual(viewModel.storageLock.state, "locked")
        XCTAssertEqual(viewModel.allLights.state, "off")
        XCTAssertEqual(viewModel.washerState.state, "run")
        XCTAssertEqual(viewModel.dryerState.state, "cooling")
        XCTAssertEqual(viewModel.generalWasteDate.state, "2023-06-20")
    }

    func testReloadSilentlyHandlesNetworkFailure() async {
        // Given: no stubs registered – all requests will fail
        // When
        await viewModel.reload()
        // Then: entities remain in their initial Loading state
        XCTAssertEqual(viewModel.coffeeMachine.state, "Loading")
        XCTAssertEqual(viewModel.pulsePower.state, "Loading")
        XCTAssertEqual(viewModel.easeeStatus.state, "Loading")
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
}
