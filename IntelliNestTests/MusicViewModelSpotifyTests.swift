@testable import IntelliNest
import XCTest

/// A Spotify stub that records calls and tracks saved ids in memory, so the view
/// model's account-playlist load and optimistic toggle/revert logic can be tested
/// without Spotify.
@MainActor
final class StubSpotifyPlaylistService: SpotifyPlaylistService {
    var authorized: Bool
    var savedIDs: Set<String>
    var operationSucceeds: Bool
    var authorizeThrows: Bool
    var accountPlaylistItems: [MusicSearchItem]
    private(set) var authorizeCallCount = 0
    private(set) var saveCallCount = 0
    private(set) var removeCallCount = 0
    private(set) var accountPlaylistsCallCount = 0

    init(authorized: Bool = true,
         savedIDs: Set<String> = [],
         operationSucceeds: Bool = true,
         authorizeThrows: Bool = false,
         accountPlaylistItems: [MusicSearchItem] = []) {
        self.authorized = authorized
        self.savedIDs = savedIDs
        self.operationSucceeds = operationSucceeds
        self.authorizeThrows = authorizeThrows
        self.accountPlaylistItems = accountPlaylistItems
    }

    var isAuthorized: Bool { authorized }

    func authorize() async throws {
        authorizeCallCount += 1
        if authorizeThrows {
            throw SpotifyAuthError.notAuthorized
        }
        authorized = true
    }

    func accountPlaylists() async -> [MusicSearchItem] {
        accountPlaylistsCallCount += 1
        return accountPlaylistItems
    }

    func isPlaylistSaved(playlistID: String) async -> Bool {
        savedIDs.contains(playlistID)
    }

    func savePlaylist(playlistID: String) async -> Bool {
        saveCallCount += 1
        if operationSucceeds {
            savedIDs.insert(playlistID)
        }
        return operationSucceeds
    }

    func removePlaylist(playlistID: String) async -> Bool {
        removeCallCount += 1
        if operationSucceeds {
            savedIDs.remove(playlistID)
        }
        return operationSucceeds
    }
}

/// Covers the Spotify favourite toggle and shuffled-play paths on the music view
/// model. Lives in its own file as an extension on `MusicViewModelTests` so it
/// reuses that case's stubbed REST/speaker setup without duplicating scaffolding.
@MainActor
extension MusicViewModelTests {
    var spotifyPlaylistID: String { "37i9dQZF1DXcBWIGoYBM5M" }

    func spotifyPlaylist() -> MusicSearchItem {
        MusicSearchItem(uri: "spotify://playlist/\(spotifyPlaylistID)",
                        name: "Lugnt & Skönt", mediaType: .playlist, imageURL: nil, artist: nil)
    }

    func makeViewModel(spotify: SpotifyPlaylistService) -> MusicViewModel {
        MusicViewModel(restAPIService: restAPIService,
                       setErrorBannerText: { [weak self] title, _ in self?.bannerTitles.append(title) },
                       spotify: spotify)
    }

    func testIsSpotifyPlaylistDistinguishesProvider() {
        let spotifyItem = spotifyPlaylist()
        let localItem = MusicSearchItem(uri: "library://playlist/3", name: "Lokal",
                                        mediaType: .playlist, imageURL: nil, artist: nil)
        XCTAssertTrue(viewModel.isSpotifyPlaylist(spotifyItem))
        XCTAssertFalse(viewModel.isSpotifyPlaylist(localItem))
    }

    func testLoadSavedStateReflectsLibrary() async {
        let stub = StubSpotifyPlaylistService(savedIDs: [spotifyPlaylistID])
        let model = makeViewModel(spotify: stub)
        await model.loadSavedState(for: spotifyPlaylist())
        XCTAssertTrue(model.isSaved(spotifyPlaylist()))
    }

    func testToggleSavesWhenNotSaved() async {
        let stub = StubSpotifyPlaylistService()
        let model = makeViewModel(spotify: stub)
        await model.toggleSpotifySaved(spotifyPlaylist())
        XCTAssertTrue(model.isSaved(spotifyPlaylist()))
        XCTAssertEqual(stub.saveCallCount, 1)
    }

    func testToggleRemovesWhenSaved() async {
        let stub = StubSpotifyPlaylistService(savedIDs: [spotifyPlaylistID])
        let model = makeViewModel(spotify: stub)
        await model.loadSavedState(for: spotifyPlaylist())
        await model.toggleSpotifySaved(spotifyPlaylist())
        XCTAssertFalse(model.isSaved(spotifyPlaylist()))
        XCTAssertEqual(stub.removeCallCount, 1)
    }

    func testToggleFailureRevertsAndBanners() async {
        let stub = StubSpotifyPlaylistService(operationSucceeds: false)
        let model = makeViewModel(spotify: stub)
        await model.toggleSpotifySaved(spotifyPlaylist())
        XCTAssertFalse(model.isSaved(spotifyPlaylist()))
        XCTAssertTrue(bannerTitles.contains("Kunde inte uppdatera favorit"))
    }

    func testToggleLogsInWhenUnauthorized() async {
        let stub = StubSpotifyPlaylistService(authorized: false)
        let model = makeViewModel(spotify: stub)
        await model.toggleSpotifySaved(spotifyPlaylist())
        XCTAssertEqual(stub.authorizeCallCount, 1)
        XCTAssertTrue(model.isSaved(spotifyPlaylist()))
    }

