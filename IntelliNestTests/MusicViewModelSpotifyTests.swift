@testable import IntelliNest
import XCTest

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

    func makeViewModel(spotify: SpotifyPlaylistService,
                       socket: MusicAssistantQueueSocket = DisabledMusicAssistantQueueSocket(),
                       personalAccounts: [SpotifyPersonalAccount] = SpotifyPersonalAccount.configured,
                       currentUser: @escaping @MainActor @Sendable () -> User = { .tobias },
                       pinnedPlaylistStore: PinnedPlaylistStore = PinnedPlaylistStore(load: { [:] }, save: { _ in }),
                       libraryCache: MusicLibraryCache = .disabled) -> MusicViewModel {
        MusicViewModel(restAPIService: restAPIService,
                       setErrorBannerText: { [weak self] title, _ in self?.bannerTitles.append(title) },
                       spotify: spotify,
                       queueSocket: socket,
                       personalAccounts: personalAccounts,
                       currentUser: currentUser,
                       pinnedPlaylistStore: pinnedPlaylistStore,
                       libraryCache: libraryCache,
                       // No wall-clock wait in tests: a scheduled search runs as soon
                       // as its task is awaited.
                       searchDebounce: {})
    }

    // Fixed personal-account ids — grep-searchable, no random data.
    var tobiasAccount: SpotifyPersonalAccount { SpotifyPersonalAccount(userID: "tobiasc91", user: .tobias) }
    var sarahAccount: SpotifyPersonalAccount { SpotifyPersonalAccount(userID: "sarahtest42", user: .sarah) }

    func playlistItem(uri: String, name: String, ownerID: String? = nil) -> MusicSearchItem {
        MusicSearchItem(uri: uri, name: name, mediaType: .playlist, imageURL: nil, artist: nil, ownerID: ownerID)
    }

    /// The huset library containing a single "Träning" playlist owned by Tobias —
    /// the common single-account fixture. Personal sections are sourced from the
    /// account library filtered by `ownerID`.
    func tobiasLibrary() -> [MusicSearchItem] {
        [playlistItem(uri: "spotify://playlist/p1", name: "Träning", ownerID: "tobiasc91")]
    }

    func testCanFavoriteShownForPlaylistsOnly() {
        let model = makeViewModel(spotify: StubSpotifyPlaylistService())
        XCTAssertTrue(model.canFavoritePlaylist(spotifyPlaylist()))
        let track = MusicSearchItem(uri: "spotify://track/1", name: "Song", mediaType: .track, imageURL: nil, artist: nil)
        XCTAssertFalse(model.canFavoritePlaylist(track))
    }

    func testIsSavedMatchesMusicAssistantFavouriteByName() {
        let model = makeViewModel(spotify: StubSpotifyPlaylistService())
        model.maFavorites = [playlistItem(uri: "library://playlist/1", name: "Träning")]
        // Matched by normalized name across the spotify:// / library:// uri spaces.
        XCTAssertTrue(model.isSaved(playlistItem(uri: "spotify://playlist/x", name: "  träning ")))
        XCTAssertFalse(model.isSaved(playlistItem(uri: "spotify://playlist/y", name: "Annan")))
    }

    func testToggleFavoriteAddsViaSocket() async {
        let socket = StubMusicAssistantQueueSocket()
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(), socket: socket)
        let playlist = spotifyPlaylist()
        await model.toggleFavorite(playlist)
        let added = await socket.addedFavoriteURIs
        XCTAssertEqual(added, [playlist.uri])
        XCTAssertTrue(model.isSaved(playlist)) // optimistic
    }

    func testToggleFavoriteRemovesViaSocketUsingLibraryID() async {
        let socket = StubMusicAssistantQueueSocket()
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(), socket: socket)
        let playlist = playlistItem(uri: "spotify://playlist/x", name: "Lugnt")
        // It's favourited in MA as a library:// item with the same name.
        model.maFavorites = [playlistItem(uri: "library://playlist/42", name: "Lugnt")]
        XCTAssertTrue(model.isSaved(playlist))
        await model.toggleFavorite(playlist)
        let removed = await socket.removedFavorites
        XCTAssertEqual(removed, ["playlist:42"])
        XCTAssertFalse(model.isSaved(playlist)) // optimistic
    }

    func testToggleFavoriteFailureRevertsAndBanners() async {
        let socket = StubMusicAssistantQueueSocket(favoriteSucceeds: false)
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(), socket: socket)
        let playlist = spotifyPlaylist()
        await model.toggleFavorite(playlist)
        XCTAssertFalse(model.isSaved(playlist)) // reverted
        XCTAssertTrue(bannerTitles.contains("Kunde inte uppdatera favorit"))
    }

    func testSyncStarsUnfavoritedSpotifyLibraryInMA() async {
        let socket = StubMusicAssistantQueueSocket()
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(), socket: socket)
        model.favoritePlaylists = [
            playlistItem(uri: "spotify://playlist/a", name: "Svensk sommar"),
            playlistItem(uri: "spotify://playlist/b", name: "Sommarklassiker")
        ]
        // Sommarklassiker is already an MA favourite; only Svensk sommar needs syncing.
        model.maFavorites = [playlistItem(uri: "library://playlist/9", name: "Sommarklassiker")]
        await model.syncSpotifyLibraryToMAFavorites()
        let added = await socket.addedFavoriteURIs
        XCTAssertEqual(added, ["spotify://playlist/a"])
        XCTAssertTrue(model.hasSyncedSpotifyFavorites)
    }

    func testSyncRunsOncePerSession() async {
        let socket = StubMusicAssistantQueueSocket()
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(), socket: socket)
        model.favoritePlaylists = [playlistItem(uri: "spotify://playlist/a", name: "Svensk sommar")]
        await model.syncSpotifyLibraryToMAFavorites()
        // A second run (e.g. after the user unstarred it) must not re-add anything.
        model.favoritePlaylists = [playlistItem(uri: "spotify://playlist/c", name: "Ny lista")]
        await model.syncSpotifyLibraryToMAFavorites()
        let added = await socket.addedFavoriteURIs
        XCTAssertEqual(added, ["spotify://playlist/a"])
    }

    func testSyncSkippedWhenLoggedOut() async {
        let socket = StubMusicAssistantQueueSocket()
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false), socket: socket)
        model.favoritePlaylists = [playlistItem(uri: "spotify://playlist/a", name: "Svensk sommar")]
        await model.syncSpotifyLibraryToMAFavorites()
        let added = await socket.addedFavoriteURIs
        XCTAssertTrue(added.isEmpty)
        // Latch stays open so it can run once the user logs in.
        XCTAssertFalse(model.hasSyncedSpotifyFavorites)
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

    func testIsSpotifyAuthorizedReflectsServiceAtInit() {
        XCTAssertTrue(makeViewModel(spotify: StubSpotifyPlaylistService(authorized: true)).isSpotifyAuthorized)
        XCTAssertFalse(makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false)).isSpotifyAuthorized)
    }

    func testConnectSpotifyLogsInAndLoadsPlaylists() async {
        let item = MusicSearchItem(uri: "spotify://playlist/a", name: "Morgon",
                                   mediaType: .playlist, imageURL: nil, artist: nil)
        let stub = StubSpotifyPlaylistService(authorized: false, accountPlaylistItems: [item])
        let model = makeViewModel(spotify: stub)
        await model.connectSpotify()
        XCTAssertTrue(model.isSpotifyAuthorized)
        XCTAssertEqual(stub.authorizeCallCount, 1)
        XCTAssertEqual(model.favoritePlaylists.map(\.name), ["Morgon"])
    }

    func testConnectSpotifyFailureBannersAndStaysLoggedOut() async {
        let stub = StubSpotifyPlaylistService(authorized: false, authorizeThrows: true)
        let model = makeViewModel(spotify: stub)
        await model.connectSpotify()
        XCTAssertFalse(model.isSpotifyAuthorized)
        XCTAssertTrue(bannerTitles.contains("Spotify-inloggning misslyckades"))
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

    // MARK: - Favourites union with the Music Assistant favourite store

    func testFavoritesUnionWithMusicAssistantFavouriteStore() async {
        struct UnionCase {
            let description: String
            let spotifyLibrary: [MusicSearchItem]
            let maFavorites: [MusicSearchItem]
            let expectedFavorites: [String]
            let expectedPersonal: [String]
        }
        // The huset Spotify library minus the per-person sections, unioned with any
        // MA favourite the library doesn't carry yet (matched by name).
        let cases = [
            UnionCase(description: "MA favourite not yet followed on Spotify surfaces in Favoriter",
                      spotifyLibrary: [playlistItem(uri: "spotify://playlist/h1", name: "Husets", ownerID: "huset")],
                      maFavorites: [playlistItem(uri: "library://playlist/24", name: "Pippi Långstrump - Alla sånger")],
                      expectedFavorites: ["Husets", "Pippi Långstrump - Alla sånger"],
                      expectedPersonal: []),
            UnionCase(description: "MA favourite already in the Spotify library is not duplicated",
                      spotifyLibrary: [playlistItem(uri: "spotify://playlist/h1", name: "Sommarklassiker", ownerID: "huset")],
                      maFavorites: [playlistItem(uri: "library://playlist/21", name: "Sommarklassiker")],
                      expectedFavorites: ["Sommarklassiker"],
                      expectedPersonal: []),
            UnionCase(description: "MA favourite owned by a personal account stays in that section, not Favoriter",
                      spotifyLibrary: [playlistItem(uri: "spotify://playlist/p1", name: "Vigsel Laross 2019", ownerID: "tobiasc91")],
                      maFavorites: [playlistItem(uri: "library://playlist/16", name: "Vigsel Laross 2019")],
                      expectedFavorites: [],
                      expectedPersonal: ["Vigsel Laross 2019"])
        ]
        for unionCase in cases {
            let stub = StubSpotifyPlaylistService(accountPlaylistItems: unionCase.spotifyLibrary)
            let model = makeViewModel(spotify: stub)
            model.maFavorites = unionCase.maFavorites
            await model.refreshSpotifyPlaylists()
            XCTAssertEqual(model.favoritePlaylists.map(\.name), unionCase.expectedFavorites, unionCase.description)
            XCTAssertEqual(model.personalPlaylistSections.flatMap(\.playlists).map(\.name),
                           unionCase.expectedPersonal, unionCase.description)
        }
    }

    func testToggleRefreshesListing() async {
        let item = MusicSearchItem(uri: "spotify://playlist/x", name: "Ny",
                                   mediaType: .playlist, imageURL: nil, artist: nil)
        let stub = StubSpotifyPlaylistService(accountPlaylistItems: [item])
        let model = makeViewModel(spotify: stub, socket: StubMusicAssistantQueueSocket())
        // A successful favourite refreshes the listing (which 2-way sync may change).
        await model.toggleFavorite(spotifyPlaylist())
        // The refreshed Spotify listing ("Ny") plus the just-favourited playlist,
        // which surfaces immediately via the MA favourite store even before the
        // Spotify follow syncs into the library.
        XCTAssertEqual(model.favoritePlaylists.map(\.name), ["Ny", "Lugnt & Skönt"])
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
