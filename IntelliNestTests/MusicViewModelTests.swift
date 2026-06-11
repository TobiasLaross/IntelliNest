@testable import IntelliNest
import XCTest

@MainActor
class MusicViewModelTests: XCTestCase {
    var viewModel: MusicViewModel!
    var restAPIService: RestAPIService!
    var urlCreator: URLCreator!
    var bannerTitles: [String] = []

    // Fixed, grep-searchable literals — no random data.
    let trackURI = "spotify://track/3SjXx3rbNGk8nCho8YEoz5"
    let trackName = "Bohemian Rhapsody"
    let trackArtist = "Queen"

    override func setUp() async throws {
        bannerTitles = []
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
        viewModel = MusicViewModel(restAPIService: restAPIService,
                                   setErrorBannerText: { [weak self] title, _ in
                                       self?.bannerTitles.append(title)
                                   })
    }

    override func tearDown() async throws {
        URLProtocolStub.stopInterceptingRequests()
        viewModel = nil
        restAPIService = nil
        urlCreator = nil
    }

    // MARK: - Helpers

    func speakerURL(_ entityID: EntityId) -> URL {
        var components = URLComponents(string: GlobalConstants.baseInternalUrlString)!
        components.path = "/api/states/\(entityID.rawValue)"
        return components.url!
    }

    func speakerJSON(entityID: EntityId,
                     state: String,
                     friendlyName: String,
                     volume: Double = 0.3,
                     title: String? = nil,
                     artist: String? = nil,
                     groupMembers: [String] = [],
                     shuffle: Bool = false,
                     repeatMode: String = "off") -> Data {
        var attributes: [String: Any] = [
            "friendly_name": friendlyName,
            "volume_level": volume,
            "group_members": groupMembers,
            "shuffle": shuffle,
            "repeat": repeatMode
        ]
        if let title { attributes["media_title"] = title }
        if let artist { attributes["media_artist"] = artist }
        return makeEntityJSON(entityId: entityID.rawValue, state: state, attributes: attributes)
    }

    func stubSpeaker(_ entityID: EntityId, data: Data) {
        let response = HTTPURLResponse(url: speakerURL(entityID), statusCode: 200, httpVersion: nil, headerFields: nil)!
        URLProtocolStub.setStub(for: speakerURL(entityID), data: data, response: response, error: nil)
    }

    func stubAllSpeakers(playing: EntityId? = nil, unavailable: Set<EntityId> = []) {
        for entityID in MusicViewModel.speakerIDs {
            let state: String = if unavailable.contains(entityID) {
                "unavailable"
            } else if entityID == playing {
                "playing"
            } else {
                "idle"
            }
            stubSpeaker(entityID, data: speakerJSON(entityID: entityID,
                                                    state: state,
                                                    friendlyName: entityID.rawValue))
        }
    }

    func searchURL() -> URL {
        var components = URLComponents(string: GlobalConstants.baseInternalUrlString)!
        components.path = "/api/services/music_assistant/search"
        components.queryItems = [URLQueryItem(name: "return_response", value: "true")]
        return components.url!
    }

