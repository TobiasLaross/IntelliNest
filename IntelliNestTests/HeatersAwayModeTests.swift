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

    private func stubAwayServices(failing failingPath: String? = nil) -> RequestRecorder {
        for path in ["/api/services/input_datetime/set_datetime", "/api/services/input_boolean/turn_on",
                     "/api/services/input_boolean/turn_off"] {
            var components = URLComponents(string: GlobalConstants.baseInternalUrlString)
            components?.path = path
            guard let url = components?.url,
                  let response = HTTPURLResponse(url: url, statusCode: path == failingPath ? 500 : 200,
                                                 httpVersion: nil, headerFields: nil) else {
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

    func testStartingAwayModeWritesTheReturnBeforeTurningOn() async {
        let recorder = stubAwayServices()
        let returnDate = HeatersAwayMode.returnDate(daysFromNow: 7, now: awayNow)

        viewModel.startAwayMode(returnDate: returnDate)
        await viewModel.pendingAwayModeTask?.value

        XCTAssertEqual(postedServices(recorder.requests), ["input_datetime/set_datetime", "input_boolean/turn_on"],
                       "the return time must be in HA before the automation sees the mode turn on")
        XCTAssertTrue(viewModel.heatersAwayMode.isActive)
        XCTAssertEqual(viewModel.heatersAwayReturn.date, returnDate)
    }

    func testStartingAwayModeStaysOffWhenTheReturnWriteFails() async {
        let recorder = stubAwayServices(failing: "/api/services/input_datetime/set_datetime")
        viewModel.reload(entityID: .heatersAwayReturn, state: "2026-11-23 00:00:00")

        viewModel.startAwayMode(returnDate: HeatersAwayMode.returnDate(daysFromNow: 7, now: awayNow))
        await viewModel.pendingAwayModeTask?.value

        XCTAssertFalse(postedServices(recorder.requests).contains("input_boolean/turn_on"),
                       "a stale return time in HA would make the automation restore the heaters at once")
        XCTAssertFalse(viewModel.heatersAwayMode.isActive)
        XCTAssertEqual(viewModel.heatersAwayReturn.state, "2026-11-23 00:00:00")
    }

    func testEndingRightAfterStartingSendsTurnOffLast() async {
        let recorder = stubAwayServices()

        viewModel.startAwayMode(returnDate: HeatersAwayMode.returnDate(daysFromNow: 2, now: awayNow))
        viewModel.endAwayMode()
        await viewModel.pendingAwayModeTask?.value

        XCTAssertEqual(postedServices(recorder.requests),
                       ["input_datetime/set_datetime", "input_boolean/turn_on", "input_boolean/turn_off"])
        XCTAssertFalse(viewModel.heatersAwayMode.isActive)
    }

    func testEndingAwayModeTurnsTheHelperOff() async {
        let recorder = stubAwayServices()
        viewModel.reload(entityID: .heatersAwayMode, state: "on")

        viewModel.endAwayMode()
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

    func testPresetReturnDatesAreThatManyDaysAheadAtFourPM() {
        let calendar = Calendar.current
        for days in HeatersAwayMode.presetDays {
            let returnDate = HeatersAwayMode.returnDate(daysFromNow: days, now: awayNow, calendar: calendar)
            XCTAssertEqual(calendar.dateComponents([.day], from: calendar.startOfDay(for: awayNow),
                                                   to: calendar.startOfDay(for: returnDate)).day, days)
            XCTAssertEqual(calendar.component(.hour, from: returnDate), 16)
        }
    }

    func testPresetTitles() {
        XCTAssertEqual(HeatersAwayMode.presetDays.map(HeatersAwayMode.presetTitle), ["2 dagar", "1 vecka", "2 veckor"])
    }

    func testBadgeCountsDaysThenHoursAndDisappearsAfterReturn() {
        let hour: TimeInterval = 3600
        let cases: [(remaining: TimeInterval, badge: String?)] = [
            (6 * 24 * hour, "6 d"), (5 * 24 * hour + hour, "6 d"), (24 * hour, "1 d"),
            (23 * hour + 1, "24 h"), (hour / 2, "1 h"), (0, nil), (-hour, nil)
        ]
        for testCase in cases {
            XCTAssertEqual(HeatersAwayMode.badge(returnDate: awayNow.addingTimeInterval(testCase.remaining), now: awayNow),
                           testCase.badge, "remaining \(testCase.remaining)")
        }
    }
}
