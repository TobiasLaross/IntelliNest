@testable import IntelliNest
import XCTest

/// The search behind the music screen's field: when it fires, what it presents,
/// and how the user's own playlists are ranked into the results.
@MainActor
extension MusicViewModelTests {
    func testSpotifyOwnerIsNotShownAsSubtitle() {
        let cases: [(artist: String?, expected: String?)] = [("Spotify", nil), ("spotify", nil), ("Tobias", "Tobias"), (nil, nil)]
        for testCase in cases {
            let item = MusicSearchItem(uri: "spotify://playlist/37i9dQZF1DX0Ew6u9sRtTY", name: "Swedish pop",
                                       mediaType: .playlist, imageURL: nil, artist: testCase.artist)
            XCTAssertEqual(item.artist, testCase.expected)
        }
    }

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

    // MARK: - Mixed results list

    func testAlltTakesTheTypesInTurnsWithLibraryPlaylistsBadged() async {
        stubSearch(json: mixedJSON)
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false))
        model.favoritePlaylists = [playlistItem(uri: "spotify://playlist/mine", name: "Brynäs på soffan")]
        model.searchText = "brynäs"
        await model.searchNow()

        let hits = model.searchHits(filter: nil)
        XCTAssertEqual(hits.map(\.item.uri), [
            "spotify://artist/a1", "spotify://playlist/mine", "spotify://track/t1", "spotify://album/b1",
            "spotify://playlist/remote", "spotify://track/t2"
        ])
        XCTAssertEqual(hits.filter(\.isInLibrary).map(\.item.uri), ["spotify://playlist/mine"])
        XCTAssertEqual(model.searchFilters, [.track, .album, .artist, .playlist])
    }

    func testFilterListsOneTypeInFullWithLibraryPlaylistsFirst() async {
        stubSearch(json: mixedJSON)
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false))
        model.favoritePlaylists = [playlistItem(uri: "spotify://playlist/mine", name: "Brynäs på soffan")]
        model.searchText = "brynäs"
        await model.searchNow()

        let cases: [(filter: MusicMediaType, expected: [String])] = [
            (.track, ["spotify://track/t1", "spotify://track/t2"]),
            (.playlist, ["spotify://playlist/mine", "spotify://playlist/remote"]),
            (.artist, ["spotify://artist/a1"])
        ]
        for testCase in cases {
            XCTAssertEqual(model.searchHits(filter: testCase.filter).map(\.item.uri), testCase.expected,
                           "filter \(testCase.filter)")
        }
    }

    func testTheSameArtistFromTwoProvidersIsListedOnce() async {
        stubSearch(json: """
        {"service_response":{"artists":[
          {"uri":"spotify://artist/a1","name":"Victor Leksell"},
          {"uri":"library://artist/9","name":"victor leksell"},
          {"uri":"spotify://artist/a2","name":"Viktor Norén"}
        ]}}
        """)
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false))
        model.searchText = "victor"
        await model.searchNow()

        XCTAssertEqual(model.searchHits(filter: nil).map(\.item.uri), ["spotify://artist/a1", "spotify://artist/a2"])
    }

    func testLibraryMatchesShowBeforeTheSpotifySearchHasRun() {
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false))
        model.favoritePlaylists = [playlistItem(uri: "spotify://playlist/mine", name: "Brynäs på soffan")]
        model.searchText = "brynäs"

        XCTAssertEqual(model.searchHits(filter: nil).map(\.item.uri), ["spotify://playlist/mine"])
        XCTAssertEqual(model.searchFilters, [.playlist])
    }

    func testOpeningAnArtistOrAlbumBrowsesInsteadOfPlaying() async {
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false))
        for mediaType in [MusicMediaType.artist, .album] {
            let item = MusicSearchItem(uri: "spotify://\(mediaType.rawValue)/x1", name: "Victor",
                                       mediaType: mediaType, imageURL: nil, artist: nil)
            await model.open(item)
            XCTAssertEqual(model.browsingArtist, item)
        }
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

    func testInlineResultsHideAnOlderQuerysHitsUntilTheNewSearchFinishes() async {
        stubSearch(json: searchJSON)
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false))
        model.searchText = "brynäs"
        await model.searchNow()
        model.searchText = "victor"

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

    private var mixedJSON: String {
        """
        {"service_response":{
          "tracks":[{"uri":"spotify://track/t1","name":"Vi är Brynäs"},{"uri":"spotify://track/t2","name":"Brynäs forever"}],
          "albums":[{"uri":"spotify://album/b1","name":"Brynäs"}],
          "artists":[{"uri":"spotify://artist/a1","name":"Brynäskören"}],
          "playlists":[{"uri":"spotify://playlist/remote","name":"Brynäs IF fanclub"}]
        }}
        """
    }
}
