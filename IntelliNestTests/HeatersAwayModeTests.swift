@testable import IntelliNest
import XCTest

@MainActor
final class HeatersAwayModeTests: XCTestCase {
    var viewModel: HeatersViewModel!
    var restAPIService: RestAPIService!

    override func setUp() async throws {
        URLProtocolStub.startInterceptingRequests()
        let stubbedSession = URLProtocolStub.createStubbedURLSession()
        let urlCreator = URLCreator(session: stubbedSession)
        urlCreator.connectionState = .local
        restAPIService = RestAPIService(urlCreator: urlCreator,
                                        session: stubbedSession,
                                        setErrorBannerText: { _, _ in },
                                        repeatReloadAction: { _ in })
        viewModel = HeatersViewModel(restAPIService: restAPIService, showHeaterDetails: { _ in })
    }

    override func tearDown() async throws {
        URLProtocolStub.stopInterceptingRequests()
        viewModel = nil
        restAPIService = nil
    }

    func testReloadUpdatesTheAwayModeEntities() {
        viewModel.reload(entityID: .heatersAwayMode, state: "on")
        viewModel.reload(entityID: .heatersAwayReturn, state: "2026-12-10 18:00:00")
        XCTAssertTrue(viewModel.heatersAwayMode.isActive)
        XCTAssertEqual(viewModel.heatersAwayReturn.state, "2026-12-10 18:00:00")
    }

    private let awayNow = Date(timeIntervalSince1970: 1_795_420_800) // 2026-11-23

    private func stubAwayServices() -> RequestRecorder {
        for path in ["/api/services/input_datetime/set_datetime", "/api/services/input_boolean/turn_on",
                     "/api/services/input_boolean/turn_off"] {
            var components = URLComponents(string: GlobalConstants.baseInternalUrlString)
            components?.path = path
            guard let url = components?.url,
                  let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil) else {
                XCTFail("Could not build stub for \(path)")
                continue
            }
            URLProtocolStub.setStub(for: url, data: Data(), response: response, error: nil)
        }
        return RequestRecorder { $0.httpMethod == "POST" }
    }

    private func postedServices(_ requests: [URLRequest]) -> [String] {
        requests.compactMap { $0.url?.path.replacingOccurrences(of: "/api/services/", with: "") }
    }

    func testEnablingAwayModeWithAStaleReturnWritesADefaultReturnBeforeTurningOn() async {
        let recorder = stubAwayServices()
        viewModel.reload(entityID: .heatersAwayReturn, state: "2026-11-23 00:00:00")

        viewModel.setAwayMode(true, now: awayNow)
        await viewModel.pendingAwayModeTask?.value

        XCTAssertEqual(postedServices(recorder.requests), ["input_datetime/set_datetime", "input_boolean/turn_on"],
                       "the return time must be in HA before the automation sees the mode turn on")
        XCTAssertTrue(viewModel.heatersAwayMode.isActive)
        XCTAssertEqual(viewModel.heatersAwayReturn.date, HeatersAwayMode.defaultReturnDate(now: awayNow))
    }

    func testEnablingAwayModeKeepsAReturnMoreThanADayAhead() async {
        let recorder = stubAwayServices()
        let returnState = HeatersAwayMode.stateString(for: awayNow.addingTimeInterval(3 * 24 * 60 * 60))
        viewModel.reload(entityID: .heatersAwayReturn, state: returnState)

        viewModel.setAwayMode(true, now: awayNow)
        await viewModel.pendingAwayModeTask?.value

        XCTAssertEqual(postedServices(recorder.requests), ["input_boolean/turn_on"])
        XCTAssertEqual(viewModel.heatersAwayReturn.state, returnState)
    }

    func testDisablingAwayModeTurnsTheHelperOff() async {
        let recorder = stubAwayServices()
        viewModel.reload(entityID: .heatersAwayMode, state: "on")

        viewModel.setAwayMode(false, now: awayNow)
        await viewModel.pendingAwayModeTask?.value

        XCTAssertEqual(postedServices(recorder.requests), ["input_boolean/turn_off"])
        XCTAssertFalse(viewModel.heatersAwayMode.isActive)
    }

    func testSettingTheReturnDateUpdatesItOptimisticallyAndPostsIt() async {
        let recorder = stubAwayServices()
        let returnDate = awayNow.addingTimeInterval(5 * 24 * 60 * 60)

        viewModel.setAwayReturn(returnDate)
        await viewModel.pendingAwayModeTask?.value

        XCTAssertEqual(postedServices(recorder.requests), ["input_datetime/set_datetime"])
        XCTAssertEqual(viewModel.heatersAwayReturn.date, returnDate)
    }

    func testAwayModeRestoresADayBeforeReturn() {
        let returnDate = awayNow.addingTimeInterval(7 * 24 * 60 * 60)
        XCTAssertEqual(HeatersAwayMode.restoreAt(returnDate: returnDate), awayNow.addingTimeInterval(6 * 24 * 60 * 60))
    }

    func testDefaultReturnIsAWeekAheadAtFourPM() {
        let calendar = Calendar.current
        let returnDate = HeatersAwayMode.defaultReturnDate(now: awayNow, calendar: calendar)
        XCTAssertEqual(calendar.dateComponents([.day], from: calendar.startOfDay(for: awayNow),
                                               to: calendar.startOfDay(for: returnDate)).day, 7)
        XCTAssertEqual(calendar.component(.hour, from: returnDate), 16)
    }
}