    func testToggleAuthorizeFailureBanners() async {
        let stub = StubSpotifyPlaylistService(authorized: false, authorizeThrows: true)
        let model = makeViewModel(spotify: stub)
        await model.toggleSpotifySaved(spotifyPlaylist())
        XCTAssertEqual(stub.saveCallCount, 0)
        XCTAssertFalse(model.isSaved(spotifyPlaylist()))
        XCTAssertTrue(bannerTitles.contains("Spotify-inloggning misslyckades"))
    }

    func testToggleIgnoresNonSpotifyPlaylist() async {
        let stub = StubSpotifyPlaylistService()
        let model = makeViewModel(spotify: stub)
        let localItem = MusicSearchItem(uri: "library://playlist/3", name: "Lokal",
                                        mediaType: .playlist, imageURL: nil, artist: nil)
        await model.toggleSpotifySaved(localItem)
        XCTAssertEqual(stub.saveCallCount, 0)
        XCTAssertTrue(model.savedPlaylistURIs.isEmpty)
    }

    func testSpotifyAccountPlaylistsLoadIntoFavoritesOnReload() async {
        let accountPlaylists = [
            MusicSearchItem(uri: "spotify://playlist/a", name: "Morgon", mediaType: .playlist, imageURL: nil, artist: "huset"),
            MusicSearchItem(uri: "spotify://playlist/b", name: "Träning", mediaType: .playlist, imageURL: nil, artist: "huset")
        ]
        let stub = StubSpotifyPlaylistService(accountPlaylistItems: accountPlaylists)
        let model = makeViewModel(spotify: stub)
        stubAllSpeakers(playing: .mediaPlayerKitchen)
        await model.reload()
        XCTAssertEqual(model.favoritePlaylists.map(\.name), ["Morgon", "Träning"])
    }

    func testSpotifyAccountPlaylistsNotLoadedWhenUnauthorized() async {
        let item = MusicSearchItem(uri: "spotify://playlist/a", name: "Morgon",
                                   mediaType: .playlist, imageURL: nil, artist: nil)
        let stub = StubSpotifyPlaylistService(authorized: false, accountPlaylistItems: [item])
        let model = makeViewModel(spotify: stub)
        stubAllSpeakers(playing: .mediaPlayerKitchen)
        await model.reload()
        XCTAssertTrue(model.favoritePlaylists.isEmpty)
        XCTAssertEqual(stub.accountPlaylistsCallCount, 0)
    }

    func testRefreshSpotifyPlaylistsReflectsLatestLibrary() async {
        let stub = StubSpotifyPlaylistService(accountPlaylistItems: [
            MusicSearchItem(uri: "spotify://playlist/a", name: "En", mediaType: .playlist, imageURL: nil, artist: nil)
        ])
        let model = makeViewModel(spotify: stub)
        await model.refreshSpotifyPlaylists()
        XCTAssertEqual(model.favoritePlaylists.map(\.name), ["En"])
        // The library changes on Spotify; a refresh reflects it (no stale cache),
        // even though the list was already loaded once.
        stub.accountPlaylistItems = [
            MusicSearchItem(uri: "spotify://playlist/b", name: "Två", mediaType: .playlist, imageURL: nil, artist: nil)
        ]
        await model.refreshSpotifyPlaylists()
        XCTAssertEqual(model.favoritePlaylists.map(\.name), ["Två"])
    }

    func testRefreshSpotifyPlaylistsSkippedWhenLoggedOut() async {
        let item = MusicSearchItem(uri: "spotify://playlist/a", name: "En",
                                   mediaType: .playlist, imageURL: nil, artist: nil)
        let stub = StubSpotifyPlaylistService(authorized: false, accountPlaylistItems: [item])
        let model = makeViewModel(spotify: stub)
        await model.refreshSpotifyPlaylists()
        XCTAssertTrue(model.favoritePlaylists.isEmpty)
        XCTAssertEqual(stub.accountPlaylistsCallCount, 0)
    }

    func testToggleRefreshesAccountPlaylists() async {
        let item = MusicSearchItem(uri: "spotify://playlist/x", name: "Ny",
                                   mediaType: .playlist, imageURL: nil, artist: nil)
        let stub = StubSpotifyPlaylistService(accountPlaylistItems: [item])
        let model = makeViewModel(spotify: stub)
        await model.toggleSpotifySaved(spotifyPlaylist())
        XCTAssertEqual(model.favoritePlaylists.map(\.name), ["Ny"])
        XCTAssertGreaterThanOrEqual(stub.accountPlaylistsCallCount, 1)
    }

    func testPlayPlaylistShuffledStartsPlaybackAndEnablesShuffle() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        viewModel.speakers[.mediaPlayerKitchen]?.shuffle = false
        stubPlayMedia(statusCode: 200)
        stubPostService(path: "/api/services/media_player/shuffle_set")
        await viewModel.playPlaylistShuffled(spotifyPlaylist())
        XCTAssertEqual(viewModel.speakers[.mediaPlayerKitchen]?.state, "playing")
        XCTAssertEqual(viewModel.speakers[.mediaPlayerKitchen]?.shuffle, true)
    }
}
