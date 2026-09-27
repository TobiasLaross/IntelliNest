@testable import IntelliNest
import XCTest

// MARK: - Sonos grouping while a native source plays

@MainActor
extension MusicViewModelTests {
    private static let airPlayContentID = "x-sonos-vli:RINCON_38420B10EC2801400:1,airplay:9d126e4e"

    /// Kitchen's Sonos plays AirPlay (so Music Assistant can't group it) and is the
    /// coordinator of a Sonos group with `twinGroup` as its members.
    private func stubKitchenOnAirPlay(twinGroup: [EntityId] = [.mediaPlayerKitchenSonos]) {
        let members = twinGroup.map(\.rawValue)
        stubSpeaker(.mediaPlayerKitchenSonos,
                    data: speakerJSON(entityID: .mediaPlayerKitchenSonos, state: "playing", friendlyName: "Kitchen",
                                      title: "Ho Hey", artist: "The Lumineers",
                                      contentID: Self.airPlayContentID, groupMembers: members))
        for twinID in twinGroup where twinID != .mediaPlayerKitchenSonos {
            stubSpeaker(twinID, data: speakerJSON(entityID: twinID, state: "playing", friendlyName: twinID.rawValue,
                                                  title: "Ho Hey", artist: "The Lumineers", groupMembers: members))
        }
    }

    private func capturePost(path: String) -> () -> [String: Any]? {
        var capturedBody: [String: Any]?
        URLProtocolStub.observerRequests { request in
            if request.httpMethod == "POST", request.url?.path == path {
                let data = request.httpBodyStreamData() ?? request.httpBody
                capturedBody = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
            }
        }
        return { capturedBody }
    }

    func testNativeSourceHidesPrimaryAndReadsSonosGroup() async {
        stubAllSpeakers()
        stubKitchenOnAirPlay(twinGroup: [.mediaPlayerKitchenSonos, .mediaPlayerLivingRoomSonos])
        await viewModel.reload()
        viewModel.selectSpeaker(.mediaPlayerKitchen)

        XCTAssertFalse(viewModel.showsPrimary)
        XCTAssertTrue(viewModel.isGrouped(.mediaPlayerLivingRoom))
        XCTAssertFalse(viewModel.isGrouped(.mediaPlayerGuestRoom))
        XCTAssertEqual(viewModel.groupedSpeakers.map(\.entityId), [.mediaPlayerKitchen, .mediaPlayerLivingRoom])
    }

    func testMusicAssistantPlaybackKeepsPrimary() async {
        stubAllSpeakers(playing: .mediaPlayerKitchen)
        await viewModel.reload()
        viewModel.selectSpeaker(.mediaPlayerKitchen)

        XCTAssertTrue(viewModel.showsPrimary)
    }

    func testNativeSourceJoinsSonosTwinsOnCoordinator() async {
        stubAllSpeakers()
        stubKitchenOnAirPlay()
        await viewModel.reload()
        viewModel.selectSpeaker(.mediaPlayerKitchen)

        let body = capturePost(path: "/api/services/media_player/join")
        stubPostService(path: "/api/services/media_player/join")
        // The Sonos topology reports the new member on the confirming reload.
        stubKitchenOnAirPlay(twinGroup: [.mediaPlayerKitchenSonos, .mediaPlayerLivingRoomSonos])
        await viewModel.toggleGroupMember(.mediaPlayerLivingRoom)

        XCTAssertEqual(body()?["entity_id"] as? String, EntityId.mediaPlayerKitchenSonos.rawValue)
        XCTAssertEqual(body()?["group_members"] as? [String], [EntityId.mediaPlayerLivingRoomSonos.rawValue])
        XCTAssertTrue(viewModel.isGrouped(.mediaPlayerLivingRoom))
        XCTAssertTrue(bannerTitles.isEmpty)
        XCTAssertTrue(viewModel.pendingGroupingSpeakers.isEmpty)
    }

    func testNativeSourceUnjoinsSonosTwin() async {
        stubAllSpeakers()
        stubKitchenOnAirPlay(twinGroup: [.mediaPlayerKitchenSonos, .mediaPlayerLivingRoomSonos])
        await viewModel.reload()
        viewModel.selectSpeaker(.mediaPlayerKitchen)

        let body = capturePost(path: "/api/services/media_player/unjoin")
        stubPostService(path: "/api/services/media_player/unjoin")
        stubKitchenOnAirPlay()
        await viewModel.toggleGroupMember(.mediaPlayerLivingRoom)

        XCTAssertEqual(body()?["entity_id"] as? String, EntityId.mediaPlayerLivingRoomSonos.rawValue)
        XCTAssertFalse(viewModel.isGrouped(.mediaPlayerLivingRoom))
        XCTAssertTrue(bannerTitles.isEmpty)
    }

    func testNativeSourceRejectsNonSonosSpeaker() async {
        stubAllSpeakers()
        stubKitchenOnAirPlay()
        await viewModel.reload()
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        let recorder = RequestRecorder { $0.httpMethod == "POST" && $0.url?.path.contains("/media_player/join") == true }

        await viewModel.toggleGroupMember(.mediaPlayerSpa)

        XCTAssertTrue(recorder.requests.isEmpty)
        XCTAssertEqual(bannerTitles, ["Kunde inte gruppera högtalare"])
        XCTAssertTrue(bannerMessages.first?.contains("Bara Sonos-högtalare") == true)
    }
}
