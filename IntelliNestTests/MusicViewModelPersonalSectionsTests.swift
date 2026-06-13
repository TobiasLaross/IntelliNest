@testable import IntelliNest
import XCTest

@MainActor
extension MusicViewModelTests {
    // MARK: - Personal account playlist sections

    func testPersonalSectionAppearsWhenLoggedInWithPlaylists() async {
        // Personal sections are sourced from the huset library, matched by ownerID.
        let library = [playlistItem(uri: "spotify://playlist/p1", name: "Träning", ownerID: "tobiasc91"),
                       playlistItem(uri: "spotify://playlist/p2", name: "Lugnt & skönt", ownerID: "tobiasc91")]
        let stub = StubSpotifyPlaylistService(accountPlaylistItems: library)
        let model = makeViewModel(spotify: stub, personalAccounts: [tobiasAccount])
        await model.refreshSpotifyPlaylists()
        XCTAssertEqual(model.personalPlaylistSections.count, 1)
        XCTAssertEqual(model.personalPlaylistSections.first?.title, "Tobias spellistor")
        // Order is preserved exactly as returned — no client-side re-sorting.
        XCTAssertEqual(model.personalPlaylistSections.first?.playlists.map(\.name), ["Träning", "Lugnt & skönt"])
    }

    func testPersonalOwnedPlaylistsExcludedFromFavourites() async {
        // A huset-owned playlist stays in Favoriter; a personal-account-owned one
        // moves to that person's section so it never shows in both.
        let library = [playlistItem(uri: "spotify://playlist/h1", name: "Husets", ownerID: "huset"),
                       playlistItem(uri: "spotify://playlist/p1", name: "Träning", ownerID: "tobiasc91")]
        let stub = StubSpotifyPlaylistService(accountPlaylistItems: library)
        let model = makeViewModel(spotify: stub, personalAccounts: [tobiasAccount])
        await model.refreshSpotifyPlaylists()
        XCTAssertEqual(model.favoritePlaylists.map(\.name), ["Husets"])
        XCTAssertEqual(model.personalPlaylistSections.first?.playlists.map(\.name), ["Träning"])
    }

    func testPersonalSectionLoadsViaReload() async {
        let stub = StubSpotifyPlaylistService(accountPlaylistItems: tobiasLibrary())
        let model = makeViewModel(spotify: stub, personalAccounts: [tobiasAccount])
        stubAllSpeakers(playing: .mediaPlayerKitchen)
        XCTAssertTrue(model.personalPlaylistSections.isEmpty)
        await model.reload()
        XCTAssertEqual(model.personalPlaylistSections.map(\.title), ["Tobias spellistor"])
    }

    func testPersonalSectionHiddenWhenAccountOwnsNoLibraryPlaylists() async {
        // The library has playlists, but none owned by Tobias → no Tobias section.
        let stub = StubSpotifyPlaylistService(accountPlaylistItems: [
            playlistItem(uri: "spotify://playlist/h1", name: "Husets", ownerID: "huset")
        ])
        let model = makeViewModel(spotify: stub, personalAccounts: [tobiasAccount])
        await model.refreshSpotifyPlaylists()
        XCTAssertTrue(model.personalPlaylistSections.isEmpty)
    }

    func testPersonalSectionHiddenWhenLoggedOut() async {
        let stub = StubSpotifyPlaylistService(authorized: false, accountPlaylistItems: tobiasLibrary())
        let model = makeViewModel(spotify: stub, personalAccounts: [tobiasAccount])
        await model.refreshSpotifyPlaylists()
        XCTAssertTrue(model.personalPlaylistSections.isEmpty)
        XCTAssertEqual(stub.accountPlaylistsCallCount, 0)
    }

    func testPersonalSectionsClearedWhenSessionBecomesLoggedOut() async {
        let stub = StubSpotifyPlaylistService(accountPlaylistItems: tobiasLibrary())
        let model = makeViewModel(spotify: stub, personalAccounts: [tobiasAccount])
        await model.refreshSpotifyPlaylists()
        XCTAssertEqual(model.personalPlaylistSections.count, 1)
        // The session is lost; a refresh now clears the sections so they disappear.
        stub.authorized = false
        await model.refreshSpotifyPlaylists()
        XCTAssertTrue(model.personalPlaylistSections.isEmpty)
    }

