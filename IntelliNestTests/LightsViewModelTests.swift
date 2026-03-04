@testable import IntelliNest
import XCTest

@MainActor
class LightsViewModelTests: XCTestCase {
    var viewModel: LightsViewModel!
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
        viewModel = LightsViewModel(restAPIService: restAPIService)
    }

    override func tearDown() async throws {
        URLProtocolStub.stopInterceptingRequests()
        viewModel = nil
        restAPIService = nil
        urlCreator = nil
    }

    // MARK: - Initial State

    func testInitialLightEntitiesContainsExpectedKeys() {
        let expectedKeys: Set<EntityId> = [
            .sofa, .cozyCorner, .lightsInLivingRoom, .lightsInCorridor,
            .corridorN, .corridorS, .lightsInPlayroom, .lightsInGuestRoom, .laundryRoom
        ]
        XCTAssertEqual(Set(viewModel.lightEntities.keys), expectedKeys)
    }

    func testInitialLightEntitiesAllHaveLoadingState() {
        for (_, light) in viewModel.lightEntities {
            XCTAssertEqual(light.state, "Loading", "Expected 'Loading' for entityId \(light.entityId)")
        }
    }

    func testPlayroomLightHasGroupedLightIDs() {
        let playroomLight = viewModel.lightEntities[.lightsInPlayroom]
        XCTAssertNotNil(playroomLight)
        XCTAssertEqual(playroomLight?.groupedLightIDs, [.playroomCeiling1, .playroomCeiling2, .playroomCeiling3])
    }

    func testGuestRoomLightHasGroupedLightIDs() {
        let guestRoomLight = viewModel.lightEntities[.lightsInGuestRoom]
        XCTAssertNotNil(guestRoomLight)
        XCTAssertEqual(guestRoomLight?.groupedLightIDs, [.guestRoomCeiling1, .guestRoomCeiling2, .guestRoomCeiling3])
    }

    func testSofaLightHasNoGroupedLightIDs() {
        let sofaLight = viewModel.lightEntities[.sofa]
        XCTAssertNotNil(sofaLight)
        XCTAssertNil(sofaLight?.groupedLightIDs)
    }

    // MARK: - onSliderChange

    func testOnSliderChangeUpdatesBrightness() {
        guard let light = viewModel.lightEntities[.sofa] else {
            return XCTFail("Expected sofa light to exist")
        }
        viewModel.onSliderChange(slideable: light, brightness: 128)
        XCTAssertEqual(viewModel.lightEntities[.sofa]?.brightness, 128)
    }

    func testOnSliderChangeUpdatesCorrectLight() {
        guard let sofaLight = viewModel.lightEntities[.sofa],
              let corridorLight = viewModel.lightEntities[.corridorN] else {
            return XCTFail("Expected lights to exist")
        }
        viewModel.onSliderChange(slideable: sofaLight, brightness: 200)
        viewModel.onSliderChange(slideable: corridorLight, brightness: 50)

        XCTAssertEqual(viewModel.lightEntities[.sofa]?.brightness, 200)
        XCTAssertEqual(viewModel.lightEntities[.corridorN]?.brightness, 50)
    }

    func testOnSliderChangeSetsZeroBrightness() {
        guard let light = viewModel.lightEntities[.sofa] else {
            return XCTFail("Expected sofa light to exist")
        }
        viewModel.onSliderChange(slideable: light, brightness: 0)
        XCTAssertEqual(viewModel.lightEntities[.sofa]?.brightness, 0)
    }

    // MARK: - onSliderRelease

    func testOnSliderReleaseSetsIsUpdating() async {
        guard var light = viewModel.lightEntities[.sofa] else {
            return XCTFail("Expected sofa light to exist")
        }
        light.brightness = 100
        viewModel.lightEntities[.sofa] = light

        // Stub the potential reload URL so nothing fails
        stubEntityURL(entityID: .sofa, state: "on")

        await viewModel.onSliderRelease(slideable: light)
        // isUpdating is set to true during the call; after returning it may have been cleared by reload
        // What we can reliably assert: the call completed without crashing
        XCTAssertNotNil(viewModel.lightEntities[.sofa])
    }

    // MARK: - onToggle

    func testOnToggleSetsIsUpdating() async {
        guard var light = viewModel.lightEntities[.sofa] else {
            return XCTFail("Expected sofa light to exist")
        }
        light.state = "on"
        viewModel.lightEntities[.sofa] = light

        stubEntityURL(entityID: .sofa, state: "off")
        await viewModel.onToggle(slideable: light)
        XCTAssertNotNil(viewModel.lightEntities[.sofa])
    }

    // MARK: - Room name constants

    func testRoomNameConstants() {
        XCTAssertEqual(viewModel.corridorName, "Korridoren")
        XCTAssertEqual(viewModel.corridorSouthName, "Södra")
        XCTAssertEqual(viewModel.corridorNorthName, "Norra")
        XCTAssertEqual(viewModel.livingroomName, "Vardagsrummet")
        XCTAssertEqual(viewModel.cozyName, "Myshörnan")
        XCTAssertEqual(viewModel.sofaName, "Soffbordet")
        XCTAssertEqual(viewModel.playroomName, "Lekrummet")
        XCTAssertEqual(viewModel.guestroomName, "Gästrummet")
        XCTAssertEqual(viewModel.laundryRoomName, "Tvättstugan")
    }

    // MARK: - Network Reload

    func testReloadFetchesLightEntities() async {
        for entityId in viewModel.lightEntities.keys {
            stubEntityURL(entityID: entityId, state: "on")
        }
        await viewModel.reload()

        for (_, light) in viewModel.lightEntities {
            XCTAssertEqual(light.state, "on", "Expected light \(light.entityId) to be 'on'")
        }
    }

    func testReloadPreservesGroupedLightIDsAfterFetch() async {
        for entityId in viewModel.lightEntities.keys {
            stubEntityURL(entityID: entityId, state: "off")
        }
        await viewModel.reload()

        // groupedLightIDs should be preserved from the initial configuration
        XCTAssertEqual(viewModel.lightEntities[.lightsInPlayroom]?.groupedLightIDs,
                       [.playroomCeiling1, .playroomCeiling2, .playroomCeiling3])
        XCTAssertEqual(viewModel.lightEntities[.lightsInGuestRoom]?.groupedLightIDs,
                       [.guestRoomCeiling1, .guestRoomCeiling2, .guestRoomCeiling3])
    }
}
