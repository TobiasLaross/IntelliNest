@testable import IntelliNest
import XCTest

// MARK: - Group changes Home Assistant accepts but never applies

@MainActor
extension MusicViewModelTests {
    func testJoinAcceptedButNeverAppliedShowsBanner() async {
        // Home Assistant answers 200 and the membership never changes. The tap has
        // to report that instead of leaving the speaker looking like it joined.
        stubAllSpeakers(playing: .mediaPlayerKitchen)
        stubSpeaker(.mediaPlayerKitchen,
                    data: speakerJSON(entityID: .mediaPlayerKitchen, state: "playing",
                                      friendlyName: "Köket", activeQueue: "RINCON_38420B10EC2801400"))
        await viewModel.reload()
        XCTAssertFalse(viewModel.isGrouped(.mediaPlayerSpa))
        stubPostService(path: "/api/services/media_player/join")
        await viewModel.toggleGroupMember(.mediaPlayerSpa)
        XCTAssertFalse(viewModel.isGrouped(.mediaPlayerSpa))
        XCTAssertTrue(bannerTitles.contains("Kunde inte gruppera högtalare"))
        XCTAssertEqual(bannerMessages.last, "Det gick inte att lägga till \(EntityId.mediaPlayerSpa.rawValue) i gruppen")
        XCTAssertTrue(viewModel.pendingGroupingSpeakers.isEmpty)
    }

    func testJoinOntoAnExternalSourceExplainsWhyItFailed() async {
        // Köket is playing over Spotify Connect, so it reports no active_queue and
        // Music Assistant has no stream to extend to Spa. The banner has to say that
        // rather than blame Spa, since starting playback from the app is the fix.
        stubAllSpeakers()
        stubSpeaker(.mediaPlayerKitchen,
                    data: speakerJSON(entityID: .mediaPlayerKitchen, state: "playing",
                                      friendlyName: "Köket", title: "Kite", artist: "Benjamin Ingrosso"))
        await viewModel.reload()
        XCTAssertEqual(viewModel.activeSpeakerID, .mediaPlayerKitchen)
        XCTAssertFalse(viewModel.isGrouped(.mediaPlayerSpa))

        stubPostService(path: "/api/services/media_player/join")
        await viewModel.toggleGroupMember(.mediaPlayerSpa)

        XCTAssertTrue(bannerTitles.contains("Kunde inte gruppera högtalare"))
        XCTAssertEqual(bannerMessages.last,
                       "Köket spelar från en annan app. Starta musiken härifrån för att spela på flera högtalare")
    }

    func testJoinConfirmedAgainstTheLeaderItWasSentTo() async {
        // Home Assistant applies the group a beat late, and the user picks another
        // speaker while the confirmation reloads are still running. The join still
        // has to be judged against Köket, the leader it was sent to — not against
        // whatever is selected by the time the reloads finish.
        stubAllSpeakers(playing: .mediaPlayerKitchen)
        stubSpeaker(.mediaPlayerKitchen,
                    data: speakerJSON(entityID: .mediaPlayerKitchen, state: "playing",
                                      friendlyName: "Köket", activeQueue: "RINCON_38420B10EC2801400"))
        await viewModel.reload()
        XCTAssertEqual(viewModel.activeSpeakerID, .mediaPlayerKitchen)
        XCTAssertFalse(viewModel.isGrouped(.mediaPlayerSpa))

        stubPostService(path: "/api/services/media_player/join")
        let group = [EntityId.mediaPlayerKitchen.rawValue, EntityId.mediaPlayerSpa.rawValue]
        onGroupRecheckWait = { [weak self] in
            guard let self else {
                return
            }
            stubSpeaker(.mediaPlayerKitchen,
                        data: speakerJSON(entityID: .mediaPlayerKitchen, state: "playing",
                                          friendlyName: "Köket", groupMembers: group,
                                          activeQueue: "RINCON_38420B10EC2801400"))
            stubSpeaker(.mediaPlayerSpa,
                        data: speakerJSON(entityID: .mediaPlayerSpa, state: "playing",
                                          friendlyName: "Spa", groupMembers: group))
            viewModel.selectSpeaker(.mediaPlayerLivingRoom)
        }

        await viewModel.toggleGroupMember(.mediaPlayerSpa)

        XCTAssertEqual(viewModel.speakers[.mediaPlayerKitchen]?.groupMembers,
                       [.mediaPlayerKitchen, .mediaPlayerSpa])
        XCTAssertTrue(bannerTitles.isEmpty)
    }

    // MARK: - Splitting and linking another group

