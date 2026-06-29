@testable import IntelliNest
import XCTest

// MARK: - Seek / scrubber

@MainActor
extension MusicViewModelTests {
    func testSeekRoutesToGroupLeaderWithPosition() async {
        // Kitchen is synced into a group led by the living room; transport (and seek)
        // must target the leader.
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        viewModel.speakers[.mediaPlayerKitchen]?.groupMembers = [.mediaPlayerLivingRoom, .mediaPlayerKitchen]

        let expectation = XCTestExpectation(description: "POST media_seek")
        var capturedBody: [String: Any]?
        URLProtocolStub.observerRequests { request in
            if request.httpMethod == "POST", request.url?.path.contains("/media_seek") == true {
                let data = request.httpBodyStreamData() ?? request.httpBody
                capturedBody = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
                expectation.fulfill()
            }
        }
        stubPostService(path: "/api/services/media_player/media_seek")

        viewModel.seek(to: 42)

        // Optimistic position lands on the selected speaker so the UI jumps at once.
        XCTAssertEqual(viewModel.speakers[.mediaPlayerKitchen]?.mediaPosition, 42)
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertEqual(capturedBody?["entity_id"] as? String, EntityId.mediaPlayerLivingRoom.rawValue)
        XCTAssertEqual(capturedBody?["seek_position"] as? Double, 42)
    }

    func testSeekWithoutActiveSpeakerIsNoOp() async {
        let noRequest = XCTestExpectation(description: "no media_seek request")
        noRequest.isInverted = true
        URLProtocolStub.observerRequests { request in
            if request.url?.path.contains("/media_seek") == true {
                noRequest.fulfill()
            }
        }
        viewModel.seek(to: 10)
        XCTAssertNil(viewModel.activeSpeakerID)
        XCTAssertNil(viewModel.speakers[.mediaPlayerKitchen]?.mediaPosition)
        await fulfillment(of: [noRequest], timeout: 0.5)
    }

    func testSeekRegistersPositionHold() async {
        viewModel.selectSpeaker(.mediaPlayerSpa)
        viewModel.speakers[.mediaPlayerSpa] = MediaPlayerEntity(entityId: .mediaPlayerSpa, state: "playing", friendlyName: "Spa")
        // Await the fired request so the async seek Task can't bleed a stray media_seek
        // POST into a sibling test sharing the process-global URLProtocolStub.
        let sent = transportExpectation(path: "/media_seek")
        stubPostService(path: "/api/services/media_player/media_seek")

        viewModel.seek(to: 42)

        // The hold keeps the seeked spot through the reloads that still report the
        // pre-seek position, so the scrubber doesn't snap back.
        XCTAssertEqual(viewModel.positionHold?.target ?? -1, 42, accuracy: 0.001)
        await fulfillment(of: [sent], timeout: 2.0)
    }

    func testPauseHoldsTheLivePositionSoItCannotSnapToZero() async {
        var speaker = MediaPlayerEntity(entityId: .mediaPlayerSpa, state: "playing", friendlyName: "Spa")
        speaker.mediaPosition = 30
        speaker.mediaPositionUpdatedAt = Date()
        viewModel.speakers[.mediaPlayerSpa] = speaker
        viewModel.activeSpeakerID = .mediaPlayerSpa
        let sent = transportExpectation(path: "/media_pause")
        stubPostService(path: "/api/services/media_player/media_pause")

        viewModel.togglePlayPause()

        XCTAssertEqual(viewModel.speakers[.mediaPlayerSpa]?.state, "paused")
        XCTAssertEqual(viewModel.positionHold?.target ?? -1, 30, accuracy: 0.5)
        XCTAssertEqual(viewModel.speakers[.mediaPlayerSpa]?.mediaPosition ?? -1, 30, accuracy: 0.5)
        await fulfillment(of: [sent], timeout: 2.0)
    }

    func testResumeClearsThePositionHold() async {
        var speaker = MediaPlayerEntity(entityId: .mediaPlayerSpa, state: "paused", friendlyName: "Spa")
        speaker.mediaPosition = 30
        viewModel.speakers[.mediaPlayerSpa] = speaker
        viewModel.activeSpeakerID = .mediaPlayerSpa
        viewModel.positionHold = PlaybackPositionHold(target: 30, since: Date())
        let sent = transportExpectation(path: "/media_play")
        stubPostService(path: "/api/services/media_player/media_play")

        viewModel.togglePlayPause()

        XCTAssertEqual(viewModel.speakers[.mediaPlayerSpa]?.state, "playing")
        XCTAssertNil(viewModel.positionHold, "resuming must let the live position advance freely")
        await fulfillment(of: [sent], timeout: 2.0)
    }

