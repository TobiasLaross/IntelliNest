@testable import IntelliNest
import XCTest

/// Several rooms playing different music at once: the mini player's pages, each
/// room's own source playlist, and play/pause for a room that isn't controlled.
@MainActor
extension MusicViewModelTests {
    // MARK: - Parallel playback

    func testEachRoomKeepsItsOwnSourcePlaylist() async {
        let kitchenPlaylist = MusicSearchItem(uri: "spotify://playlist/k1", name: "Pippi Långstrump",
                                              mediaType: .playlist, imageURL: nil, artist: nil)
        let guestPlaylist = MusicSearchItem(uri: "spotify://playlist/g1", name: "Lugnt & Skönt",
                                            mediaType: .playlist, imageURL: nil, artist: nil)
        stubPlayMedia(statusCode: 200)

        viewModel.selectSpeaker(.mediaPlayerKitchen)
        await viewModel.playPlaylist(kitchenPlaylist)
        viewModel.selectSpeaker(.mediaPlayerGuestRoom)
        await viewModel.playPlaylist(guestPlaylist)

        XCTAssertEqual(viewModel.nowPlayingSourcePlaylist?.uri, guestPlaylist.uri)
        XCTAssertEqual(viewModel.sourcePlaylist(for: .mediaPlayerKitchen)?.uri, kitchenPlaylist.uri)
        XCTAssertEqual(viewModel.speakers[.mediaPlayerKitchen]?.state, "playing",
                       "Starting music in the guest room must leave the kitchen playing")

        viewModel.selectSpeaker(.mediaPlayerKitchen)
        XCTAssertEqual(viewModel.nowPlayingSourcePlaylist?.uri, kitchenPlaylist.uri)
    }

    func testAGroupedRoomShowsItsLeadersSource() {
        let leaderPlaylist = MusicSearchItem(uri: "spotify://playlist/l1", name: "Sommarklassiker",
                                             mediaType: .playlist, imageURL: nil, artist: nil)
        let stalePlaylist = MusicSearchItem(uri: "spotify://playlist/s1", name: "Brynäs",
                                            mediaType: .playlist, imageURL: nil, artist: nil)
        let group = [EntityId.mediaPlayerGuestRoom, .mediaPlayerKitchen]
        viewModel.speakers[.mediaPlayerKitchen]?.groupMembers = group
        viewModel.speakers[.mediaPlayerGuestRoom]?.groupMembers = group
        viewModel.sourcePlaylistsBySpeaker = [.mediaPlayerGuestRoom: leaderPlaylist, .mediaPlayerKitchen: stalePlaylist]

        XCTAssertEqual(viewModel.sourcePlaylist(for: .mediaPlayerKitchen)?.uri, leaderPlaylist.uri)
    }

    func testAFollowerInControlRecordsAndClearsTheGroupsSource() {
        let started = MusicSearchItem(uri: "spotify://playlist/n1", name: "Morgonkaffe",
                                      mediaType: .playlist, imageURL: nil, artist: nil)
        let stale = MusicSearchItem(uri: "spotify://playlist/s1", name: "Brynäs",
                                    mediaType: .playlist, imageURL: nil, artist: nil)
        let group = [EntityId.mediaPlayerGuestRoom, .mediaPlayerKitchen]
        viewModel.speakers[.mediaPlayerKitchen]?.groupMembers = group
        viewModel.speakers[.mediaPlayerGuestRoom]?.groupMembers = group
        viewModel.sourcePlaylistsBySpeaker = [.mediaPlayerGuestRoom: stale]
        viewModel.selectSpeaker(.mediaPlayerKitchen)

        viewModel.nowPlayingSourcePlaylist = started
        XCTAssertEqual(viewModel.nowPlayingSourcePlaylist?.uri, started.uri,
                       "A follower starting a playlist must replace the leader's stale source")

        viewModel.nowPlayingSourcePlaylist = nil
        XCTAssertNil(viewModel.nowPlayingSourcePlaylist)
        XCTAssertNil(viewModel.sourcePlaylist(for: .mediaPlayerGuestRoom))
    }

    func testMiniPlayerPagesThroughPlayingRoomsAndTheControlledOne() async {
        struct Case {
            let playing: Set<EntityId>
            let active: EntityId?
            let expected: [EntityId]
        }
        let cases = [
            Case(playing: [.mediaPlayerKitchen, .mediaPlayerGuestRoom], active: .mediaPlayerKitchen,
                 expected: [.mediaPlayerKitchen, .mediaPlayerGuestRoom]),
            Case(playing: [.mediaPlayerKitchen], active: .mediaPlayerSpa, expected: [.mediaPlayerKitchen, .mediaPlayerSpa]),
            Case(playing: [], active: .mediaPlayerPlayroom, expected: [.mediaPlayerPlayroom]),
            Case(playing: [], active: nil, expected: [])
        ]
        for testCase in cases {
            for entityID in MusicViewModel.speakerIDs {
                stubSpeaker(entityID, data: speakerJSON(entityID: entityID,
                                                        state: testCase.playing.contains(entityID) ? "playing" : "idle",
                                                        friendlyName: entityID.rawValue,
                                                        activeQueue: "queue"))
            }
            await viewModel.reloadSpeakers()
            viewModel.activeSpeakerID = testCase.active
            XCTAssertEqual(viewModel.miniPlayerRooms.map(\.id), testCase.expected,
                           "playing \(testCase.playing), active \(String(describing: testCase.active))")
        }
    }

