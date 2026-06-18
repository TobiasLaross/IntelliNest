@testable import IntelliNest
import XCTest

// MARK: - Grouping & live updates

@MainActor
extension MusicViewModelTests {
    func testJoinAddsSpeakerToGroup() async {
        viewModel.selectSpeaker(.mediaPlayerLivingRoom)
        let expectation = XCTestExpectation(description: "POST join")
        URLProtocolStub.observerRequests { request in
            if request.httpMethod == "POST", request.url?.path.contains("/media_player/join") == true {
                expectation.fulfill()
            }
        }
        stubPostService(path: "/api/services/media_player/join")
        XCTAssertFalse(viewModel.isGrouped(.mediaPlayerKitchen))
        await viewModel.toggleGroupMember(.mediaPlayerKitchen)
        await fulfillment(of: [expectation], timeout: 2.0)
    }

    func testJoinRefreshesMembershipImmediatelyAndClearsPending() async {
        // Kitchen is the active, ungrouped leader.
        stubAllSpeakers(playing: .mediaPlayerKitchen)
        await viewModel.reload()
        XCTAssertFalse(viewModel.isGrouped(.mediaPlayerGuestRoom))

        // The join succeeds and the speakers now report the new group, so the
        // confirming reload inside toggleGroupMember should reflect it right away —
        // without waiting for the 5-second loop — and clear the pending spinner.
        stubPostService(path: "/api/services/media_player/join")
        let group = [EntityId.mediaPlayerKitchen.rawValue, EntityId.mediaPlayerGuestRoom.rawValue]
        stubSpeaker(.mediaPlayerKitchen,
                    data: speakerJSON(entityID: .mediaPlayerKitchen, state: "playing",
                                      friendlyName: "Köket", groupMembers: group))
        stubSpeaker(.mediaPlayerGuestRoom,
                    data: speakerJSON(entityID: .mediaPlayerGuestRoom, state: "idle",
                                      friendlyName: "Gästrummet", groupMembers: group))
        await viewModel.toggleGroupMember(.mediaPlayerGuestRoom)

        XCTAssertTrue(viewModel.isGrouped(.mediaPlayerGuestRoom))
        XCTAssertTrue(viewModel.pendingGroupingSpeakers.isEmpty)
    }

    func testFailedJoinClearsPendingAndBanners() async {
        stubAllSpeakers(playing: .mediaPlayerKitchen)
        await viewModel.reload()
        stubPostService(path: "/api/services/media_player/join", statusCode: 500)
        await viewModel.toggleGroupMember(.mediaPlayerGuestRoom)
        XCTAssertTrue(viewModel.pendingGroupingSpeakers.isEmpty)
        XCTAssertTrue(bannerTitles.contains("Kunde inte gruppera högtalare"))
    }

    func testUnjoinRemovesSpeakerFromGroup() async {
        // Living room is leader with Kitchen already grouped in.
        stubSpeaker(.mediaPlayerLivingRoom,
                    data: speakerJSON(entityID: .mediaPlayerLivingRoom,
                                      state: "playing",
                                      friendlyName: "Vardagsrummet",
                                      groupMembers: [EntityId.mediaPlayerKitchen.rawValue]))
        for entityID in MusicViewModel.speakerIDs where entityID != .mediaPlayerLivingRoom {
            stubSpeaker(entityID, data: speakerJSON(entityID: entityID, state: "idle", friendlyName: entityID.rawValue))
        }
        await viewModel.reload()
        XCTAssertEqual(viewModel.activeSpeakerID, .mediaPlayerLivingRoom)
        XCTAssertTrue(viewModel.isGrouped(.mediaPlayerKitchen))

        let expectation = XCTestExpectation(description: "POST unjoin")
        URLProtocolStub.observerRequests { request in
            if request.httpMethod == "POST", request.url?.path.contains("/media_player/unjoin") == true {
                expectation.fulfill()
            }
        }
        stubPostService(path: "/api/services/media_player/unjoin")
        await viewModel.toggleGroupMember(.mediaPlayerKitchen)
        await fulfillment(of: [expectation], timeout: 2.0)
    }

