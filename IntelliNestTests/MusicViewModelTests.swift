@testable import IntelliNest
import XCTest

@MainActor
class MusicViewModelTests: XCTestCase {
    var viewModel: MusicViewModel!
    var restAPIService: RestAPIService!
    var urlCreator: URLCreator!
    var bannerTitles: [String] = []
    /// In-memory backing for the last-used-speaker persistence so tests stay
    /// deterministic instead of touching shared `UserDefaults`.
    var storedLastSpeaker: EntityId?

    // Fixed, grep-searchable literals — no random data.
    let trackURI = "spotify://track/3SjXx3rbNGk8nCho8YEoz5"
    let trackName = "Bohemian Rhapsody"
    let trackArtist = "Queen"

    override func setUp() async throws {
        bannerTitles = []
        storedLastSpeaker = nil
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
                                   },
                                   loadLastSpeaker: { [weak self] in self?.storedLastSpeaker },
                                   saveLastSpeaker: { [weak self] in self?.storedLastSpeaker = $0 })
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
                     album: String? = nil,
                     contentID: String? = nil,
                     entityPicture: String? = nil,
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
        if let album { attributes["media_album_name"] = album }
        if let contentID { attributes["media_content_id"] = contentID }
        if let entityPicture { attributes["entity_picture"] = entityPicture }
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

    func testSelectSpeakerPersistsLastUsed() {
        viewModel.selectSpeaker(.mediaPlayerSpa)
        XCTAssertEqual(storedLastSpeaker, .mediaPlayerSpa)
    }

    func testDefaultActiveSpeaker_picksLastUsedWhenNothingPlaying() async {
        storedLastSpeaker = .mediaPlayerGuestRoom
        stubAllSpeakers(playing: nil)
        await viewModel.reload()
        XCTAssertEqual(viewModel.activeSpeakerID, .mediaPlayerGuestRoom)
    }

    func testDefaultActiveSpeaker_playingWinsOverLastUsed() async {
        storedLastSpeaker = .mediaPlayerGuestRoom
        stubAllSpeakers(playing: .mediaPlayerLivingRoom)
        await viewModel.reload()
        XCTAssertEqual(viewModel.activeSpeakerID, .mediaPlayerLivingRoom)
    }

    func testDefaultActiveSpeaker_ignoresUnavailableLastUsed() async {
        storedLastSpeaker = .mediaPlayerSpa
        stubAllSpeakers(playing: nil, unavailable: [.mediaPlayerSpa])
        await viewModel.reload()
        XCTAssertNil(viewModel.activeSpeakerID)
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