    func testPausingAnotherRoomLeavesTheControlledRoomAlone() async {
        let path = "/api/services/media_player/media_pause"
        stubAllSpeakers()
        for entityID in [EntityId.mediaPlayerKitchen, .mediaPlayerGuestRoom] {
            stubSpeaker(entityID, data: speakerJSON(entityID: entityID, state: "playing",
                                                    friendlyName: entityID.rawValue, activeQueue: "queue"))
        }
        await viewModel.reload()
        viewModel.selectSpeaker(.mediaPlayerGuestRoom)

        let recorder = RequestRecorder { $0.httpMethod == "POST" && $0.url?.path == path }
        stubPostService(path: path)
        viewModel.togglePlayPause(for: .mediaPlayerKitchen)
        await restAPIService.lastCommandTask?.value
        let postedIDs = recorder.requests.compactMap { request -> String? in
            let data = request.httpBodyStreamData() ?? request.httpBody
            let body = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
            return body?["entity_id"] as? String
        }

        XCTAssertEqual(postedIDs, [EntityId.mediaPlayerKitchen.rawValue])
        XCTAssertEqual(viewModel.speakers[.mediaPlayerKitchen]?.state, "paused")
        XCTAssertEqual(viewModel.speakers[.mediaPlayerGuestRoom]?.state, "playing")
        XCTAssertEqual(viewModel.activeSpeakerID, .mediaPlayerGuestRoom)
    }

    func testSelectingTheControlledGroupKeepsTheFollowerInControl() async {
        stubAllSpeakers()
        let group = [EntityId.mediaPlayerPlayroom.rawValue, EntityId.mediaPlayerKitchen.rawValue]
        for entityID in [EntityId.mediaPlayerKitchen, .mediaPlayerPlayroom] {
            stubSpeaker(entityID, data: speakerJSON(entityID: entityID, state: "playing",
                                                    friendlyName: entityID.rawValue, groupMembers: group))
        }
        await viewModel.reload()
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        let groupEntry = viewModel.speakerPickerEntries.first { $0.isGroup }

        viewModel.selectRoom(groupEntry!)

        XCTAssertEqual(viewModel.activeSpeakerID, .mediaPlayerKitchen)
        XCTAssertEqual(viewModel.controlledSpeakerID(in: groupEntry!), .mediaPlayerKitchen)
        XCTAssertEqual(viewModel.controlledRoomTitle, "\(EntityId.mediaPlayerKitchen.rawValue) + \(EntityId.mediaPlayerPlayroom.rawValue)")
    }

    // MARK: - Room status

    func testRoomStatusText() {
        struct Case {
            let state: String
            var title: String?
            var artist: String?
            var queue: String? = "queue"
            let expected: String
        }
        let cases = [
            Case(state: "playing", title: "Black Car", artist: "Miriam Bryant", expected: "Black Car · Miriam Bryant"),
            Case(state: "playing", expected: "Spelar"),
            Case(state: "paused", title: "Black Car", expected: "Pausad · Black Car"),
            Case(state: "playing", title: "TV", queue: nil, expected: "Annan app · TV"),
            Case(state: "idle", title: "Black Car", expected: "Tyst")
        ]
        for testCase in cases {
            var speaker = MediaPlayerEntity(entityId: .mediaPlayerKitchen, state: testCase.state, friendlyName: "Köket")
            speaker.mediaTitle = testCase.title
            speaker.mediaArtist = testCase.artist
            speaker.activeQueueID = testCase.queue
            XCTAssertEqual(speaker.roomStatusText, testCase.expected, "\(testCase)")
        }
    }

    // MARK: - Start screen

    func testShortcutGridShowsTheSixMostRecentAndTheCardsSkipRecents() {
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false))
        model.recentlyPlayedPlaylists = (1 ... 8).map {
            MusicSearchItem(uri: "spotify://playlist/r\($0)", name: "Lista \($0)", mediaType: .playlist, imageURL: nil, artist: nil)
        }
        model.favoritePlaylists = [MusicSearchItem(uri: "spotify://playlist/f1", name: "Husets",
                                                   mediaType: .playlist, imageURL: nil, artist: nil)]

        XCTAssertEqual(model.shortcutPlaylists.map(\.name), (1 ... 6).map { "Lista \($0)" })
        XCTAssertEqual(model.homeLibrarySections.map(\.title), ["Favoriter"])
        XCTAssertEqual(model.recentlyPlayedSection?.playlists.count, 8)
    }

    func testSearchListsAPlaylistFoundInSeveralSectionsOnce() {
        let model = makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false))
        let shared = MusicSearchItem(uri: "spotify://playlist/v1", name: "Victor Leksell/Miriam Bryant",
                                     mediaType: .playlist, imageURL: nil, artist: nil)
        model.recentlyPlayedPlaylists = [shared]
        model.favoritePlaylists = [shared,
                                   MusicSearchItem(uri: "spotify://playlist/v2", name: "Victor live",
                                                   mediaType: .playlist, imageURL: nil, artist: nil)]

        model.searchText = "victor"

        XCTAssertEqual(model.librarySections.map(\.title), ["Senast spelade", "Favoriter"])
        XCTAssertEqual(model.librarySections.map { $0.playlists.map(\.uri) },
                       [["spotify://playlist/v1"], ["spotify://playlist/v2"]])
    }
}