    func testJoinUnjoinsSpeakerFromItsOldGroupFirst() async {
        // Kitchen is the active, ungrouped leader. Spa and Matbord-ute are already
        // synced together in their own group, so tapping Spa must unjoin it from
        // that group before joining Kitchen — a bare join would silently no-op.
        let spaGroup = [EntityId.mediaPlayerSpa.rawValue, EntityId.mediaPlayerOutdoorTable.rawValue]
        stubSpeaker(.mediaPlayerKitchen,
                    data: speakerJSON(entityID: .mediaPlayerKitchen, state: "playing", friendlyName: "Köket"))
        stubSpeaker(.mediaPlayerSpa,
                    data: speakerJSON(entityID: .mediaPlayerSpa, state: "idle", friendlyName: "Spa", groupMembers: spaGroup))
        stubSpeaker(.mediaPlayerOutdoorTable,
                    data: speakerJSON(entityID: .mediaPlayerOutdoorTable, state: "idle",
                                      friendlyName: "Matbord-ute", groupMembers: spaGroup))
        for entityID in [EntityId.mediaPlayerGuestRoom, .mediaPlayerPlayroom, .mediaPlayerLivingRoom] {
            stubSpeaker(entityID, data: speakerJSON(entityID: entityID, state: "idle", friendlyName: entityID.rawValue))
        }
        await viewModel.reload()
        XCTAssertEqual(viewModel.activeSpeakerID, .mediaPlayerKitchen)
        XCTAssertFalse(viewModel.isGrouped(.mediaPlayerSpa))

        let orderLock = NSLock()
        var requestOrder: [String] = []
        URLProtocolStub.observerRequests { request in
            guard request.httpMethod == "POST", let path = request.url?.path else {
                return
            }
            if path.contains("/media_player/unjoin") {
                orderLock.withLock { requestOrder.append("unjoin") }
            } else if path.contains("/media_player/join") {
                orderLock.withLock { requestOrder.append("join") }
            }
        }
        stubPostService(path: "/api/services/media_player/unjoin")
        stubPostService(path: "/api/services/media_player/join")

        await viewModel.toggleGroupMember(.mediaPlayerSpa)
        let recordedOrder = orderLock.withLock { requestOrder }
        XCTAssertEqual(recordedOrder, ["unjoin", "join"])
    }

    func testJoinDoesNotUnjoinAFreeSpeaker() async {
        // Kitchen active, Spa ungrouped. Tapping Spa joins it directly — no unjoin.
        stubAllSpeakers(playing: .mediaPlayerKitchen)
        await viewModel.reload()
        XCTAssertFalse(viewModel.isGrouped(.mediaPlayerSpa))

        let orderLock = NSLock()
        var requestOrder: [String] = []
        URLProtocolStub.observerRequests { request in
            guard request.httpMethod == "POST", let path = request.url?.path else {
                return
            }
            if path.contains("/media_player/unjoin") {
                orderLock.withLock { requestOrder.append("unjoin") }
            } else if path.contains("/media_player/join") {
                orderLock.withLock { requestOrder.append("join") }
            }
        }
        stubPostService(path: "/api/services/media_player/unjoin")
        stubPostService(path: "/api/services/media_player/join")

        await viewModel.toggleGroupMember(.mediaPlayerSpa)
        let recordedOrder = orderLock.withLock { requestOrder }
        XCTAssertEqual(recordedOrder, ["join"])
    }

    func testJoinFailureShowsBanner() async {
        // Kitchen active, Spa ungrouped, but the join is rejected by Home Assistant.
        stubAllSpeakers(playing: .mediaPlayerKitchen)
        await viewModel.reload()
        stubPostService(path: "/api/services/media_player/join", statusCode: 500)
        await viewModel.toggleGroupMember(.mediaPlayerSpa)
        XCTAssertTrue(bannerTitles.contains("Kunde inte gruppera högtalare"))
    }

