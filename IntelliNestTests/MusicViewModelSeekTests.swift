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

    func testSeekWithoutActiveSpeakerIsNoOp() {
        viewModel.seek(to: 10)
        XCTAssertNil(viewModel.activeSpeakerID)
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
