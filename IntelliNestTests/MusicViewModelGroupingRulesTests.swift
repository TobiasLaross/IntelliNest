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
}
