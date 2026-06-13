@testable import IntelliNest
import XCTest

// MARK: - Playback, transport & volume

@MainActor
extension MusicViewModelTests {
    // MARK: - Play

    func stubPlayMedia(statusCode: Int) {
        var components = URLComponents(string: GlobalConstants.baseInternalUrlString)!
        components.path = "/api/services/music_assistant/play_media"
        let url = components.url!
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        URLProtocolStub.setStub(for: url, data: Data("[]".utf8), response: response, error: nil)
    }

    func testPlayOnActiveSpeakerSetsPlayingState() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        stubPlayMedia(statusCode: 200)
        let item = MusicSearchItem(uri: trackURI, name: trackName, mediaType: .track,
                                   imageURL: nil, artist: trackArtist)
        await viewModel.play(item: item)
        XCTAssertEqual(viewModel.speakers[.mediaPlayerKitchen]?.state, "playing")
        XCTAssertEqual(viewModel.speakers[.mediaPlayerKitchen]?.mediaTitle, trackName)
        XCTAssertTrue(bannerTitles.isEmpty)
    }

    func testPlayFailureKeepsNoFalsePlayingState() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        // Kitchen currently idle.
        viewModel.speakers[.mediaPlayerKitchen]?.state = "idle"
        stubPlayMedia(statusCode: 500)
        let item = MusicSearchItem(uri: trackURI, name: trackName, mediaType: .track,
                                   imageURL: nil, artist: trackArtist)
        await viewModel.play(item: item)
        XCTAssertNotEqual(viewModel.speakers[.mediaPlayerKitchen]?.state, "playing")
        XCTAssertTrue(bannerTitles.contains("Kunde inte spela"))
    }

    func testPlayWithoutActiveSpeakerShowsBanner() async {
        let item = MusicSearchItem(uri: trackURI, name: trackName, mediaType: .track,
                                   imageURL: nil, artist: trackArtist)
        await viewModel.play(item: item)
        XCTAssertTrue(bannerTitles.contains("Ingen högtalare vald"))
    }

    // MARK: - Transport

    func testTogglePlayPause_pausesWhenPlaying() async {
        stubAllSpeakers(playing: .mediaPlayerKitchen)
        await viewModel.reload()
        let expectation = XCTestExpectation(description: "POST media_pause")
        URLProtocolStub.observerRequests { request in
            if request.httpMethod == "POST", request.url?.path.contains("/media_pause") == true {
                expectation.fulfill()
            }
        }
        stubPostService(path: "/api/services/media_player/media_pause")
        viewModel.togglePlayPause()
        XCTAssertEqual(viewModel.speakers[.mediaPlayerKitchen]?.state, "paused")
        await fulfillment(of: [expectation], timeout: 2.0)
    }

    func testTogglePlayPause_playsWhenPaused() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        viewModel.speakers[.mediaPlayerKitchen]?.state = "paused"
        let expectation = XCTestExpectation(description: "POST media_play")
        URLProtocolStub.observerRequests { request in
            if request.httpMethod == "POST", request.url?.path.contains("/media_play") == true {
                expectation.fulfill()
            }
        }
        stubPostService(path: "/api/services/media_player/media_play")
        viewModel.togglePlayPause()
        XCTAssertEqual(viewModel.speakers[.mediaPlayerKitchen]?.state, "playing")
        await fulfillment(of: [expectation], timeout: 2.0)
    }

    func testNextAndPreviousTrack() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        let cases: [(action: () -> Void, path: String)] = [
            (viewModel.nextTrack, "/api/services/media_player/media_next_track"),
            (viewModel.previousTrack, "/api/services/media_player/media_previous_track")
        ]
        for testCase in cases {
            let expectation = XCTestExpectation(description: "POST \(testCase.path)")
            URLProtocolStub.observerRequests { request in
                if request.httpMethod == "POST", request.url?.path == testCase.path {
                    expectation.fulfill()
                }
            }
            stubPostService(path: testCase.path)
            testCase.action()
            await fulfillment(of: [expectation], timeout: 2.0)
        }
    }

    func testTransportWithoutActiveSpeakerDoesNothing() {
        // No active speaker; these must be no-ops (no crash).
        viewModel.togglePlayPause()
        viewModel.nextTrack()
        viewModel.previousTrack()
        viewModel.setVolume(0.5)
        viewModel.toggleShuffle()
        viewModel.toggleRepeat()
        XCTAssertNil(viewModel.activeSpeakerID)
    }

    // MARK: - Volume

    func testSetVolumeUpdatesStateAndPosts() async {
        viewModel.selectSpeaker(.mediaPlayerGuestRoom)
        let expectation = XCTestExpectation(description: "POST volume_set")
        URLProtocolStub.observerRequests { request in
            if request.httpMethod == "POST", request.url?.path.contains("/volume_set") == true {
                expectation.fulfill()
            }
        }
        stubPostService(path: "/api/services/media_player/volume_set")
        viewModel.setVolume(0.75)
        XCTAssertEqual(viewModel.speakers[.mediaPlayerGuestRoom]?.volumeLevel, 0.75)
        await fulfillment(of: [expectation], timeout: 2.0)
    }

    func testSetVolumeForSpecificSpeakerAdjustsThatSpeakerWithoutSelecting() async {
        // No active speaker — volume can still be set on any speaker in place.
        let expectation = XCTestExpectation(description: "POST volume_set")
        URLProtocolStub.observerRequests { request in
            if request.httpMethod == "POST", request.url?.path.contains("/volume_set") == true {
                expectation.fulfill()
            }
        }
        stubPostService(path: "/api/services/media_player/volume_set")
        viewModel.setVolume(0.42, for: .mediaPlayerSpa)
        XCTAssertEqual(viewModel.speakers[.mediaPlayerSpa]?.volumeLevel, 0.42)
        XCTAssertNil(viewModel.activeSpeakerID)
        await fulfillment(of: [expectation], timeout: 2.0)
    }

    // MARK: - Shuffle / Repeat

    func testToggleShuffle() async {
        viewModel.selectSpeaker(.mediaPlayerPlayroom)
        viewModel.speakers[.mediaPlayerPlayroom]?.shuffle = false
        let expectation = XCTestExpectation(description: "POST shuffle_set")
        URLProtocolStub.observerRequests { request in
            if request.httpMethod == "POST", request.url?.path.contains("/shuffle_set") == true {
                expectation.fulfill()
            }
        }
        stubPostService(path: "/api/services/media_player/shuffle_set")
        viewModel.toggleShuffle()
        XCTAssertEqual(viewModel.speakers[.mediaPlayerPlayroom]?.shuffle, true)
        await fulfillment(of: [expectation], timeout: 2.0)
    }

    func testToggleRepeatCyclesOffAllOne() async {
        viewModel.selectSpeaker(.mediaPlayerPlayroom)
        stubPostService(path: "/api/services/media_player/repeat_set")

        viewModel.speakers[.mediaPlayerPlayroom]?.repeatMode = .off
        viewModel.toggleRepeat()
        XCTAssertEqual(viewModel.speakers[.mediaPlayerPlayroom]?.repeatMode, .all)
        viewModel.toggleRepeat()
        XCTAssertEqual(viewModel.speakers[.mediaPlayerPlayroom]?.repeatMode, .one)
        viewModel.toggleRepeat()
        XCTAssertEqual(viewModel.speakers[.mediaPlayerPlayroom]?.repeatMode, .off)
    }

    // MARK: - Helpers

    func stubPostService(path: String, statusCode: Int = 200) {
        var components = URLComponents(string: GlobalConstants.baseInternalUrlString)!
        components.path = path
        let url = components.url!
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        URLProtocolStub.setStub(for: url, data: Data(), response: response, error: nil)
    }
}