    func stubSearch(json: String, statusCode: Int = 200) {
        let url = searchURL()
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        URLProtocolStub.setStub(for: url, data: Data(json.utf8), response: response, error: nil)
    }

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertEqual(viewModel.speakers.count, 6)
        XCTAssertNil(viewModel.activeSpeakerID)
        XCTAssertTrue(viewModel.searchSections.isEmpty)
        XCTAssertFalse(viewModel.hasSearched)
        XCTAssertFalse(viewModel.hasNoResults)
    }

    // MARK: - Default active speaker selection

    func testDefaultActiveSpeaker_picksPlayingSpeaker() async {
        stubAllSpeakers(playing: .mediaPlayerLivingRoom)
        await viewModel.reload()
        XCTAssertEqual(viewModel.activeSpeakerID, .mediaPlayerLivingRoom)
    }

    func testDefaultActiveSpeaker_noneWhenNothingPlaying() async {
        stubAllSpeakers(playing: nil)
        await viewModel.reload()
        XCTAssertNil(viewModel.activeSpeakerID)
    }

    func testDefaultSelection_runsOnlyOnce() async {
        stubAllSpeakers(playing: .mediaPlayerKitchen)
        await viewModel.reload()
        XCTAssertEqual(viewModel.activeSpeakerID, .mediaPlayerKitchen)

        // User switches; a later reload where Kitchen still plays must not override.
        viewModel.selectSpeaker(.mediaPlayerSpa)
        await viewModel.reload()
        XCTAssertEqual(viewModel.activeSpeakerID, .mediaPlayerSpa)
    }

    // MARK: - Unavailable speaker filtering

    func testUnavailableSpeakersFilteredOut() async {
        stubAllSpeakers(playing: nil, unavailable: [.mediaPlayerSpa])
        await viewModel.reload()
        let availableIDs = viewModel.availableSpeakers.map(\.entityId)
        XCTAssertEqual(availableIDs.count, 5)
        XCTAssertFalse(availableIDs.contains(.mediaPlayerSpa))
    }

    func testActiveSpeakerDroppedWhenItBecomesUnavailable() async {
        stubAllSpeakers(playing: .mediaPlayerKitchen)
        await viewModel.reload()
        XCTAssertEqual(viewModel.activeSpeakerID, .mediaPlayerKitchen)

        stubAllSpeakers(playing: nil, unavailable: [.mediaPlayerKitchen])
        await viewModel.reload()
        XCTAssertNil(viewModel.activeSpeakerID)
    }

    // MARK: - Search

    func testSearchGroupsResultsByType() async {
        let json = """
        {"tracks":[{"uri":"\(trackURI)","name":"\(trackName)","image":"https://img/track.jpg",
        "artists":[{"name":"\(trackArtist)"}]}],
        "albums":[{"uri":"spotify://album/1","name":"A Night at the Opera"}],
        "artists":[{"uri":"spotify://artist/1","name":"\(trackArtist)"}],
        "playlists":[{"uri":"spotify://playlist/1","name":"Rock Classics"}]}
        """
        stubSearch(json: json)
        viewModel.searchText = trackName
        await viewModel.search()

        XCTAssertEqual(viewModel.searchSections.count, 4)
        XCTAssertEqual(viewModel.searchSections.map(\.mediaType), [.track, .album, .artist, .playlist])
        let firstTrack = viewModel.searchSections.first?.items.first
        XCTAssertEqual(firstTrack?.uri, trackURI)
        XCTAssertEqual(firstTrack?.name, trackName)
        XCTAssertEqual(firstTrack?.artist, trackArtist)
        XCTAssertFalse(viewModel.hasNoResults)
    }

    func testSearchUnwrapsServiceResponseEnvelope() async {
        let json = """
        {"service_response":{"tracks":[{"uri":"\(trackURI)","name":"\(trackName)"}]}}
        """
        stubSearch(json: json)
        viewModel.searchText = trackName
        await viewModel.search()
        XCTAssertEqual(viewModel.searchSections.count, 1)
        XCTAssertEqual(viewModel.searchSections.first?.items.first?.uri, trackURI)
    }

    func testEmptySearchResultsShowsNoResultsState() async {
        stubSearch(json: "{\"tracks\":[],\"albums\":[]}")
        viewModel.searchText = "zzzznotfound"
        await viewModel.search()
        XCTAssertTrue(viewModel.searchSections.isEmpty)
        XCTAssertTrue(viewModel.hasNoResults)
    }

    func testBlankSearchTextDoesNotSearch() async {
        viewModel.searchText = "   "
        await viewModel.search()
        XCTAssertFalse(viewModel.hasSearched)
        XCTAssertTrue(viewModel.searchSections.isEmpty)
    }

    func testSearchFailureShowsBanner() async {
        stubSearch(json: "boom", statusCode: 500)
        viewModel.searchText = trackName
        await viewModel.search()
        XCTAssertTrue(viewModel.searchSections.isEmpty)
        XCTAssertTrue(bannerTitles.contains("Sökningen misslyckades"))
        // A failure must not look like an empty result, and it closes the sheet.
        XCTAssertFalse(viewModel.hasNoResults)
        XCTAssertFalse(viewModel.isShowingSearchResults)
    }
}

