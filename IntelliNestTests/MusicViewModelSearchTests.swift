@testable import IntelliNest
import XCTest

/// The search behind the music screen's field: when it fires, what it presents,
/// and how the user's own playlists are ranked into the results.
@MainActor
extension MusicViewModelTests {
    // MARK: - Debounced background search

    func testScheduledSearchFetchesWithoutOpeningTheResultsSheet() async {
        // Typing is usually a library filter. The results are warmed in the
        // background so Enter is instant, but the sheet must stay shut.
        stubSearch(json: searchJSON)
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false))
        model.searchText = "brynäs"
        model.scheduleSearch()
        await model.pendingSearchTask?.value

        XCTAssertFalse(model.isShowingSearchResults)
        XCTAssertEqual(model.searchSections.map(\.mediaType), [.track, .playlist])
    }

    func testScheduledSearchIgnoresAQueryTooShortToBeWorthACall() async {
        stubSearch(json: searchJSON)
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false))
        model.searchText = "b"
        model.scheduleSearch()
        await model.pendingSearchTask?.value

        XCTAssertNil(model.pendingSearchTask)
        XCTAssertTrue(model.searchSections.isEmpty)
        XCTAssertFalse(model.hasSearched)
    }

    func testANewKeystrokeCancelsTheSearchQueuedForThePreviousOne() async {
        stubSearch(json: searchJSON)
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false))
        model.searchText = "bry"
        model.scheduleSearch()
        let superseded = model.pendingSearchTask
        model.searchText = "brynäs"
        model.scheduleSearch()

        XCTAssertEqual(superseded?.isCancelled, true)
        await model.pendingSearchTask?.value
        XCTAssertEqual(model.lastCompletedSearchQuery, "brynäs")
    }

    func testABackgroundFailureDoesNotBannerOrCloseAnything() async {
        // A banner thrown mid-keystroke is noise the user can't act on.
        stubSearch(json: "", statusCode: 500)
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false))
        model.searchText = "brynäs"
        model.scheduleSearch()
        await model.pendingSearchTask?.value

        XCTAssertTrue(bannerTitles.isEmpty)
        XCTAssertFalse(model.isShowingSearchResults)
    }

    // MARK: - Explicit search

    func testExplicitSearchOpensTheSheetAndReportsFailures() async {
        stubSearch(json: "", statusCode: 500)
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false))
        model.searchText = "brynäs"
        await model.search()

        XCTAssertEqual(bannerTitles, ["Sökningen misslyckades"])
        XCTAssertFalse(model.isShowingSearchResults)
    }

    func testExplicitSearchReusesResultsTheBackgroundSearchAlreadyFetched() async {
        stubSearch(json: searchJSON)
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false))
        model.searchText = "brynäs"
        model.scheduleSearch()
        await model.pendingSearchTask?.value

        // A failing stub proves the second call never reached the network: the
        // warmed results survive it.
        stubSearch(json: "", statusCode: 500)
        await model.search()

        XCTAssertTrue(model.isShowingSearchResults)
        XCTAssertTrue(bannerTitles.isEmpty)
        XCTAssertEqual(model.searchSections.map(\.mediaType), [.track, .playlist])
    }

    func testSearchClearsWhenTheQueryIsEmptied() async {
        stubSearch(json: searchJSON)
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false))
        model.searchText = "brynäs"
        await model.search()
        model.searchText = "  "
        await model.search()

        XCTAssertTrue(model.searchSections.isEmpty)
        XCTAssertFalse(model.hasSearched)
        XCTAssertNil(model.lastCompletedSearchQuery)
    }

    // MARK: - Ranking

    func testOwnPlaylistsArePinnedAboveSpotifysMatches() async {
        stubSearch(json: searchJSON)
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false))
        model.favoritePlaylists = [playlistItem(uri: "spotify://playlist/mine", name: "Brynäs")]
        model.searchText = "brynäs"
        await model.search()

        let playlists = model.searchSections.first { $0.mediaType == .playlist }?.items
        XCTAssertEqual(playlists?.map(\.name), ["Brynäs", "Brynäs IF fanclub"])
    }

    func testAPinnedPlaylistIsNotAlsoListedAsARemoteHit() async {
        // The library copy and the search hit carry different provider uris, so the
        // dedupe has to fall back to the name or the playlist shows up twice.
        stubSearch(json: searchJSON)
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false))
        model.favoritePlaylists = [playlistItem(uri: "library://playlist/7", name: "Brynäs IF fanclub")]
        model.searchText = "brynäs"
        await model.search()

        let playlists = model.searchSections.first { $0.mediaType == .playlist }?.items
        XCTAssertEqual(playlists?.map(\.uri), ["library://playlist/7"])
    }

    func testPinningKeepsTheCanonicalCategoryOrder() async {
        stubSearch(json: searchJSON)
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false))
        model.favoritePlaylists = [playlistItem(uri: "spotify://playlist/mine", name: "Brynäs")]
        model.searchText = "brynäs"
        await model.search()

        XCTAssertEqual(model.searchSections.map(\.mediaType), [.track, .playlist])
    }

    func testResultsAreUntouchedWhenNoOwnPlaylistMatches() async {
        stubSearch(json: searchJSON)
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false))
        model.favoritePlaylists = [playlistItem(uri: "spotify://playlist/mine", name: "Smurfparty 3")]
        model.searchText = "brynäs"
        await model.search()

        let playlists = model.searchSections.first { $0.mediaType == .playlist }?.items
        XCTAssertEqual(playlists?.map(\.name), ["Brynäs IF fanclub"])
    }

    // MARK: - Overview tab

    func testOverviewShowsOnlyTheTopFewOfEachCategory() async {
        stubSearch(json: manyTracksJSON)
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false))
        model.searchText = "brynäs"
        await model.search()

        XCTAssertEqual(model.searchSections.first?.items.count, 5)
        XCTAssertEqual(model.searchOverviewSections.first?.items.count, 3)
        XCTAssertEqual(model.searchOverviewSections.first?.items.map(\.name), ["Låt 1", "Låt 2", "Låt 3"])
    }

    // MARK: - Inline results on the music screen

    func testEnterSearchesStraightAwayWithoutOpeningTheSheet() async {
        stubSearch(json: searchJSON)
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false))
        model.searchText = "brynäs"
        model.scheduleSearch()
        let debounced = model.pendingSearchTask
        await model.searchNow()

        XCTAssertEqual(debounced?.isCancelled, true)
        XCTAssertFalse(model.isShowingSearchResults)
        XCTAssertEqual(model.inlineSearchSections.map(\.mediaType), [.track, .playlist])
    }

    func testInlineResultsLeaveOutPlaylistsAlreadyListedAsLibraryMatches() async {
        stubSearch(json: searchJSON)
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false))
        model.favoritePlaylists = [playlistItem(uri: "library://playlist/7", name: "Brynäs IF fanclub")]
        model.searchText = "brynäs"
        await model.searchNow()

        XCTAssertEqual(model.inlineSearchSections.map(\.mediaType), [.track])
    }

    func testInlineResultsHideAnOlderQuerysHitsBelowTheMinimumLength() async {
        stubSearch(json: searchJSON)
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false))
        model.searchText = "brynäs"
        await model.searchNow()
        model.searchText = "b"

        XCTAssertFalse(model.searchSections.isEmpty)
        XCTAssertTrue(model.inlineSearchSections.isEmpty)
    }

    // MARK: - Fixtures

    private var searchJSON: String {
        """
        {"service_response":{
          "tracks":[{"uri":"spotify://track/t1","name":"Vi är Brynäs","artists":[{"name":"Kören"}]}],
          "playlists":[{"uri":"spotify://playlist/remote","name":"Brynäs IF fanclub"}]
        }}
        """
    }

    private var manyTracksJSON: String {
        let tracks = (1 ... 5).map { #"{"uri":"spotify://track/t\#($0)","name":"Låt \#($0)"}"# }
        return #"{"service_response":{"tracks":[\#(tracks.joined(separator: ","))]}}"#
    }
}