    func testMultipleAccountsEachGetASectionInConfiguredOrder() async {
        let stub = StubSpotifyPlaylistService(accountPlaylistItems: [
            playlistItem(uri: "spotify://playlist/p1", name: "Träning", ownerID: "tobiasc91"),
            playlistItem(uri: "spotify://playlist/p2", name: "Sarahs mix", ownerID: "sarahtest42")
        ])
        let model = makeViewModel(spotify: stub, personalAccounts: [tobiasAccount, sarahAccount])
        await model.refreshSpotifyPlaylists()
        XCTAssertEqual(model.personalPlaylistSections.map(\.title), ["Tobias spellistor", "Sarahs spellistor"])
    }

    func testEmptyAccountDroppedWhileOthersRemain() async {
        let stub = StubSpotifyPlaylistService(accountPlaylistItems: [
            playlistItem(uri: "spotify://playlist/p2", name: "Sarahs mix", ownerID: "sarahtest42")
        ])
        let model = makeViewModel(spotify: stub, personalAccounts: [tobiasAccount, sarahAccount])
        await model.refreshSpotifyPlaylists()
        // Tobias owns nothing in the library → dropped; only Sarah's section shows.
        XCTAssertEqual(model.personalPlaylistSections.map(\.title), ["Sarahs spellistor"])
    }

    func testPersonalSectionRefreshReflectsLatestPlaylists() async {
        let stub = StubSpotifyPlaylistService(accountPlaylistItems: tobiasLibrary())
        let model = makeViewModel(spotify: stub, personalAccounts: [tobiasAccount])
        await model.refreshSpotifyPlaylists()
        XCTAssertEqual(model.personalPlaylistSections.first?.playlists.map(\.name), ["Träning"])
        // Renamed/changed on Spotify; a refresh reflects it with no stale cache.
        stub.accountPlaylistItems = [playlistItem(uri: "spotify://playlist/p3", name: "Ny spellista", ownerID: "tobiasc91")]
        await model.refreshSpotifyPlaylists()
        XCTAssertEqual(model.personalPlaylistSections.first?.playlists.map(\.name), ["Ny spellista"])
    }

    func testConnectSpotifyLoadsPersonalSections() async {
        let stub = StubSpotifyPlaylistService(authorized: false, accountPlaylistItems: tobiasLibrary())
        let model = makeViewModel(spotify: stub, personalAccounts: [tobiasAccount])
        await model.connectSpotify()
        XCTAssertEqual(model.personalPlaylistSections.map(\.title), ["Tobias spellistor"])
    }

    func testTappingPersonalPlaylistRoutesThroughBrowseFlow() async {
        let playlist = playlistItem(uri: "spotify://playlist/p1", name: "Träning", ownerID: "tobiasc91")
        let stub = StubSpotifyPlaylistService(accountPlaylistItems: [playlist])
        let model = makeViewModel(spotify: stub, personalAccounts: [tobiasAccount])
        model.selectSpeaker(.mediaPlayerKitchen)
        await model.refreshSpotifyPlaylists()
        // Tapping a personal playlist uses the same browse flow as a favourite.
        await model.browseLibraryPlaylist(model.personalPlaylistSections.first!.playlists.first!)
        XCTAssertEqual(model.browsingLibraryPlaylist?.uri, playlist.uri)
    }

    func testDefaultPersonalAccountsConfiguresTobiasThenSarah() {
        XCTAssertEqual(SpotifyPersonalAccount.configured.map(\.userID), ["tobiasc91", "mbostroem"])
        XCTAssertEqual(SpotifyPersonalAccount.configured.map(\.user), [.tobias, .sarah])
    }

    func testViewerOwnSectionIsFirstAndTitledByName() async {
        let library = [playlistItem(uri: "spotify://playlist/p1", name: "Tobias lista", ownerID: "tobiasc91"),
                       playlistItem(uri: "spotify://playlist/p2", name: "Sarahs lista", ownerID: "sarahtest42")]
        let stub = StubSpotifyPlaylistService(accountPlaylistItems: library)
        // Sarah is the viewer → her section is first, titled by her own name;
        // Tobias's drops below, also titled by his name.
        let model = makeViewModel(spotify: stub, personalAccounts: [tobiasAccount, sarahAccount], currentUser: { .sarah })
        await model.refreshSpotifyPlaylists()
        XCTAssertEqual(model.personalPlaylistSections.map(\.title), ["Sarahs spellistor", "Tobias spellistor"])
        XCTAssertEqual(model.personalPlaylistSections.first?.account.userID, "sarahtest42")
    }
}
