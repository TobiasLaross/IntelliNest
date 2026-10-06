@testable import IntelliNest
import XCTest

@MainActor
extension MusicViewModelTests {
    func activityState(isPlaying: Bool = true,
                       position: Double? = 30,
                       groupVolume: Double = 0.4) -> MusicActivityAttributes.ContentState {
        MusicActivityAttributes.ContentState(title: "Ha dig igen",
                                             artist: "Victor Leksell",
                                             roomName: "Köket +2",
                                             isPlaying: isPlaying,
                                             position: position,
                                             positionDate: Date(timeIntervalSince1970: 1000),
                                             duration: 173,
                                             groupVolume: groupVolume,
                                             transportTargetID: EntityId.mediaPlayerKitchen.rawValue,
                                             volumeSpeakerIDs: [EntityId.mediaPlayerKitchen.rawValue,
                                                                EntityId.mediaPlayerPlayroom.rawValue])
    }

    private func postedBodies(_ requests: [URLRequest]) -> [[String: Any]] {
        requests.compactMap { request in
            let data = request.httpBodyStreamData() ?? request.httpBody
            return data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
        }
    }

    // MARK: - Snapshot

    func testLiveActivitySnapshotFollowsTheGroupAndAveragesItsVolume() async {
        await reloadGroupedKitchenLeader()
        viewModel.speakers[.mediaPlayerKitchen]?.mediaTitle = "Ha dig igen"

        let snapshot = viewModel.liveActivitySnapshot()

        XCTAssertEqual(snapshot?.state.roomName, "Köket +2")
        XCTAssertEqual(snapshot?.state.transportTargetID, EntityId.mediaPlayerKitchen.rawValue)
        XCTAssertEqual(snapshot?.state.volumeSpeakerIDs, [EntityId.mediaPlayerKitchen.rawValue,
                                                          EntityId.mediaPlayerPlayroom.rawValue,
                                                          EntityId.mediaPlayerOutdoorTable.rawValue])
        XCTAssertEqual(snapshot?.state.groupVolume ?? 0, 0.12, accuracy: 0.0001)
    }

    func testLiveActivitySnapshotUsesTheShownTrack() async {
        for entityID in MusicViewModel.speakerIDs {
            let isKitchen = entityID == .mediaPlayerKitchen
            stubSpeaker(entityID, data: speakerJSON(entityID: entityID,
                                                    state: isKitchen ? "paused" : "idle",
                                                    friendlyName: "Köket",
                                                    title: isKitchen ? "Ha dig igen" : nil,
                                                    artist: isKitchen ? "Victor Leksell" : nil,
                                                    entityPicture: isKitchen ? "/api/media_player_proxy/media_player.kitchen" : nil))
        }
        await viewModel.reload()
        viewModel.selectSpeaker(.mediaPlayerKitchen)

        let snapshot = viewModel.liveActivitySnapshot()

        XCTAssertEqual(snapshot?.state.title, "Ha dig igen")
        XCTAssertEqual(snapshot?.state.artist, "Victor Leksell")
        XCTAssertEqual(snapshot?.state.isPlaying, false)
        XCTAssertEqual(snapshot?.state.roomName, "Köket")
        XCTAssertEqual(snapshot?.artworkPath, "/api/media_player_proxy/media_player.kitchen")
    }

    func testLiveActivitySnapshotIsNilWhenNothingPlays() async {
        stubAllSpeakers()
        await viewModel.reload()

        XCTAssertNil(viewModel.liveActivitySnapshot())
    }

    func testLiveActivitySnapshotIsNilWhileTheAppleTVIsOn() async {
        stubAllSpeakers(playing: .mediaPlayerKitchen)
        stubTwin(for: .mediaPlayerLivingRoom,
                 state: "playing",
                 title: "TV",
                 contentID: "x-sonos-htastream:RINCON_F0F6C1705FFD01400:spdif")
        await viewModel.reload()
        viewModel.speakers[.mediaPlayerKitchen]?.mediaTitle = "Ha dig igen"

        XCTAssertNil(viewModel.liveActivitySnapshot())
    }

    // MARK: - Content state

    func testVolumeStepStaysWithinRange() {
        struct VolumeCase {
            let start: Double
            let raising: Bool
            let expected: Double
        }
        let cases = [
            VolumeCase(start: 0.4, raising: true, expected: 0.45),
            VolumeCase(start: 0.4, raising: false, expected: 0.35),
            VolumeCase(start: 0.98, raising: true, expected: 1),
            VolumeCase(start: 0.02, raising: false, expected: 0)
        ]
        for testCase in cases {
            let stepped = activityState(groupVolume: testCase.start).steppingVolume(raising: testCase.raising)
            XCTAssertEqual(stepped.groupVolume, testCase.expected, accuracy: 0.0001, "\(testCase)")
        }
    }

