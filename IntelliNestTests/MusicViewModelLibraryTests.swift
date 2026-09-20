@testable import IntelliNest
import XCTest

/// The music screen's library: how the sections collapse, how the search field
/// filters them, and how a person's own Spotify playlists reach them.
@MainActor
extension MusicViewModelTests {
    // MARK: - Sections

    func testLibrarySectionsSkipEmptyOnes() async {
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false))
        XCTAssertTrue(model.allLibrarySections.isEmpty)

        model.favoritePlaylists = [playlistItem(uri: "spotify://playlist/f1", name: "Husets")]
        XCTAssertEqual(model.allLibrarySections.map(\.title), ["Favoriter"])

        model.recentlyPlayedPlaylists = [playlistItem(uri: "spotify://playlist/r1", name: "Pre hockey")]
        XCTAssertEqual(model.allLibrarySections.map(\.title), ["Senast spelade", "Favoriter"])
    }

    func testSectionCollapsesToFourRowsAndReportsTheRest() {
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false))
        let section = MusicLibrarySection(id: "favorites", title: "Favoriter", playlists: numberedPlaylists(count: 7))
        XCTAssertEqual(model.collapsedPlaylists(in: section).map(\.name), ["Lista 1", "Lista 2", "Lista 3", "Lista 4"])
        XCTAssertEqual(model.hiddenPlaylistCount(in: section), 3)
    }

    func testShortSectionHidesNothing() {
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false))
        let section = MusicLibrarySection(id: "favorites", title: "Favoriter", playlists: numberedPlaylists(count: 2))
        XCTAssertEqual(model.collapsedPlaylists(in: section).count, 2)
        XCTAssertEqual(model.hiddenPlaylistCount(in: section), 0)
    }

    // MARK: - Filtering

    func testFilterNarrowsSectionsAndDropsTheOnesWithoutAMatch() {
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false))
        model.recentlyPlayedPlaylists = [playlistItem(uri: "spotify://playlist/r1", name: "Pre hockey")]
        model.favoritePlaylists = [playlistItem(uri: "spotify://playlist/f1", name: "Lugnt & Skönt"),
                                   playlistItem(uri: "spotify://playlist/f2", name: "Smurfparty 3")]

        model.searchText = "smurf"
        XCTAssertTrue(model.isFilteringLibrary)
        XCTAssertEqual(model.librarySections.map(\.title), ["Favoriter"])
        XCTAssertEqual(model.librarySections.first?.playlists.map(\.name), ["Smurfparty 3"])
    }

    func testFilterIgnoresCaseAndDiacritics() {
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false))
        model.favoritePlaylists = [playlistItem(uri: "spotify://playlist/f1", name: "Lugnt & Skönt")]
        for query in ["lugnt", "SKÖNT", "skont", "Skon"] {
            model.searchText = query
            XCTAssertEqual(model.librarySections.first?.playlists.map(\.name), ["Lugnt & Skönt"],
                           "Expected \"\(query)\" to match Lugnt & Skönt")
        }
    }

    func testFilterShowsEveryMatchRatherThanCollapsingThem() {
        // A collapsed section hides rows behind "Visa alla"; while filtering, hiding
        // a match behind a button is the opposite of what the user asked for.
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false))
        model.favoritePlaylists = numberedPlaylists(count: 7)
        model.searchText = "Lista"
        let section = model.librarySections.first
        XCTAssertEqual(section?.playlists.count, 7)
        XCTAssertEqual(model.collapsedPlaylists(in: section!).count, 7)
        XCTAssertEqual(model.hiddenPlaylistCount(in: section!), 0)
    }

    func testEmptyFilterShowsEverything() {
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false))
        model.favoritePlaylists = numberedPlaylists(count: 3)
        model.searchText = "   "
        XCTAssertFalse(model.isFilteringLibrary)
        XCTAssertEqual(model.librarySections.first?.playlists.count, 3)
    }

    func testMatchingLibraryPlaylistsDedupesAcrossSections() {
        // The same playlist can sit in both Senast spelade and Favoriter; pinning it
        // into the search results twice would be worse than not pinning it at all.
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false))
        let shared = playlistItem(uri: "spotify://playlist/p1", name: "Brynäs")
        model.recentlyPlayedPlaylists = [shared]
        model.favoritePlaylists = [shared, playlistItem(uri: "spotify://playlist/p2", name: "Pre hockey")]
        XCTAssertEqual(model.matchingLibraryPlaylists(query: "bry").map(\.uri), ["spotify://playlist/p1"])
    }

    // MARK: - Personal playlists from a public profile

    func testPersonalSectionIncludesPlaylistsHusetDoesNotFollow() async {
        // The point of the profile read: a playlist Tobias made that the huset
        // account never followed was previously invisible to the app.
        let stub = StubSpotifyPlaylistService(
            accountPlaylistItems: [playlistItem(uri: "spotify://playlist/p1", name: "Träning", ownerID: "tobiasc91")],
            publicPlaylistsByUser: ["tobiasc91": [playlistItem(uri: "spotify://playlist/p2", name: "Pruttkorv", ownerID: "tobiasc91")]]
        )
        let model = makeViewModel(spotify: stub, personalAccounts: [tobiasAccount])
        await model.refreshSpotifyPlaylists()
        XCTAssertEqual(model.personalPlaylistSections.first?.playlists.map(\.name), ["Träning", "Pruttkorv"])
    }

    func testPersonalSectionDoesNotListAPlaylistTwice() async {
        let shared = playlistItem(uri: "spotify://playlist/p1", name: "Träning", ownerID: "tobiasc91")
        let stub = StubSpotifyPlaylistService(accountPlaylistItems: [shared],
                                              publicPlaylistsByUser: ["tobiasc91": [shared]])
        let model = makeViewModel(spotify: stub, personalAccounts: [tobiasAccount])
        await model.refreshSpotifyPlaylists()
        XCTAssertEqual(model.personalPlaylistSections.first?.playlists.map(\.uri), ["spotify://playlist/p1"])
    }

    func testPersonalSectionAppearsFromProfileAloneWhenHusetFollowsNothingOfTheirs() async {
        let stub = StubSpotifyPlaylistService(
            accountPlaylistItems: [playlistItem(uri: "spotify://playlist/h1", name: "Husets", ownerID: "huset")],
            publicPlaylistsByUser: ["tobiasc91": [playlistItem(uri: "spotify://playlist/p1", name: "Träning", ownerID: "tobiasc91")]]
        )
        let model = makeViewModel(spotify: stub, personalAccounts: [tobiasAccount])
        await model.refreshSpotifyPlaylists()
        XCTAssertEqual(model.personalPlaylistSections.map(\.title), ["Tobias spellistor"])
        XCTAssertEqual(model.personalPlaylistSections.first?.playlists.map(\.name), ["Träning"])
    }

    func testRefusedProfileReadLeavesTheLibrarySectionsAlone() async {
        // Spotify refusing `/users/<id>/playlists` must degrade to the old
        // library-derived behaviour, not to an empty section.
        let stub = StubSpotifyPlaylistService(accountPlaylistItems: tobiasLibrary())
        let model = makeViewModel(spotify: stub, personalAccounts: [tobiasAccount])
        await model.refreshSpotifyPlaylists()
        XCTAssertEqual(model.personalPlaylistSections.first?.playlists.map(\.name), ["Träning"])
    }

    func testProfileOnlyPlaylistIsNotAutoFavouritedIntoTheHouseLibrary() async {
        // Showing somebody's playlist must not quietly make the huset account
        // follow it — `syncSpotifyLibraryToMAFavorites` only stars what huset has.
        let socket = StubMusicAssistantQueueSocket()
        let stub = StubSpotifyPlaylistService(
            accountPlaylistItems: [playlistItem(uri: "spotify://playlist/p1", name: "Träning", ownerID: "tobiasc91")],
            publicPlaylistsByUser: ["tobiasc91": [playlistItem(uri: "spotify://playlist/p2", name: "Pruttkorv", ownerID: "tobiasc91")]]
        )
        let model = makeViewModel(spotify: stub, socket: socket, personalAccounts: [tobiasAccount])
        await model.refreshSpotifyPlaylists()
        await model.syncSpotifyLibraryToMAFavorites()
        let added = await socket.addedFavoriteURIs
        XCTAssertEqual(added, ["spotify://playlist/p1"])
    }

    // MARK: - Helpers

    private func numberedPlaylists(count: Int) -> [MusicSearchItem] {
        (1 ... count).map { playlistItem(uri: "spotify://playlist/p\($0)", name: "Lista \($0)") }
    }
}
