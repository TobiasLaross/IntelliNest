@testable import IntelliNest
import XCTest

/// Song-level Spotify behaviour on the music view model: liking/unliking tracks,
/// adding and removing playlist tracks, and tracking the now-playing source
/// playlist for the jump-to-playlist control. Reuses `MusicViewModelTests`
/// scaffolding (stubbed REST + speakers).
@MainActor
extension MusicViewModelTests {
    private var spotifyTrackURI: String { trackURI }

    private func playlistTrack(_ uri: String, title: String = "X") -> MusicPlaylistTrack {
        MusicPlaylistTrack(uri: uri, title: title, imageURL: nil)
    }

    // MARK: - Liked Songs

    func testCanFavoriteSongRequiresLoginAndSpotifyTrack() {
        let loggedIn = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: true))
        XCTAssertTrue(loggedIn.canFavoriteSong(uri: spotifyTrackURI))
        XCTAssertFalse(loggedIn.canFavoriteSong(uri: "library://track/4"))
        XCTAssertFalse(loggedIn.canFavoriteSong(uri: nil))

        let loggedOut = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false))
        XCTAssertFalse(loggedOut.canFavoriteSong(uri: spotifyTrackURI))
    }

    func testLoadSavedSongStatesReflectsLibrary() async {
        let trackID = "3SjXx3rbNGk8nCho8YEoz5"
        let stub = StubSpotifyPlaylistService(savedSongTrackIDs: [trackID])
        let model = makeViewModel(spotify: stub)
        await model.loadSavedSongStates(uris: [spotifyTrackURI])
        XCTAssertTrue(model.isSongSaved(uri: spotifyTrackURI))
    }

    func testToggleSongSavesThenRemoves() async {
        let stub = StubSpotifyPlaylistService()
        let model = makeViewModel(spotify: stub)
        await model.toggleSongSaved(uri: spotifyTrackURI)
        XCTAssertTrue(model.isSongSaved(uri: spotifyTrackURI))
        XCTAssertEqual(stub.saveSongCallCount, 1)

        await model.toggleSongSaved(uri: spotifyTrackURI)
        XCTAssertFalse(model.isSongSaved(uri: spotifyTrackURI))
        XCTAssertEqual(stub.removeSongCallCount, 1)
    }

    func testToggleSongFailureRevertsAndBanners() async {
        let stub = StubSpotifyPlaylistService(operationSucceeds: false)
        let model = makeViewModel(spotify: stub)
        await model.toggleSongSaved(uri: spotifyTrackURI)
        XCTAssertFalse(model.isSongSaved(uri: spotifyTrackURI))
        XCTAssertTrue(bannerTitles.contains("Kunde inte uppdatera favorit"))
    }

    func testToggleSongLogsInWhenLoggedOut() async {
        let stub = StubSpotifyPlaylistService(authorized: false)
        let model = makeViewModel(spotify: stub)
        await model.toggleSongSaved(uri: spotifyTrackURI)
        XCTAssertEqual(stub.authorizeCallCount, 1)
        XCTAssertTrue(model.isSongSaved(uri: spotifyTrackURI))
    }

    func testToggleSongIgnoresNonSpotifyTrack() async {
        let stub = StubSpotifyPlaylistService()
        let model = makeViewModel(spotify: stub)
        await model.toggleSongSaved(uri: "library://track/9")
        XCTAssertEqual(stub.saveSongCallCount, 0)
        XCTAssertTrue(model.savedSongURIs.isEmpty)
    }

    // MARK: - Add to playlist

    private func makeEditableModel() async -> (MusicViewModel, StubSpotifyPlaylistService) {
        let stub = StubSpotifyPlaylistService(accountPlaylistItems: [spotifyPlaylist()],
                                              editableIDs: [spotifyPlaylistID])
        let model = makeViewModel(spotify: stub)
        await model.refreshSpotifyPlaylists()
        return (model, stub)
    }

    func testEditableAccountPlaylistsFiltersByEditableIDs() async {
        let (model, _) = await makeEditableModel()
        XCTAssertEqual(model.editableAccountPlaylists.map(\.name), ["Lugnt & Skönt"])
    }

    func testCanAddTrackRequiresEditablePlaylistAndSpotifyTrack() async {
        let (model, _) = await makeEditableModel()
        XCTAssertTrue(model.canAddTrackToPlaylist(uri: spotifyTrackURI))
        XCTAssertFalse(model.canAddTrackToPlaylist(uri: "library://track/1"))
    }

    func testAddTrackToPlaylistCallsSpotify() async {
        let (model, stub) = await makeEditableModel()
        await model.addTrack(uri: spotifyTrackURI, toPlaylist: spotifyPlaylist())
        XCTAssertEqual(stub.addedTracks.count, 1)
        XCTAssertEqual(stub.addedTracks.first?.playlistID, spotifyPlaylistID)
        XCTAssertEqual(stub.addedTracks.first?.trackID, "3SjXx3rbNGk8nCho8YEoz5")
    }

    func testAddTrackFailureBanners() async {
        let stub = StubSpotifyPlaylistService(operationSucceeds: false,
                                              accountPlaylistItems: [spotifyPlaylist()],
                                              editableIDs: [spotifyPlaylistID])
        let model = makeViewModel(spotify: stub)
        await model.refreshSpotifyPlaylists()
        await model.addTrack(uri: spotifyTrackURI, toPlaylist: spotifyPlaylist())
        XCTAssertTrue(bannerTitles.contains("Kunde inte lägga till i spellistan"))
    }

    // MARK: - Remove from playlist

    func testCanEditPlaylistReflectsEditableIDs() async {
        let (model, _) = await makeEditableModel()
        XCTAssertTrue(model.canEditPlaylist(spotifyPlaylist()))
        let other = MusicSearchItem(uri: "spotify://playlist/other", name: "Annan",
                                    mediaType: .playlist, imageURL: nil, artist: nil)
        XCTAssertFalse(model.canEditPlaylist(other))
    }

    func testRemoveTrackFromPlaylistOptimisticallyDropsRow() async {
        let (model, stub) = await makeEditableModel()
        let track = playlistTrack(spotifyTrackURI)
        model.playlistTracks = [track, playlistTrack("spotify://track/keep", title: "Keep")]
        await model.removeTrack(track, fromPlaylist: spotifyPlaylist())
        XCTAssertEqual(model.playlistTracks.map(\.title), ["Keep"])
        XCTAssertEqual(stub.removedTracks.first?.trackID, "3SjXx3rbNGk8nCho8YEoz5")
    }

    func testRemoveTrackFailureRevertsList() async {
        let stub = StubSpotifyPlaylistService(operationSucceeds: false,
                                              accountPlaylistItems: [spotifyPlaylist()],
                                              editableIDs: [spotifyPlaylistID])
        let model = makeViewModel(spotify: stub)
        await model.refreshSpotifyPlaylists()
        let track = playlistTrack(spotifyTrackURI)
        model.playlistTracks = [track]
        await model.removeTrack(track, fromPlaylist: spotifyPlaylist())
        XCTAssertEqual(model.playlistTracks.map(\.uri), [spotifyTrackURI])
        XCTAssertTrue(bannerTitles.contains("Kunde inte ta bort låten"))
    }

    // MARK: - Jump to playing playlist

    func testPlayPlaylistSetsNowPlayingSource() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        stubPlayMedia(statusCode: 200)
        await viewModel.playPlaylist(spotifyPlaylist())
        XCTAssertEqual(viewModel.nowPlayingSourcePlaylist?.uri, spotifyPlaylist().uri)
    }

    func testPlaySingleTrackClearsNowPlayingSource() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        viewModel.nowPlayingSourcePlaylist = spotifyPlaylist()
        stubPlayMedia(statusCode: 200)
        let item = MusicSearchItem(uri: spotifyTrackURI, name: "Track", mediaType: .track, imageURL: nil, artist: nil)
        await viewModel.play(item: item)
        XCTAssertNil(viewModel.nowPlayingSourcePlaylist)
    }

    func testOpenNowPlayingPlaylistOpensBrowseSheet() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        viewModel.nowPlayingSourcePlaylist = spotifyPlaylist()
        await viewModel.openNowPlayingPlaylist()
        XCTAssertEqual(viewModel.playerBrowsingPlaylist?.uri, spotifyPlaylist().uri)
    }

    func testOpenNowPlayingPlaylistNoOpWhenSourceUnknown() async {
        viewModel.nowPlayingSourcePlaylist = nil
        await viewModel.openNowPlayingPlaylist()
        XCTAssertNil(viewModel.playerBrowsingPlaylist)
    }

    // MARK: - Sheet hosts

    func testPlayerAndRoomsOpenOverTheTopmostLayer() {
        let section = MusicLibrarySection(id: "recent", title: "Senast spelade", playlists: [])
        struct Case {
            let name: String
            let setUp: (MusicViewModel) -> Void
            let playerHost: MusicSheetHost
        }
        let cases = [
            Case(name: "music screen", setUp: { _ in }, playerHost: .musicScreen),
            Case(name: "Visa alla", setUp: { $0.expandedLibrarySection = section }, playerHost: .browseSheet),
            Case(name: "artist", setUp: { $0.browsingArtist = self.spotifyPlaylist() }, playerHost: .browseSheet),
            Case(name: "library playlist", setUp: { $0.browsingLibraryPlaylist = self.spotifyPlaylist() }, playerHost: .browseSheet)
        ]
        for testCase in cases {
            let model = makeViewModel(spotify: StubSpotifyPlaylistService())
            testCase.setUp(model)
            model.isShowingSpeakerPicker = true
            for host in [MusicSheetHost.musicScreen, .browseSheet, .player] {
                XCTAssertEqual(model.presentation(\.isShowingSpeakerPicker, from: host).wrappedValue,
                               host == testCase.playerHost, "rooms from \(host) over \(testCase.name)")
            }

            model.isShowingNowPlaying = true
            for host in [MusicSheetHost.musicScreen, .browseSheet] {
                XCTAssertEqual(model.nowPlayingPresentation(from: host).wrappedValue,
                               host == testCase.playerHost, "player from \(host) over \(testCase.name)")
            }
            XCTAssertTrue(model.presentation(\.isShowingSpeakerPicker, from: .player).wrappedValue, testCase.name)
        }
    }

    func testPlayerLinkOverALibraryPlaylistSheetKeepsBothOpen() async {
        let browsed = MusicSearchItem(uri: "spotify://playlist/37i9dQZF1DXcBWIGoYBM5M", name: "Today's Top Hits",
                                      mediaType: .playlist, imageURL: nil, artist: nil)
        await viewModel.browseLibraryPlaylist(browsed)
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        viewModel.isShowingNowPlaying = true
        viewModel.nowPlayingSourcePlaylist = spotifyPlaylist()

        await viewModel.openNowPlayingPlaylist()

        XCTAssertEqual(viewModel.browsingLibraryPlaylist?.uri, browsed.uri)
        XCTAssertEqual(viewModel.playerBrowsingPlaylist?.uri, spotifyPlaylist().uri)
        XCTAssertTrue(viewModel.nowPlayingPresentation(from: .browseSheet).wrappedValue)
        XCTAssertFalse(viewModel.nowPlayingPresentation(from: .musicScreen).wrappedValue)
    }

    func testPlayerPresentsThePlaylistItsLinkOpened() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        viewModel.nowPlayingSourcePlaylist = spotifyPlaylist()
        viewModel.isShowingNowPlaying = true
        await viewModel.openNowPlayingPlaylist()
        XCTAssertEqual(viewModel.playerBrowsingPlaylist?.uri, spotifyPlaylist().uri)
        XCTAssertNil(viewModel.browsingLibraryPlaylist)
        XCTAssertFalse(viewModel.isShowingBrowseSheet)
        XCTAssertTrue(viewModel.nowPlayingPresentation(from: .musicScreen).wrappedValue)
    }

    func testDismissBrowseSheetsClosesThePlayersPlaylistToo() {
        viewModel.browsingLibraryPlaylist = spotifyPlaylist()
        viewModel.playerBrowsingPlaylist = spotifyPlaylist()
        viewModel.dismissBrowseSheets()
        XCTAssertNil(viewModel.browsingLibraryPlaylist)
        XCTAssertNil(viewModel.playerBrowsingPlaylist)
    }
}
