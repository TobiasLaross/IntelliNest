@testable import IntelliNest
import XCTest

@MainActor
extension MusicViewModelTests {
    func testForcePauseHitsMAAndSonosRegardlessOfShownState() async {
        // MA and the Sonos both claim to be idle — the shown state can't be trusted,
        // so the forced pause must go to both anyway.
        let path = "/api/services/media_player/media_pause"
        stubAllSpeakers()
        await viewModel.reload()
        viewModel.selectSpeaker(.mediaPlayerLivingRoom)

        let recorder = RequestRecorder { $0.httpMethod == "POST" && $0.url?.path == path }
        stubPostService(path: path)
        viewModel.forcePause()
        await restAPIService.lastCommandTask?.value
        let postedIDs = recorder.requests.compactMap { request -> String? in
            let data = request.httpBodyStreamData() ?? request.httpBody
            let body = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
            return body?["entity_id"] as? String
        }

        XCTAssertEqual(Set(postedIDs),
                       [EntityId.mediaPlayerLivingRoom.rawValue, EntityId.mediaPlayerLivingRoomSonos.rawValue])
        XCTAssertEqual(viewModel.speakers[.mediaPlayerLivingRoom]?.state, "paused")
    }
}
