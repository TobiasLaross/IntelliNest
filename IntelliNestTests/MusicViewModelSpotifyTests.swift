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
    var editableIDs: Set<String>
    var savedSongTrackIDs: Set<String>
    private(set) var authorizeCallCount = 0
    private(set) var saveCallCount = 0
    private(set) var removeCallCount = 0
    private(set) var accountPlaylistsCallCount = 0
    private(set) var saveSongCallCount = 0
    private(set) var removeSongCallCount = 0
    private(set) var addedTracks: [(playlistID: String, trackID: String)] = []
    private(set) var removedTracks: [(playlistID: String, trackID: String)] = []

    init(authorized: Bool = true,
         savedIDs: Set<String> = [],
         operationSucceeds: Bool = true,
         authorizeThrows: Bool = false,
         accountPlaylistItems: [MusicSearchItem] = [],
         editableIDs: Set<String> = [],
         savedSongTrackIDs: Set<String> = []) {
        self.authorized = authorized
        self.savedIDs = savedIDs
        self.operationSucceeds = operationSucceeds
        self.authorizeThrows = authorizeThrows
        self.accountPlaylistItems = accountPlaylistItems
        self.editableIDs = editableIDs
        self.savedSongTrackIDs = savedSongTrackIDs
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

    func editablePlaylistIDs() async -> Set<String> {
        editableIDs
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

    func savedSongIDs(trackIDs: [String]) async -> Set<String> {
        savedSongTrackIDs.intersection(trackIDs)
    }

    func saveSong(trackID: String) async -> Bool {
        saveSongCallCount += 1
        if operationSucceeds {
            savedSongTrackIDs.insert(trackID)
        }
        return operationSucceeds
    }

    func removeSong(trackID: String) async -> Bool {
        removeSongCallCount += 1
        if operationSucceeds {
            savedSongTrackIDs.remove(trackID)
        }
        return operationSucceeds
    }

    func addTrack(playlistID: String, trackID: String) async -> Bool {
        if operationSucceeds {
            addedTracks.append((playlistID, trackID))
        }
        return operationSucceeds
    }

    func removeTrack(playlistID: String, trackID: String) async -> Bool {
        if operationSucceeds {
            removedTracks.append((playlistID, trackID))
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

    func makeViewModel(spotify: SpotifyPlaylistService,
                       socket: MusicAssistantQueueSocket = DisabledMusicAssistantQueueSocket(),
                       personalAccounts: [SpotifyPersonalAccount] = SpotifyPersonalAccount.configured,
                       currentUser: @escaping @MainActor () -> User = { .tobias }) -> MusicViewModel {
        MusicViewModel(restAPIService: restAPIService,
                       setErrorBannerText: { [weak self] title, _ in self?.bannerTitles.append(title) },
                       spotify: spotify,
                       queueSocket: socket,
                       personalAccounts: personalAccounts,
                       currentUser: currentUser)
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

    func testToggleRefreshesListing() async {
        let item = MusicSearchItem(uri: "spotify://playlist/x", name: "Ny",
                                   mediaType: .playlist, imageURL: nil, artist: nil)
        let stub = StubSpotifyPlaylistService(accountPlaylistItems: [item])
        let model = makeViewModel(spotify: stub, socket: StubMusicAssistantQueueSocket())
        // A successful favourite refreshes the listing (which 2-way sync may change).
        await model.toggleFavorite(spotifyPlaylist())
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

    // MARK: - Personal account playlist sections

    func testPersonalSectionAppearsWhenLoggedInWithPlaylists() async {
        // Personal sections are sourced from the huset library, matched by ownerID.
        let library = [playlistItem(uri: "spotify://playlist/p1", name: "Träning", ownerID: "tobiasc91"),
                       playlistItem(uri: "spotify://playlist/p2", name: "Lugnt & skönt", ownerID: "tobiasc91")]
        let stub = StubSpotifyPlaylistService(accountPlaylistItems: library)
        let model = makeViewModel(spotify: stub, personalAccounts: [tobiasAccount])
        await model.refreshSpotifyPlaylists()
        XCTAssertEqual(model.personalPlaylistSections.count, 1)
        XCTAssertEqual(model.personalPlaylistSections.first?.title, "Mina spellistor")
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
        XCTAssertEqual(model.personalPlaylistSections.map(\.title), ["Mina spellistor"])
    }

    func testPersonalSectionHiddenWhenAccountOwnsNoLibraryPlaylists() async {
        // The library has playlists, but none owned by Tobias → no Mina section.
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
        XCTAssertEqual(model.personalPlaylistSections.map(\.title), ["Mina spellistor", "Sarahs spellistor"])
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
        XCTAssertEqual(model.personalPlaylistSections.map(\.title), ["Mina spellistor"])
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

    func testViewerOwnSectionIsFirstAndTitledMina() async {
        let library = [playlistItem(uri: "spotify://playlist/p1", name: "Tobias lista", ownerID: "tobiasc91"),
                       playlistItem(uri: "spotify://playlist/p2", name: "Sarahs lista", ownerID: "sarahtest42")]
        let stub = StubSpotifyPlaylistService(accountPlaylistItems: library)
        // Sarah is the viewer → her section is first and titled "Mina spellistor",
        // Tobias's drops below, titled by his name.
        let model = makeViewModel(spotify: stub, personalAccounts: [tobiasAccount, sarahAccount], currentUser: { .sarah })
        await model.refreshSpotifyPlaylists()
        XCTAssertEqual(model.personalPlaylistSections.map(\.title), ["Mina spellistor", "Tobias spellistor"])
        XCTAssertEqual(model.personalPlaylistSections.first?.account.userID, "sarahtest42")
    }
}
