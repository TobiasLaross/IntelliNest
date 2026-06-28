@testable import IntelliNest
import XCTest

/// Covers the playback-position helpers added for the scrubber and synced lyrics:
/// extrapolated elapsed time and hardware-twin position mirroring.
final class MediaPlayerEntityLyricsTests: XCTestCase {
    private let sampledAt = Date(timeIntervalSince1970: 995)
    private let now = Date(timeIntervalSince1970: 1000) // 5s after the sample

    private func makeSpeaker(state: String,
                             position: Double?,
                             duration: Double?,
                             updatedAt: Date?) -> MediaPlayerEntity {
        var speaker = MediaPlayerEntity(entityId: .mediaPlayerKitchen, state: state)
        speaker.mediaPosition = position
        speaker.mediaDuration = duration
        speaker.mediaPositionUpdatedAt = updatedAt
        return speaker
    }

    func testCurrentElapsedExtrapolatesWhilePlaying() {
        let speaker = makeSpeaker(state: "playing", position: 10, duration: 200, updatedAt: sampledAt)
        XCTAssertEqual(speaker.currentElapsed(asOf: now), 15)
    }

    func testCurrentElapsedClampsToDuration() {
        let speaker = makeSpeaker(state: "playing", position: 198, duration: 200, updatedAt: sampledAt)
        XCTAssertEqual(speaker.currentElapsed(asOf: now), 200)
    }

    func testCurrentElapsedFrozenWhilePaused() {
        let speaker = makeSpeaker(state: "paused", position: 10, duration: 200, updatedAt: sampledAt)
        XCTAssertEqual(speaker.currentElapsed(asOf: now), 10)
    }

    func testCurrentElapsedNilWithoutPosition() {
        let speaker = makeSpeaker(state: "playing", position: nil, duration: 200, updatedAt: sampledAt)
        XCTAssertNil(speaker.currentElapsed(asOf: now))
    }

    func testMirroringCopiesLiveTwinPosition() {
        var queue = MediaPlayerEntity(entityId: .mediaPlayerLivingRoom, state: "idle")
        queue.mediaPosition = 5
        queue.mediaDuration = 100
        queue.mediaPositionUpdatedAt = sampledAt

        var twin = MediaPlayerEntity(entityId: .mediaPlayerLivingRoomSonos, state: "playing")
        twin.mediaTitle = "Native Track"
        twin.mediaPosition = 42
        twin.mediaDuration = 250
        twin.mediaPositionUpdatedAt = now

        let mirrored = queue.mirroring(twin)
        XCTAssertEqual(mirrored.mediaPosition, 42)
        XCTAssertEqual(mirrored.mediaDuration, 250)
        XCTAssertEqual(mirrored.mediaPositionUpdatedAt, now)
    }
}