    func testReconcileDropsHoldWhenReloadConfirmsThePosition() {
        viewModel.activeSpeakerID = .mediaPlayerSpa
        viewModel.positionHold = PlaybackPositionHold(target: 100, since: Date())
        var fresh = MediaPlayerEntity(entityId: .mediaPlayerSpa, state: "paused", friendlyName: "Spa")
        fresh.mediaPosition = 99

        let result = viewModel.reconcilePositionHold(speakerID: .mediaPlayerSpa, fresh: fresh)

        XCTAssertEqual(result.mediaPosition, 99, "a confirmed reload passes through untouched")
        XCTAssertNil(viewModel.positionHold)
    }

    func testReconcileKeepsHeldPositionWhenReloadIsStillStale() {
        viewModel.activeSpeakerID = .mediaPlayerSpa
        viewModel.positionHold = PlaybackPositionHold(target: 100, since: Date())
        var fresh = MediaPlayerEntity(entityId: .mediaPlayerSpa, state: "paused", friendlyName: "Spa")
        fresh.mediaPosition = 5

        let result = viewModel.reconcilePositionHold(speakerID: .mediaPlayerSpa, fresh: fresh)

        XCTAssertEqual(result.mediaPosition, 100, "the stale pre-seek position is overridden by the hold")
        XCTAssertNotNil(viewModel.positionHold, "the hold persists until HA confirms")
    }

    func testReconcileLeavesNonActiveSpeakersUntouched() {
        viewModel.activeSpeakerID = .mediaPlayerSpa
        viewModel.positionHold = PlaybackPositionHold(target: 100, since: Date())
        var fresh = MediaPlayerEntity(entityId: .mediaPlayerKitchen, state: "paused", friendlyName: "Kitchen")
        fresh.mediaPosition = 5

        let result = viewModel.reconcilePositionHold(speakerID: .mediaPlayerKitchen, fresh: fresh)

        XCTAssertEqual(result.mediaPosition, 5, "only the active speaker's position is held")
        XCTAssertNotNil(viewModel.positionHold)
    }

    /// Fulfilled when a POST to `path` is observed, so a test can await the async
    /// transport Task it kicked off and not leak a request into the next test.
    private func transportExpectation(path: String) -> XCTestExpectation {
        let expectation = XCTestExpectation(description: "POST \(path)")
        URLProtocolStub.observerRequests { request in
            if request.httpMethod == "POST", request.url?.path.contains(path) == true {
                expectation.fulfill()
            }
        }
        return expectation
    }
}

// MARK: - Position hold

final class PlaybackPositionHoldTests: XCTestCase {
    // Fixed epoch — no wall-clock or random data, so the timing math is deterministic.
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    private func speaker(position: Double?, state: String = "paused", updatedAt: Date? = nil) -> MediaPlayerEntity {
        var entity = MediaPlayerEntity(entityId: .mediaPlayerSpa, state: state, friendlyName: "Spa")
        entity.mediaPosition = position
        entity.mediaPositionUpdatedAt = updatedAt
        return entity
    }

    func testHoldsWhileHaStillReportsThePreSeekPosition() {
        let hold = PlaybackPositionHold(target: 100, since: epoch)
        let (entity, stillPending) = hold.reconcile(speaker(position: 10), asOf: epoch.addingTimeInterval(1))
        XCTAssertTrue(stillPending)
        XCTAssertEqual(entity.mediaPosition, 100)
    }

    func testReleasesOnceHaConfirmsThePositionWithinTolerance() {
        let hold = PlaybackPositionHold(target: 100, since: epoch)
        let (entity, stillPending) = hold.reconcile(speaker(position: 99), asOf: epoch.addingTimeInterval(1))
        XCTAssertFalse(stillPending)
        XCTAssertEqual(entity.mediaPosition, 99, "the confirmed HA state passes through untouched")
    }

    func testHoldsWhenReportedPositionIsMissing() {
        // A pausing player that drops its position to nil must not snap the scrubber to 0.
        let hold = PlaybackPositionHold(target: 55, since: epoch)
        let (entity, stillPending) = hold.reconcile(speaker(position: nil), asOf: epoch.addingTimeInterval(1))
        XCTAssertTrue(stillPending)
        XCTAssertEqual(entity.mediaPosition, 55)
    }

    func testReleasesAfterTimeoutEvenWhenUnconfirmed() {
        let hold = PlaybackPositionHold(target: 100, since: epoch)
        let pastTimeout = epoch.addingTimeInterval(PlaybackPositionHold.timeout + 1)
        let (entity, stillPending) = hold.reconcile(speaker(position: 10), asOf: pastTimeout)
        XCTAssertFalse(stillPending)
        XCTAssertEqual(entity.mediaPosition, 10, "a source that never reports the spot can't freeze the scrubber forever")
    }

