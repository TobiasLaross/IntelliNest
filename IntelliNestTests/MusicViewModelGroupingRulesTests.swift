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

        stubPostService(path: "/api/services/media_player/join")
        await viewModel.toggleGroupMember(.mediaPlayerSpa)

        XCTAssertTrue(bannerTitles.contains("Kunde inte gruppera högtalare"))
        XCTAssertEqual(bannerMessages.last,
                       "Köket spelar från en annan app. Starta musiken härifrån för att spela på flera högtalare")
    }
}
