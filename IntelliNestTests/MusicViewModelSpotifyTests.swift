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
    /// Public playlists keyed by Spotify user id, returned from `userPlaylists`.
    var userPlaylistItems: [String: [MusicSearchItem]]
    private(set) var authorizeCallCount = 0
    private(set) var saveCallCount = 0
    private(set) var removeCallCount = 0
    private(set) var accountPlaylistsCallCount = 0
    private(set) var saveSongCallCount = 0
    private(set) var removeSongCallCount = 0
    private(set) var addedTracks: [(playlistID: String, trackID: String)] = []
    private(set) var removedTracks: [(playlistID: String, trackID: String)] = []
    private(set) var userPlaylistsCalls: [String] = []

    init(authorized: Bool = true,
         savedIDs: Set<String> = [],
         operationSucceeds: Bool = true,
         authorizeThrows: Bool = false,
         accountPlaylistItems: [MusicSearchItem] = [],
         editableIDs: Set<String> = [],
         savedSongTrackIDs: Set<String> = [],
         userPlaylistItems: [String: [MusicSearchItem]] = [:]) {
        self.authorized = authorized
        self.savedIDs = savedIDs
        self.operationSucceeds = operationSucceeds
        self.authorizeThrows = authorizeThrows
        self.accountPlaylistItems = accountPlaylistItems
        self.editableIDs = editableIDs
        self.savedSongTrackIDs = savedSongTrackIDs
        self.userPlaylistItems = userPlaylistItems
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

    func userPlaylists(userID: String) async -> [MusicSearchItem] {
        userPlaylistsCalls.append(userID)
        return userPlaylistItems[userID] ?? []
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
                       personalAccounts: [SpotifyPersonalAccount] = SpotifyPersonalAccount.configured) -> MusicViewModel {
        MusicViewModel(restAPIService: restAPIService,
                       setErrorBannerText: { [weak self] title, _ in self?.bannerTitles.append(title) },
                       spotify: spotify,
                       personalAccounts: personalAccounts)
    }

    // Fixed personal-account ids/titles — grep-searchable, no random data.
    var tobiasAccount: SpotifyPersonalAccount { SpotifyPersonalAccount(userID: "tobiasc91", title: "Mina spellistor") }
    var sarahAccount: SpotifyPersonalAccount { SpotifyPersonalAccount(userID: "sarahtest42", title: "Sarahs spellistor") }

    func playlistItem(uri: String, name: String) -> MusicSearchItem {
        MusicSearchItem(uri: uri, name: name, mediaType: .playlist, imageURL: nil, artist: nil)
    }

    /// A "Träning" playlist keyed under Tobias's user id — the common single-account fixture.
    func tobiasTräning() -> [String: [MusicSearchItem]] {
        ["tobiasc91": [playlistItem(uri: "spotify://playlist/p1", name: "Träning")]]
    }

    func testIsSpotifyPlaylistShowsStarForResolvableUriEvenLoggedOut() {
        let spotifyItem = spotifyPlaylist()
        let localItem = MusicSearchItem(uri: "library://playlist/3", name: "Lokal",
                                        mediaType: .playlist, imageURL: nil, artist: nil)
        // Logged in: star shows for a Spotify uri, not for an unmatched library item.
        let loggedIn = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: true))
        XCTAssertTrue(loggedIn.isSpotifyPlaylist(spotifyItem))
        XCTAssertFalse(loggedIn.isSpotifyPlaylist(localItem))
        // Logged out: a directly-resolvable Spotify playlist (a search result) still
        // shows the star — tapping it logs in first, then saves — but an unmatched
        // library item has no Spotify id to resolve (the account list is empty), so
        // it stays starless.
        let loggedOut = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false))
        XCTAssertTrue(loggedOut.isSpotifyPlaylist(spotifyItem))
        XCTAssertFalse(loggedOut.isSpotifyPlaylist(localItem))
    }

    func testLibraryPlaylistResolvesToSpotifyByName() async {
        // The huset account has this playlist (with its real Spotify id); Music
        // Assistant exposes the same playlist as an opaque library:// item.
        let account = [MusicSearchItem(uri: "spotify://playlist/realid42",
                                       name: "Barnlåtar 🐵 musik för barn",
                                       mediaType: .playlist, imageURL: nil, artist: nil)]
        let stub = StubSpotifyPlaylistService(accountPlaylistItems: account)
        let model = makeViewModel(spotify: stub)
        await model.refreshSpotifyPlaylists()
        let libraryItem = MusicSearchItem(uri: "library://playlist/12",
                                          name: "Barnlåtar 🐵 musik för barn  ",
                                          mediaType: .playlist, imageURL: nil, artist: nil)
        XCTAssertTrue(model.isSpotifyPlaylist(libraryItem))
        await model.toggleSpotifySaved(libraryItem)
        // It resolved to a Spotify id, so the save went through.
        XCTAssertEqual(stub.saveCallCount, 1)
    }

    func testLibraryBuiltinPlaylistHasNoStar() async {
        let account = [MusicSearchItem(uri: "spotify://playlist/realid42", name: "Barnlåtar",
                                       mediaType: .playlist, imageURL: nil, artist: nil)]
        let stub = StubSpotifyPlaylistService(accountPlaylistItems: account)
        let model = makeViewModel(spotify: stub)
        await model.refreshSpotifyPlaylists()
        let builtin = MusicSearchItem(uri: "library://playlist/3", name: "Random Album (from library)",
                                      mediaType: .playlist, imageURL: nil, artist: nil)
        XCTAssertFalse(model.isSpotifyPlaylist(builtin))
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
        XCTAssertTrue(model.savedPlaylistIDs.isEmpty)
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

    // MARK: - Personal account playlist sections

    func testPersonalSectionAppearsWhenLoggedInWithPlaylists() async {
        let playlists = [playlistItem(uri: "spotify://playlist/p1", name: "Träning"),
                         playlistItem(uri: "spotify://playlist/p2", name: "Lugnt & skönt")]
        let stub = StubSpotifyPlaylistService(userPlaylistItems: ["tobiasc91": playlists])
        let model = makeViewModel(spotify: stub, personalAccounts: [tobiasAccount])
        await model.refreshPersonalPlaylists()
        XCTAssertEqual(model.personalPlaylistSections.count, 1)
        XCTAssertEqual(model.personalPlaylistSections.first?.title, "Mina spellistor")
        // Order is preserved exactly as returned — no client-side re-sorting.
        XCTAssertEqual(model.personalPlaylistSections.first?.playlists.map(\.name), ["Träning", "Lugnt & skönt"])
    }

    func testPersonalSectionLoadsViaReload() async {
        let stub = StubSpotifyPlaylistService(userPlaylistItems: tobiasTräning())
        let model = makeViewModel(spotify: stub, personalAccounts: [tobiasAccount])
        stubAllSpeakers(playing: .mediaPlayerKitchen)
        XCTAssertTrue(model.personalPlaylistSections.isEmpty)
        await model.reload()
        XCTAssertEqual(model.personalPlaylistSections.map(\.title), ["Mina spellistor"])
    }

    func testPersonalSectionHiddenWhenAccountHasNoPlaylists() async {
        let stub = StubSpotifyPlaylistService(userPlaylistItems: ["tobiasc91": []])
        let model = makeViewModel(spotify: stub, personalAccounts: [tobiasAccount])
        await model.refreshPersonalPlaylists()
        XCTAssertTrue(model.personalPlaylistSections.isEmpty)
        // The fetch was still attempted (empty result, not skipped).
        XCTAssertEqual(stub.userPlaylistsCalls, ["tobiasc91"])
    }

    func testPersonalSectionHiddenWhenLoggedOut() async {
        let stub = StubSpotifyPlaylistService(authorized: false, userPlaylistItems: tobiasTräning())
        let model = makeViewModel(spotify: stub, personalAccounts: [tobiasAccount])
        await model.refreshPersonalPlaylists()
        XCTAssertTrue(model.personalPlaylistSections.isEmpty)
        XCTAssertTrue(stub.userPlaylistsCalls.isEmpty)
    }

    func testPersonalSectionsClearedWhenSessionBecomesLoggedOut() async {
        let stub = StubSpotifyPlaylistService(userPlaylistItems: tobiasTräning())
        let model = makeViewModel(spotify: stub, personalAccounts: [tobiasAccount])
        await model.refreshPersonalPlaylists()
        XCTAssertEqual(model.personalPlaylistSections.count, 1)
        // The session is lost; a refresh now clears the sections so they disappear.
        stub.authorized = false
        await model.refreshPersonalPlaylists()
        XCTAssertTrue(model.personalPlaylistSections.isEmpty)
    }

    func testMultipleAccountsEachGetASectionInConfiguredOrder() async {
        let stub = StubSpotifyPlaylistService(userPlaylistItems: [
            "tobiasc91": [playlistItem(uri: "spotify://playlist/p1", name: "Träning")],
            "sarahtest42": [playlistItem(uri: "spotify://playlist/p2", name: "Sarahs mix")]
        ])
        let model = makeViewModel(spotify: stub, personalAccounts: [tobiasAccount, sarahAccount])
        await model.refreshPersonalPlaylists()
        XCTAssertEqual(model.personalPlaylistSections.map(\.title), ["Mina spellistor", "Sarahs spellistor"])
    }

    func testEmptyAccountDroppedWhileOthersRemain() async {
        let stub = StubSpotifyPlaylistService(userPlaylistItems: [
            "tobiasc91": [],
            "sarahtest42": [playlistItem(uri: "spotify://playlist/p2", name: "Sarahs mix")]
        ])
        let model = makeViewModel(spotify: stub, personalAccounts: [tobiasAccount, sarahAccount])
        await model.refreshPersonalPlaylists()
        // Tobias has nothing → dropped; only Sarah's section shows.
        XCTAssertEqual(model.personalPlaylistSections.map(\.title), ["Sarahs spellistor"])
    }

    func testPersonalSectionRefreshReflectsLatestPlaylists() async {
        let stub = StubSpotifyPlaylistService(userPlaylistItems: tobiasTräning())
        let model = makeViewModel(spotify: stub, personalAccounts: [tobiasAccount])
        await model.refreshPersonalPlaylists()
        XCTAssertEqual(model.personalPlaylistSections.first?.playlists.map(\.name), ["Träning"])
        // Renamed/changed on Spotify; a refresh reflects it with no stale cache.
        stub.userPlaylistItems = ["tobiasc91": [playlistItem(uri: "spotify://playlist/p3", name: "Ny spellista")]]
        await model.refreshPersonalPlaylists()
        XCTAssertEqual(model.personalPlaylistSections.first?.playlists.map(\.name), ["Ny spellista"])
    }

    func testConnectSpotifyLoadsPersonalSections() async {
        let stub = StubSpotifyPlaylistService(authorized: false, userPlaylistItems: tobiasTräning())
        let model = makeViewModel(spotify: stub, personalAccounts: [tobiasAccount])
        await model.connectSpotify()
        XCTAssertEqual(model.personalPlaylistSections.map(\.title), ["Mina spellistor"])
    }

    func testTappingPersonalPlaylistRoutesThroughBrowseFlow() async {
        let playlist = playlistItem(uri: "spotify://playlist/p1", name: "Träning")
        let stub = StubSpotifyPlaylistService(userPlaylistItems: ["tobiasc91": [playlist]])
        let model = makeViewModel(spotify: stub, personalAccounts: [tobiasAccount])
        model.selectSpeaker(.mediaPlayerKitchen)
        await model.refreshPersonalPlaylists()
        // Tapping a personal playlist uses the same browse flow as a favourite.
        await model.browseLibraryPlaylist(model.personalPlaylistSections.first!.playlists.first!)
        XCTAssertEqual(model.browsingLibraryPlaylist?.uri, playlist.uri)
    }

    func testDefaultPersonalAccountsConfiguresTobiasThenSarah() {
        XCTAssertEqual(SpotifyPersonalAccount.configured.map(\.userID), ["tobiasc91", "mbostroem"])
        XCTAssertEqual(SpotifyPersonalAccount.configured.map(\.title), ["Mina spellistor", "Sarahs spellistor"])
    }

    func testLoadLibrarySavedStatesResolvesPersonalSectionRows() async {
        // A personal playlist saved in the huset library but not a favourite must
        // still get its row star resolved, so it isn't shown empty until detail open.
        let personal = playlistItem(uri: "spotify://playlist/p1", name: "Träning")
        let stub = StubSpotifyPlaylistService(savedIDs: ["p1"], userPlaylistItems: ["tobiasc91": [personal]])
        let model = makeViewModel(spotify: stub, personalAccounts: [tobiasAccount])
        await model.refreshPersonalPlaylists()
        XCTAssertTrue(model.librarySavedStateSignature.contains("spotify://playlist/p1"))
        await model.loadLibrarySavedStates()
        XCTAssertTrue(model.isSaved(personal))
    }

    func testLoadLibrarySavedStatesLeavesUnsavedPersonalRowUnmarked() async {
        let personal = playlistItem(uri: "spotify://playlist/p9", name: "Inte sparad")
        let stub = StubSpotifyPlaylistService(savedIDs: [], userPlaylistItems: ["tobiasc91": [personal]])
        let model = makeViewModel(spotify: stub, personalAccounts: [tobiasAccount])
        await model.refreshPersonalPlaylists()
        await model.loadLibrarySavedStates()
        XCTAssertFalse(model.isSaved(personal))
    }

    // A playlist the account *owns* isn't "followed", so Spotify's follow-contains
    // check (`savedIDs` here) returns false for it. Library membership, not that
    // check, must decide the star — otherwise the same owned playlist shows filled
    // under Favoriter but hollow under Senast spelade.
    func testOwnedFavouriteShowsSavedInBothFavouritesAndRecents() async {
        let name = "Låtar som är ganska sköna och avslappnande"
        let owned = MusicSearchItem(uri: "spotify://playlist/owned1", name: name,
                                    mediaType: .playlist, imageURL: nil, artist: "huset")
        // savedIDs empty → the follow-contains check would say "not saved".
        let stub = StubSpotifyPlaylistService(savedIDs: [], accountPlaylistItems: [owned])
        let model = makeViewModel(spotify: stub)
        await model.refreshSpotifyPlaylists()
        // The same playlist surfaces in Senast spelade as an opaque library:// item.
        let recent = MusicSearchItem(uri: "library://playlist/42", name: name,
                                     mediaType: .playlist, imageURL: nil, artist: nil)
        model.recentlyPlayedPlaylists = [recent]
        await model.loadLibrarySavedStates()
        XCTAssertTrue(model.isSaved(owned))
        XCTAssertTrue(model.isSaved(recent))
    }

    // Opening an owned favourite's detail must not un-mark it: the follow-contains
    // check returns false, but library membership keeps the star filled (the popup
    // no longer drops the playlist to non-favourite on dismiss).
    func testOpeningOwnedFavouriteDetailKeepsItSaved() async {
        let owned = MusicSearchItem(uri: "spotify://playlist/owned1", name: "Min egen lista",
                                    mediaType: .playlist, imageURL: nil, artist: "huset")
        let stub = StubSpotifyPlaylistService(savedIDs: [], accountPlaylistItems: [owned])
        let model = makeViewModel(spotify: stub)
        await model.refreshSpotifyPlaylists()
        await model.loadSavedState(for: owned)
        XCTAssertTrue(model.isSaved(owned))
    }
}