    /// Köket plays alone; Gästrummet and Lekrummet are synced in a group of their own.
    private func stubKitchenWithGuestPlayroomGroup() async {
        let otherGroup = [EntityId.mediaPlayerGuestRoom.rawValue, EntityId.mediaPlayerPlayroom.rawValue]
        stubAllSpeakers(playing: .mediaPlayerKitchen)
        stubSpeaker(.mediaPlayerKitchen,
                    data: speakerJSON(entityID: .mediaPlayerKitchen, state: "playing",
                                      friendlyName: "Köket", activeQueue: "RINCON_38420B10EC2801400"))
        stubSpeaker(.mediaPlayerGuestRoom,
                    data: speakerJSON(entityID: .mediaPlayerGuestRoom, state: "playing",
                                      friendlyName: "Gästrummet", groupMembers: otherGroup))
        stubSpeaker(.mediaPlayerPlayroom,
                    data: speakerJSON(entityID: .mediaPlayerPlayroom, state: "playing",
                                      friendlyName: "Lekrummet", groupMembers: otherGroup))
        await viewModel.reload()
        XCTAssertEqual(viewModel.activeSpeakerID, .mediaPlayerKitchen)
    }

    func testSplitFromGroupUnjoinsOnlyThatRoom() async {
        await stubKitchenWithGuestPlayroomGroup()
        let recorder = RequestRecorder { $0.httpMethod == "POST" && $0.url?.path.contains("/media_player/unjoin") == true }
        stubPostService(path: "/api/services/media_player/unjoin")
        stubSpeaker(.mediaPlayerPlayroom,
                    data: speakerJSON(entityID: .mediaPlayerPlayroom, state: "idle", friendlyName: "Lekrummet"))
        stubSpeaker(.mediaPlayerGuestRoom,
                    data: speakerJSON(entityID: .mediaPlayerGuestRoom, state: "playing", friendlyName: "Gästrummet"))

        await viewModel.splitFromGroup(.mediaPlayerPlayroom)

        XCTAssertEqual(recorder.requests.count, 1)
        XCTAssertEqual(viewModel.activeSpeakerID, .mediaPlayerKitchen)
        XCTAssertFalse(viewModel.speakerPickerEntries.contains { $0.isGroup })
        XCTAssertTrue(bannerTitles.isEmpty)
        XCTAssertTrue(viewModel.pendingGroupingSpeakers.isEmpty)
    }

    func testSplitFromGroupThatNeverAppliesShowsBanner() async {
        await stubKitchenWithGuestPlayroomGroup()
        stubPostService(path: "/api/services/media_player/unjoin")

        await viewModel.splitFromGroup(.mediaPlayerPlayroom)

        XCTAssertEqual(bannerMessages.last, "Det gick inte att ta bort Lekrummet från gruppen")
        XCTAssertTrue(viewModel.pendingGroupingSpeakers.isEmpty)
    }

    func testLinkGroupUnjoinsEveryMemberThenJoinsThemAll() async {
        await stubKitchenWithGuestPlayroomGroup()
        guard let entry = viewModel.speakerPickerEntries.first(where: { $0.isGroup }) else {
            return XCTFail("Expected the Gästrummet + Lekrummet group card")
        }
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
        let newGroup = [EntityId.mediaPlayerKitchen, .mediaPlayerGuestRoom, .mediaPlayerPlayroom].map(\.rawValue)
        for (entityID, name) in [(EntityId.mediaPlayerKitchen, "Köket"), (.mediaPlayerGuestRoom, "Gästrummet"),
                                 (.mediaPlayerPlayroom, "Lekrummet")] {
            stubSpeaker(entityID, data: speakerJSON(entityID: entityID, state: "playing",
                                                    friendlyName: name, groupMembers: newGroup))
        }

        await viewModel.linkGroup(entry)

        XCTAssertEqual(orderLock.withLock { requestOrder }, ["unjoin", "unjoin", "join"])
        XCTAssertTrue(viewModel.isGrouped(.mediaPlayerGuestRoom))
        XCTAssertTrue(viewModel.isGrouped(.mediaPlayerPlayroom))
        XCTAssertTrue(bannerTitles.isEmpty)
        XCTAssertTrue(viewModel.pendingGroupingSpeakers.isEmpty)
    }

    func testLinkGroupThatFailsShowsBanner() async {
        await stubKitchenWithGuestPlayroomGroup()
        guard let entry = viewModel.speakerPickerEntries.first(where: { $0.isGroup }) else {
            return XCTFail("Expected the Gästrummet + Lekrummet group card")
        }
        stubPostService(path: "/api/services/media_player/unjoin")
        stubPostService(path: "/api/services/media_player/join", statusCode: 500)

        await viewModel.linkGroup(entry)

        XCTAssertEqual(bannerMessages.last, "Det gick inte att lägga till Gästrummet + Lekrummet i gruppen")
        XCTAssertTrue(viewModel.pendingGroupingSpeakers.isEmpty)
    }
}