    func testPausingFreezesTheProgressWhereItIs() {
        let now = Date(timeIntervalSince1970: 1010)

        let paused = activityState(isPlaying: true, position: 30).togglingPlayback(asOf: now)

        XCTAssertFalse(paused.isPlaying)
        XCTAssertEqual(paused.position, 40)
        XCTAssertEqual(paused.positionDate, now)
        XCTAssertEqual(paused.elapsed(asOf: Date(timeIntervalSince1970: 2000)), 40)
    }

    func testElapsedIsClampedToTheTrackLength() {
        XCTAssertEqual(activityState().elapsed(asOf: Date(timeIntervalSince1970: 5000)), 173)
    }

    // MARK: - Commands

    func testVolumeStepSetsEveryGroupedSpeakerToTheSameLevel() async {
        let path = "/api/services/media_player/volume_set"
        stubPostService(path: path)
        let recorder = RequestRecorder { $0.httpMethod == "POST" && $0.url?.path == path }

        await MusicActivityCommandSender(restAPIService: restAPIService).send(.volumeUp, for: activityState(groupVolume: 0.4))

        let bodies = postedBodies(recorder.requests)
        XCTAssertEqual(Set(bodies.compactMap { $0["entity_id"] as? String }),
                       [EntityId.mediaPlayerKitchen.rawValue, EntityId.mediaPlayerPlayroom.rawValue])
        XCTAssertEqual(bodies.compactMap { $0["volume_level"] as? Double }, [0.45, 0.45])
    }

    func testTransportCommandsGoToTheTransportTarget() async {
        struct TransportCase {
            let command: MusicActivityCommand
            let isPlaying: Bool
            let service: String
        }
        let cases = [
            TransportCase(command: .playPause, isPlaying: true, service: "media_pause"),
            TransportCase(command: .playPause, isPlaying: false, service: "media_play"),
            TransportCase(command: .nextTrack, isPlaying: true, service: "media_next_track"),
            TransportCase(command: .previousTrack, isPlaying: true, service: "media_previous_track")
        ]
        for testCase in cases {
            let path = "/api/services/media_player/\(testCase.service)"
            stubPostService(path: path)
            let recorder = RequestRecorder { $0.httpMethod == "POST" && $0.url?.path == path }

            await MusicActivityCommandSender(restAPIService: restAPIService)
                .send(testCase.command, for: activityState(isPlaying: testCase.isPlaying))

            XCTAssertEqual(postedBodies(recorder.requests).compactMap { $0["entity_id"] as? String },
                           [EntityId.mediaPlayerKitchen.rawValue], "\(testCase)")
        }
    }
}

@MainActor
extension MusicViewModelTests {
    func testRelayRegistrationCarriesTheTokensAndState() async throws {
        let relayURLString = "http://192.168.1.203:3000"
        let url = try XCTUnwrap(URL(string: relayURLString + "/live-activity/register"))
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        URLProtocolStub.setStub(for: url, data: Data(), response: response, error: nil)
        let recorder = RequestRecorder { $0.url == url }
        let relay = MusicActivityRelay(baseURLString: relayURLString,
                                       secret: "4f1d9c2a7b3e8f60",
                                       session: URLProtocolStub.createStubbedURLSession())
        let state = activityState()

        await relay.register(pushToken: "8a1f3c", deviceToken: "5b2e7d", state: state)

        let request = try XCTUnwrap(recorder.requests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer 4f1d9c2a7b3e8f60")
        let body = try XCTUnwrap((request.httpBodyStreamData() ?? request.httpBody)
            .flatMap { try JSONSerialization.jsonObject(with: $0) as? [String: Any] })
        XCTAssertEqual(body["push_token"] as? String, "8a1f3c")
        XCTAssertEqual(body["device_token"] as? String, "5b2e7d")
        let stateData = try JSONSerialization.data(withJSONObject: XCTUnwrap(body["content_state"]))
        XCTAssertEqual(try JSONDecoder().decode(MusicActivityAttributes.ContentState.self, from: stateData), state)
    }

    // MARK: - Tap link

    func testLiveActivityLinkOnlyMatchesTheNowPlayingURL() throws {
        let nowPlayingURL = try XCTUnwrap(MusicActivityLink.nowPlayingURL)
        XCTAssertTrue(MusicActivityLink.isNowPlaying(nowPlayingURL))

        let cases: [(url: String, matches: Bool)] = [
            ("intellinest://now-playing", true),
            ("IntelliNest://start-car-heater", false),
            ("IntelliNest://snoozeWashingMachine", false),
            ("https://now-playing", false)
        ]
        for testCase in cases {
            let url = try XCTUnwrap(URL(string: testCase.url))
            XCTAssertEqual(MusicActivityLink.isNowPlaying(url), testCase.matches, testCase.url)
        }
    }
}