    func testHeldPlayingPositionKeepsAdvancingFromTheSeekedSpot() {
        // While playing, the held position is anchored at `since`, so the scrubber
        // resumes advancing from the seeked spot rather than freezing or restarting.
        let hold = PlaybackPositionHold(target: 100, since: epoch)
        let fresh = speaker(position: 10, state: "playing", updatedAt: epoch)
        let now = epoch.addingTimeInterval(2)
        let (entity, stillPending) = hold.reconcile(fresh, asOf: now)
        XCTAssertTrue(stillPending)
        XCTAssertEqual(entity.currentElapsed(asOf: now) ?? -1, 102, accuracy: 0.001)
    }
}

// MARK: - Lyrics loading

@MainActor
private final class StubLyricsService: LyricsService {
    private let results: [LyricsResult]
    private(set) var callCount = 0

    init(results: [LyricsResult]) {
        self.results = results
    }

    func fetchLyrics(title: String, artist: String, album: String?, durationSeconds: Double?) async -> LyricsResult {
        defer { callCount += 1 }
        return callCount < results.count ? results[callCount] : .notFound
    }
}

@MainActor
extension MusicViewModelTests {
    private func playingSpeaker() -> MediaPlayerEntity {
        var speaker = MediaPlayerEntity(entityId: .mediaPlayerKitchen, state: "playing", friendlyName: "Kitchen")
        speaker.mediaTitle = "Song"
        speaker.mediaArtist = "Artist"
        return speaker
    }

    func testLyricsRetryAfterNotFoundThenLatchOnHit() async {
        let line = LyricLine(time: 0, text: "hi")
        let stub = StubLyricsService(results: [.notFound, .synced([line])])
        let viewModel = MusicViewModel(restAPIService: restAPIService, lyricsService: stub)
        viewModel.activeSpeakerID = .mediaPlayerKitchen
        viewModel.speakers[.mediaPlayerKitchen] = playingSpeaker()
        viewModel.isLyricsExpanded = true

        await viewModel.refreshLyricsForCurrentTrack()
        XCTAssertEqual(viewModel.lyrics, .notFound)
        XCTAssertNil(viewModel.lyricsTrackKey, "a miss must not latch — it has to stay retryable")

        // Same track, second trigger: it should retry rather than be suppressed.
        await viewModel.refreshLyricsForCurrentTrack()
        XCTAssertEqual(stub.callCount, 2)
        XCTAssertEqual(viewModel.lyrics, .synced([line]))
        XCTAssertNotNil(viewModel.lyricsTrackKey, "a hit latches so it isn't refetched")

        // Third trigger on the now-loaded track is a no-op.
        await viewModel.refreshLyricsForCurrentTrack()
        XCTAssertEqual(stub.callCount, 2)
    }

    func testLyricsPrefetchWhilePanelClosed() async {
        let line = LyricLine(time: 0, text: "hi")
        let stub = StubLyricsService(results: [.synced([line])])
        let viewModel = MusicViewModel(restAPIService: restAPIService, lyricsService: stub)
        viewModel.activeSpeakerID = .mediaPlayerKitchen
        viewModel.speakers[.mediaPlayerKitchen] = playingSpeaker()
        XCTAssertFalse(viewModel.isLyricsExpanded, "the panel is closed — prefetch must still run")

        await viewModel.refreshLyricsForCurrentTrack()

        // Lyrics are fetched on the track change so they're ready the instant the
        // user opens the panel, not started by that tap.
        XCTAssertEqual(stub.callCount, 1)
        XCTAssertEqual(viewModel.lyrics, .synced([line]))
    }
}

// MARK: - Time formatting

final class PlaybackTimeFormatTests: XCTestCase {
    func testClockFormatting() {
        let cases: [(seconds: TimeInterval, expected: String)] = [
            (0, "0:00"),
            (5, "0:05"),
            (65, "1:05"),
            (600, "10:00"),
            (3661, "1:01:01"),
            (-5, "0:00")
        ]
        for testCase in cases {
            XCTAssertEqual(PlaybackTimeFormat.clock(testCase.seconds), testCase.expected, "\(testCase.seconds)s")
        }
    }
}

private extension URLRequest {
    /// `URLProtocol` strips `httpBody` into a stream for POSTs, so read it back out.
    func httpBodyStreamData() -> Data? {
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data.isEmpty ? nil : data
    }
}
