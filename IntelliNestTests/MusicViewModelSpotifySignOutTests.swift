@testable import IntelliNest
import XCTest

/// Covers logging out of Spotify, by hand and when Spotify rejects the stored login.
@MainActor
extension MusicViewModelTests {
    func testDisconnectSpotifyLogsOutAndClearsSpotifyListing() async {
        let stub = StubSpotifyPlaylistService(accountPlaylistItems: [spotifyPlaylist()] + tobiasLibrary())
        let model = makeViewModel(spotify: stub, personalAccounts: [tobiasAccount])
        await model.refreshSpotifyPlaylists()
        XCTAssertFalse(model.favoritePlaylists.isEmpty)
        XCTAssertFalse(model.personalPlaylistSections.isEmpty)

        model.disconnectSpotify()

        XCTAssertEqual(stub.signOutCallCount, 1)
        XCTAssertFalse(model.isSpotifyAuthorized)
        XCTAssertTrue(model.favoritePlaylists.isEmpty)
        XCTAssertTrue(model.personalPlaylistSections.isEmpty)
        XCTAssertFalse(model.hasLoadedSpotifyPlaylists)
        XCTAssertFalse(model.hasSyncedSpotifyFavorites)
    }

    func testLoginAfterDisconnectLoadsTheNewAccount() async {
        let stub = StubSpotifyPlaylistService(accountPlaylistItems: tobiasLibrary())
        let model = makeViewModel(spotify: stub, personalAccounts: [tobiasAccount])
        await model.refreshSpotifyPlaylists()
        model.disconnectSpotify()

        stub.accountPlaylistItems = [spotifyPlaylist()]
        await model.connectSpotify()

        XCTAssertTrue(model.isSpotifyAuthorized)
        XCTAssertEqual(model.favoritePlaylists.map(\.name), ["Lugnt & Skönt"])
        XCTAssertTrue(model.personalPlaylistSections.isEmpty)
    }

    func testRejectedLoginDuringRefreshBringsBackTheLoginPrompt() async {
        let stub = StubSpotifyPlaylistService(accountPlaylistItems: [spotifyPlaylist()])
        let model = makeViewModel(spotify: stub)
        await model.refreshSpotifyPlaylists()
        XCTAssertTrue(model.isSpotifyAuthorized)

        stub.revokesOnFetch = true
        await model.refreshSpotifyPlaylists()

        XCTAssertFalse(model.isSpotifyAuthorized)
        XCTAssertTrue(model.favoritePlaylists.isEmpty)
    }
}