    func testUnjoinFailureShowsBanner() async {
        // Living room leader with Kitchen grouped in; the unjoin is rejected.
        stubSpeaker(.mediaPlayerLivingRoom,
                    data: speakerJSON(entityID: .mediaPlayerLivingRoom,
                                      state: "playing",
                                      friendlyName: "Vardagsrummet",
                                      groupMembers: [EntityId.mediaPlayerKitchen.rawValue]))
        for entityID in MusicViewModel.speakerIDs where entityID != .mediaPlayerLivingRoom {
            stubSpeaker(entityID, data: speakerJSON(entityID: entityID, state: "idle", friendlyName: entityID.rawValue))
        }
        await viewModel.reload()
        XCTAssertTrue(viewModel.isGrouped(.mediaPlayerKitchen))
        stubPostService(path: "/api/services/media_player/unjoin", statusCode: 500)
        await viewModel.toggleGroupMember(.mediaPlayerKitchen)
        XCTAssertTrue(bannerTitles.contains("Kunde inte dela upp högtalare"))
    }

    func testGroupingNoOpForActiveSpeakerItself() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        XCTAssertFalse(viewModel.isGrouped(.mediaPlayerKitchen))
        // Toggling the leader against itself must do nothing (no crash).
        await viewModel.toggleGroupMember(.mediaPlayerKitchen)
    }

    func testRemoveActiveSpeakerFromGroupPromotesNextSpeaker() async {
        // Kitchen leads a group with Playroom and Matbord-ute.
        await reloadGroupedKitchenLeader()
        XCTAssertEqual(viewModel.activeSpeakerID, .mediaPlayerKitchen)

        let expectation = XCTestExpectation(description: "POST unjoin")
        URLProtocolStub.observerRequests { request in
            if request.httpMethod == "POST", request.url?.path.contains("/media_player/unjoin") == true {
                expectation.fulfill()
            }
        }
        stubPostService(path: "/api/services/media_player/unjoin")
        await viewModel.removeActiveSpeakerFromGroup()
        await fulfillment(of: [expectation], timeout: 2.0)
        // The next remaining member in display order takes over as active.
        XCTAssertEqual(viewModel.activeSpeakerID, .mediaPlayerPlayroom)
    }

    func testMakePrimaryPromotesGroupedSpeaker() async {
        await reloadGroupedKitchenLeader()
        XCTAssertEqual(viewModel.activeSpeakerID, .mediaPlayerKitchen)
        XCTAssertTrue(viewModel.isGrouped(.mediaPlayerPlayroom))
        viewModel.makePrimary(.mediaPlayerPlayroom)
        XCTAssertEqual(viewModel.activeSpeakerID, .mediaPlayerPlayroom)
    }

    func testMakePrimaryIgnoresUngroupedSpeaker() async {
        await reloadGroupedKitchenLeader()
        // Spa isn't in the group, so it can't be made primary.
        XCTAssertFalse(viewModel.isGrouped(.mediaPlayerSpa))
        viewModel.makePrimary(.mediaPlayerSpa)
        XCTAssertEqual(viewModel.activeSpeakerID, .mediaPlayerKitchen)
    }

    func testRemoveActiveSpeakerNoOpWhenUngrouped() async {
        stubAllSpeakers(playing: .mediaPlayerKitchen)
        await viewModel.reload()
        XCTAssertFalse(viewModel.isGroupActive)
        // Nothing to promote — the active speaker stays put.
        await viewModel.removeActiveSpeakerFromGroup()
        XCTAssertEqual(viewModel.activeSpeakerID, .mediaPlayerKitchen)
    }

    func testRemoveActiveSpeakerFailureKeepsPrimaryAndBanners() async {
        await reloadGroupedKitchenLeader()
        stubPostService(path: "/api/services/media_player/unjoin", statusCode: 500)
        await viewModel.removeActiveSpeakerFromGroup()
        XCTAssertEqual(viewModel.activeSpeakerID, .mediaPlayerKitchen)
        XCTAssertTrue(bannerTitles.contains("Kunde inte dela upp högtalare"))
    }

    // MARK: - Live updates

    func testReloadKeepsOtherSpeakersWhenOneFailsToDecode() async {
        // Kitchen returns a body that cannot decode into MediaPlayerEntity, hitting
        // reload()'s per-speaker catch; the other speakers must still load.
        stubAllSpeakers(playing: .mediaPlayerLivingRoom)
        let badResponse = HTTPURLResponse(url: speakerURL(.mediaPlayerKitchen),
                                          statusCode: 200, httpVersion: nil, headerFields: nil)!
        URLProtocolStub.setStub(for: speakerURL(.mediaPlayerKitchen),
                                data: Data("not json".utf8), response: badResponse, error: nil)
        await viewModel.reload()

        // Kitchen keeps its initial loading entity; the playing speaker still resolves.
        XCTAssertEqual(viewModel.speakers[.mediaPlayerKitchen]?.state, "Loading")
        XCTAssertEqual(viewModel.activeSpeakerID, .mediaPlayerLivingRoom)
    }

    func testReloadReflectsExternalChanges() async {
        stubAllSpeakers(playing: .mediaPlayerKitchen)
        await viewModel.reload()
        XCTAssertEqual(viewModel.speakers[.mediaPlayerKitchen]?.state, "playing")

        // Someone changes volume + track elsewhere.
        stubSpeaker(.mediaPlayerKitchen,
                    data: speakerJSON(entityID: .mediaPlayerKitchen,
                                      state: "playing",
                                      friendlyName: "Kitchen",
                                      volume: 0.9,
                                      title: trackName,
                                      artist: trackArtist))
        await viewModel.reload()
        XCTAssertEqual(viewModel.speakers[.mediaPlayerKitchen]?.volumeLevel, 0.9)
        XCTAssertEqual(viewModel.speakers[.mediaPlayerKitchen]?.mediaTitle, trackName)
    }

    // MARK: - Playlists

    private var playlistItem: MusicSearchItem {
        MusicSearchItem(uri: "spotify://playlist/p1", name: "Sommar", mediaType: .playlist, imageURL: nil, artist: nil)
    }

    private func browseURL() -> URL {
        var components = URLComponents(string: GlobalConstants.baseInternalUrlString)!
        components.path = "/api/services/media_player/browse_media"
        components.queryItems = [URLQueryItem(name: "return_response", value: "true")]
        return components.url!
    }

    func stubBrowse(json: String, statusCode: Int = 200) {
        let url = browseURL()
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        URLProtocolStub.setStub(for: url, data: Data(json.utf8), response: response, error: nil)
    }

    func testOpenPlaylistDrillsInAndLoadsTracks() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        stubBrowse(json: "{\"service_response\":{\"media_player.kitchen\":{\"children\":" +
            "[{\"title\":\"Song A\",\"media_content_id\":\"spotify://track/a\"}]}}}")
        await viewModel.openPlaylist(playlistItem)
        XCTAssertEqual(viewModel.openedPlaylist, playlistItem)
        XCTAssertEqual(viewModel.playlistTracks.count, 1)
        XCTAssertEqual(viewModel.playlistTracks.first?.uri, "spotify://track/a")
        XCTAssertFalse(viewModel.isLoadingPlaylist)
    }

    func testOpenPlaylistFailureShowsBanner() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        stubBrowse(json: "boom", statusCode: 500)
        await viewModel.openPlaylist(playlistItem)
        XCTAssertTrue(viewModel.playlistTracks.isEmpty)
        XCTAssertTrue(bannerTitles.contains("Kunde inte öppna spellistan"))
        XCTAssertFalse(viewModel.isLoadingPlaylist)
    }

    func testPlayPlaylistStartsPlaybackAndClosesSheet() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        viewModel.isShowingSearchResults = true
        viewModel.openedPlaylist = playlistItem
        stubPlayMedia(statusCode: 200)
        await viewModel.playPlaylist(playlistItem)
        XCTAssertEqual(viewModel.speakers[.mediaPlayerKitchen]?.state, "playing")
        XCTAssertFalse(viewModel.isShowingSearchResults)
        XCTAssertNil(viewModel.openedPlaylist)
    }

    func testPlayRefreshesGroupStateSoStaleLeaderIsNotTargeted() async {
        // Per the last reload, Matbord-ute is grouped under Kitchen as leader, so
        // its stale playback target is Kitchen.
        let staleGroup = [EntityId.mediaPlayerKitchen.rawValue, EntityId.mediaPlayerOutdoorTable.rawValue]
        stubSpeaker(.mediaPlayerOutdoorTable,
                    data: speakerJSON(entityID: .mediaPlayerOutdoorTable, state: "playing",
                                      friendlyName: "Matbord-ute", groupMembers: staleGroup))
        for entityID in MusicViewModel.speakerIDs where entityID != .mediaPlayerOutdoorTable {
            stubSpeaker(entityID, data: speakerJSON(entityID: entityID, state: "idle", friendlyName: entityID.rawValue))
        }
        await viewModel.reload()
        XCTAssertEqual(viewModel.activeSpeakerID, .mediaPlayerOutdoorTable)
        XCTAssertEqual(viewModel.activeSpeaker?.playbackTargetID, .mediaPlayerKitchen)

        // The speakers were ungrouped since that reload; the fresh state is solo.
        stubSpeaker(.mediaPlayerOutdoorTable,
                    data: speakerJSON(entityID: .mediaPlayerOutdoorTable, state: "idle",
                                      friendlyName: "Matbord-ute", groupMembers: []))
        stubPlayMedia(statusCode: 200)
        let item = MusicSearchItem(uri: "spotify://track/x", name: "Song A",
                                   mediaType: .track, imageURL: nil, artist: nil)
        await viewModel.play(item: item)

        // Playback refreshed the active speaker first, so routing now lands on
        // Matbord-ute itself rather than the stale Kitchen leader.
        XCTAssertEqual(viewModel.speakers[.mediaPlayerOutdoorTable]?.groupMembers, [])
        XCTAssertEqual(viewModel.activeSpeaker?.playbackTargetID, .mediaPlayerOutdoorTable)
    }

    func testPlayTrackInPlaylistPlaysTrackThenClosesSheet() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        viewModel.isShowingSearchResults = true
        viewModel.openedPlaylist = playlistItem
        stubPlayMedia(statusCode: 200)
        let track = MusicPlaylistTrack(uri: "spotify://track/a", title: "Song A", imageURL: nil)
        await viewModel.playTrackInPlaylist(track, from: playlistItem)
        XCTAssertEqual(viewModel.speakers[.mediaPlayerKitchen]?.state, "playing")
        XCTAssertEqual(viewModel.speakers[.mediaPlayerKitchen]?.mediaTitle, "Song A")
        XCTAssertFalse(viewModel.isShowingSearchResults)
        XCTAssertNil(viewModel.openedPlaylist)
    }

    func testCloseSearchResultsResetsState() {
        viewModel.isShowingSearchResults = true
        viewModel.openedPlaylist = playlistItem
        viewModel.closeSearchResults()
        XCTAssertFalse(viewModel.isShowingSearchResults)
        XCTAssertNil(viewModel.openedPlaylist)
    }

    func testSearchClearsOpenedPlaylist() async {
        viewModel.openedPlaylist = playlistItem
        stubSearch(json: "{\"tracks\":[{\"uri\":\"spotify://track/a\",\"name\":\"Song A\"}]}")
        viewModel.searchText = "song"
        await viewModel.search()
        XCTAssertNil(viewModel.openedPlaylist)
        XCTAssertTrue(viewModel.isShowingSearchResults)
    }
}