// MARK: - Playback, transport & volume

@MainActor
extension MusicViewModelTests {
    // MARK: - Play

    func stubPlayMedia(statusCode: Int) {
        var components = URLComponents(string: GlobalConstants.baseInternalUrlString)!
        components.path = "/api/services/music_assistant/play_media"
        let url = components.url!
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        URLProtocolStub.setStub(for: url, data: Data("[]".utf8), response: response, error: nil)
    }

    func testPlayOnActiveSpeakerSetsPlayingState() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        stubPlayMedia(statusCode: 200)
        let item = MusicSearchItem(uri: trackURI, name: trackName, mediaType: .track,
                                   imageURL: nil, artist: trackArtist)
        await viewModel.play(item: item)
        XCTAssertEqual(viewModel.speakers[.mediaPlayerKitchen]?.state, "playing")
        XCTAssertEqual(viewModel.speakers[.mediaPlayerKitchen]?.mediaTitle, trackName)
        XCTAssertTrue(bannerTitles.isEmpty)
    }

    func testPlayFailureKeepsNoFalsePlayingState() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        // Kitchen currently idle.
        viewModel.speakers[.mediaPlayerKitchen]?.state = "idle"
        stubPlayMedia(statusCode: 500)
        let item = MusicSearchItem(uri: trackURI, name: trackName, mediaType: .track,
                                   imageURL: nil, artist: trackArtist)
        await viewModel.play(item: item)
        XCTAssertNotEqual(viewModel.speakers[.mediaPlayerKitchen]?.state, "playing")
        XCTAssertTrue(bannerTitles.contains("Kunde inte spela"))
    }

    func testPlayWithoutActiveSpeakerShowsBanner() async {
        let item = MusicSearchItem(uri: trackURI, name: trackName, mediaType: .track,
                                   imageURL: nil, artist: trackArtist)
        await viewModel.play(item: item)
        XCTAssertTrue(bannerTitles.contains("Ingen högtalare vald"))
    }

    // MARK: - Transport

    func testTogglePlayPause_pausesWhenPlaying() async {
        stubAllSpeakers(playing: .mediaPlayerKitchen)
        await viewModel.reload()
        let expectation = XCTestExpectation(description: "POST media_pause")
        URLProtocolStub.observerRequests { request in
            if request.httpMethod == "POST", request.url?.path.contains("/media_pause") == true {
                expectation.fulfill()
            }
        }
        stubPostService(path: "/api/services/media_player/media_pause")
        viewModel.togglePlayPause()
        XCTAssertEqual(viewModel.speakers[.mediaPlayerKitchen]?.state, "paused")
        await fulfillment(of: [expectation], timeout: 2.0)
    }

    func testTogglePlayPause_playsWhenPaused() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        viewModel.speakers[.mediaPlayerKitchen]?.state = "paused"
        let expectation = XCTestExpectation(description: "POST media_play")
        URLProtocolStub.observerRequests { request in
            if request.httpMethod == "POST", request.url?.path.contains("/media_play") == true {
                expectation.fulfill()
            }
        }
        stubPostService(path: "/api/services/media_player/media_play")
        viewModel.togglePlayPause()
        XCTAssertEqual(viewModel.speakers[.mediaPlayerKitchen]?.state, "playing")
        await fulfillment(of: [expectation], timeout: 2.0)
    }

    func testNextAndPreviousTrack() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        let cases: [(action: () -> Void, path: String)] = [
            (viewModel.nextTrack, "/api/services/media_player/media_next_track"),
            (viewModel.previousTrack, "/api/services/media_player/media_previous_track")
        ]
        for testCase in cases {
            let expectation = XCTestExpectation(description: "POST \(testCase.path)")
            URLProtocolStub.observerRequests { request in
                if request.httpMethod == "POST", request.url?.path == testCase.path {
                    expectation.fulfill()
                }
            }
            stubPostService(path: testCase.path)
            testCase.action()
            await fulfillment(of: [expectation], timeout: 2.0)
        }
    }

    func testTransportWithoutActiveSpeakerDoesNothing() {
        // No active speaker; these must be no-ops (no crash).
        viewModel.togglePlayPause()
        viewModel.nextTrack()
        viewModel.previousTrack()
        viewModel.setVolume(0.5)
        viewModel.toggleShuffle()
        viewModel.toggleRepeat()
        XCTAssertNil(viewModel.activeSpeakerID)
    }

    // MARK: - Volume

    func testSetVolumeUpdatesStateAndPosts() async {
        viewModel.selectSpeaker(.mediaPlayerGuestRoom)
        let expectation = XCTestExpectation(description: "POST volume_set")
        URLProtocolStub.observerRequests { request in
            if request.httpMethod == "POST", request.url?.path.contains("/volume_set") == true {
                expectation.fulfill()
            }
        }
        stubPostService(path: "/api/services/media_player/volume_set")
        viewModel.setVolume(0.75)
        XCTAssertEqual(viewModel.speakers[.mediaPlayerGuestRoom]?.volumeLevel, 0.75)
        await fulfillment(of: [expectation], timeout: 2.0)
    }

    func testSetVolumeForSpecificSpeakerAdjustsThatSpeakerWithoutSelecting() async {
        // No active speaker — volume can still be set on any speaker in place.
        let expectation = XCTestExpectation(description: "POST volume_set")
        URLProtocolStub.observerRequests { request in
            if request.httpMethod == "POST", request.url?.path.contains("/volume_set") == true {
                expectation.fulfill()
            }
        }
        stubPostService(path: "/api/services/media_player/volume_set")
        viewModel.setVolume(0.42, for: .mediaPlayerSpa)
        XCTAssertEqual(viewModel.speakers[.mediaPlayerSpa]?.volumeLevel, 0.42)
        XCTAssertNil(viewModel.activeSpeakerID)
        await fulfillment(of: [expectation], timeout: 2.0)
    }

    // MARK: - Shuffle / Repeat

    func testToggleShuffle() async {
        viewModel.selectSpeaker(.mediaPlayerPlayroom)
        viewModel.speakers[.mediaPlayerPlayroom]?.shuffle = false
        let expectation = XCTestExpectation(description: "POST shuffle_set")
        URLProtocolStub.observerRequests { request in
            if request.httpMethod == "POST", request.url?.path.contains("/shuffle_set") == true {
                expectation.fulfill()
            }
        }
        stubPostService(path: "/api/services/media_player/shuffle_set")
        viewModel.toggleShuffle()
        XCTAssertEqual(viewModel.speakers[.mediaPlayerPlayroom]?.shuffle, true)
        await fulfillment(of: [expectation], timeout: 2.0)
    }

    func testToggleRepeatCyclesOffAllOne() async {
        viewModel.selectSpeaker(.mediaPlayerPlayroom)
        stubPostService(path: "/api/services/media_player/repeat_set")

        viewModel.speakers[.mediaPlayerPlayroom]?.repeatMode = .off
        viewModel.toggleRepeat()
        XCTAssertEqual(viewModel.speakers[.mediaPlayerPlayroom]?.repeatMode, .all)
        viewModel.toggleRepeat()
        XCTAssertEqual(viewModel.speakers[.mediaPlayerPlayroom]?.repeatMode, .one)
        viewModel.toggleRepeat()
        XCTAssertEqual(viewModel.speakers[.mediaPlayerPlayroom]?.repeatMode, .off)
    }

    // MARK: - Helpers

    func stubPostService(path: String, statusCode: Int = 200) {
        var components = URLComponents(string: GlobalConstants.baseInternalUrlString)!
        components.path = path
        let url = components.url!
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        URLProtocolStub.setStub(for: url, data: Data(), response: response, error: nil)
    }
}
