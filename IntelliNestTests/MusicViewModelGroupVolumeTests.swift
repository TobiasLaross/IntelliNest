@testable import IntelliNest
import XCTest

@MainActor
extension MusicViewModelTests {
    // MARK: - Group volume

    /// Reloads with Kitchen as group leader synced to Playroom and Matbord-ute,
    /// each at a distinct volume, and returns the active speaker. Shared with the
    /// live-update tests in `MusicViewModelGroupingTests`.
    func reloadGroupedKitchenLeader() async {
        let leaderMembers = [EntityId.mediaPlayerKitchen.rawValue,
                             EntityId.mediaPlayerPlayroom.rawValue,
                             EntityId.mediaPlayerOutdoorTable.rawValue]
        stubSpeaker(.mediaPlayerKitchen,
                    data: speakerJSON(entityID: .mediaPlayerKitchen, state: "playing",
                                      friendlyName: "Köket", volume: 0.06, groupMembers: leaderMembers))
        stubSpeaker(.mediaPlayerPlayroom,
                    data: speakerJSON(entityID: .mediaPlayerPlayroom, state: "playing",
                                      friendlyName: "Lekrummet", volume: 0.12, groupMembers: leaderMembers))
        stubSpeaker(.mediaPlayerOutdoorTable,
                    data: speakerJSON(entityID: .mediaPlayerOutdoorTable, state: "playing",
                                      friendlyName: "Matbord-ute", volume: 0.18, groupMembers: leaderMembers))
        for entityID in [EntityId.mediaPlayerGuestRoom, .mediaPlayerLivingRoom, .mediaPlayerSpa] {
            stubSpeaker(entityID, data: speakerJSON(entityID: entityID, state: "idle",
                                                    friendlyName: entityID.rawValue, volume: 0.3))
        }
        await viewModel.reload()
    }

    func testGroupedSpeakersAndAverageVolume() async {
        await reloadGroupedKitchenLeader()
        XCTAssertEqual(viewModel.activeSpeakerID, .mediaPlayerKitchen)
        XCTAssertTrue(viewModel.isGroupActive)
        XCTAssertEqual(viewModel.groupedSpeakers.map(\.entityId),
                       [.mediaPlayerKitchen, .mediaPlayerPlayroom, .mediaPlayerOutdoorTable])
        // Average of 0.06, 0.12, 0.18.
        XCTAssertEqual(viewModel.groupVolume, 0.12, accuracy: 0.0001)
    }

    func testUngroupedSpeakerIsNotGroupActive() async {
        stubAllSpeakers(playing: .mediaPlayerKitchen)
        await viewModel.reload()
        XCTAssertFalse(viewModel.isGroupActive)
        XCTAssertEqual(viewModel.groupedSpeakers.map(\.entityId), [.mediaPlayerKitchen])
        XCTAssertEqual(viewModel.groupVolume, viewModel.activeSpeaker?.volumeLevel)
    }

    func testSetGroupVolumeUpdatesEveryGroupedSpeakerOnly() async {
        await reloadGroupedKitchenLeader()
        stubPostService(path: "/api/services/media_player/volume_set")
        viewModel.setGroupVolume(0.5)
        // Every grouped speaker is set to the new level…
        XCTAssertEqual(viewModel.speakers[.mediaPlayerKitchen]?.volumeLevel, 0.5)
        XCTAssertEqual(viewModel.speakers[.mediaPlayerPlayroom]?.volumeLevel, 0.5)
        XCTAssertEqual(viewModel.speakers[.mediaPlayerOutdoorTable]?.volumeLevel, 0.5)
        // …while an ungrouped speaker keeps its own volume.
        XCTAssertEqual(viewModel.speakers[.mediaPlayerSpa]?.volumeLevel, 0.3)
    }

    // MARK: - Recently-played playlists

    private func recentsURL() -> URL {
        var components = URLComponents(string: GlobalConstants.baseInternalUrlString)!
        components.path = "/api/services/music_assistant/get_library"
        components.queryItems = [URLQueryItem(name: "return_response", value: "true")]
        return components.url!
    }

    private func stubRecents(json: String, statusCode: Int = 200) {
        let url = recentsURL()
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        URLProtocolStub.setStub(for: url, data: Data(json.utf8), response: response, error: nil)
    }

    func testRecentlyPlayedPlaylistsLoadOnReload() async {
        stubAllSpeakers(playing: .mediaPlayerKitchen)
        stubRecents(json: "{\"service_response\":{\"items\":[" +
            "{\"uri\":\"spotify://playlist/1\",\"name\":\"Bastumusik\"}," +
            "{\"uri\":\"spotify://playlist/2\",\"name\":\"Träning\"}]}}")
        await viewModel.reload()
        XCTAssertEqual(viewModel.recentlyPlayedPlaylists.map(\.name), ["Bastumusik", "Träning"])
        XCTAssertTrue(viewModel.recentlyPlayedPlaylists.allSatisfy { $0.mediaType == .playlist })
        // Favourites now come from the Spotify account, not Music Assistant, so the
        // default (disabled, logged-out) Spotify service leaves them empty.
        XCTAssertTrue(viewModel.favoritePlaylists.isEmpty)
    }

    func testPlayPlaylistRefreshesRecents() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        viewModel.isShowingSearchResults = true
        stubPlayMedia(statusCode: 200)
        stubRecents(json: "{\"service_response\":{\"items\":[" +
            "{\"uri\":\"spotify://playlist/1\",\"name\":\"Bastumusik\"}]}}")
        let playlist = MusicSearchItem(uri: "spotify://playlist/1", name: "Bastumusik",
                                       mediaType: .playlist, imageURL: nil, artist: nil)
        await viewModel.playPlaylist(playlist)
        XCTAssertEqual(viewModel.speakers[.mediaPlayerKitchen]?.state, "playing")
        // Playing closes the sheet and the post-play refresh repopulated recents.
        XCTAssertFalse(viewModel.isShowingSearchResults)
        XCTAssertEqual(viewModel.recentlyPlayedPlaylists.map(\.name), ["Bastumusik"])
    }

    func testBrowseLibraryPlaylistOpensSheetAndLoadsTracks() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        stubBrowse(json: "{\"service_response\":{\"media_player.kitchen\":{\"children\":" +
            "[{\"title\":\"Song A\",\"media_content_id\":\"spotify://track/a\"}]}}}")
        let favorite = MusicSearchItem(uri: "spotify://playlist/p1", name: "Bastumusik",
                                       mediaType: .playlist, imageURL: nil, artist: nil)
        await viewModel.browseLibraryPlaylist(favorite)
        XCTAssertEqual(viewModel.browsingLibraryPlaylist, favorite)
        XCTAssertEqual(viewModel.playlistTracks.first?.uri, "spotify://track/a")
        // Closing clears the browse sheet.
        viewModel.closeSearchResults()
        XCTAssertNil(viewModel.browsingLibraryPlaylist)
    }
}
