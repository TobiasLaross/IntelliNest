@testable import IntelliNest
import XCTest

// MARK: - Speaker picker entries

@MainActor
extension MusicViewModelTests {
    func testUngroupedSpeakersAreEachTheirOwnPickerEntry() async {
        stubAllSpeakers(playing: .mediaPlayerKitchen)
        await viewModel.reload()
        let entries = viewModel.speakerPickerEntries
        XCTAssertEqual(entries.map(\.leader.entityId), MusicViewModel.speakerIDs)
        XCTAssertTrue(entries.allSatisfy { !$0.isGroup })
    }

    func testGroupedSpeakersCollapseIntoOneEntryLeaderFirst() async {
        // Lekrummet leads a group with Köket. The group card sits where Köket (the
        // first room in display order) would, and names the leader first.
        stubAllSpeakers()
        let group = [EntityId.mediaPlayerPlayroom.rawValue, EntityId.mediaPlayerKitchen.rawValue]
        stubSpeaker(.mediaPlayerKitchen,
                    data: speakerJSON(entityID: .mediaPlayerKitchen, state: "playing",
                                      friendlyName: "Köket", volume: 0.2, groupMembers: group))
        stubSpeaker(.mediaPlayerPlayroom,
                    data: speakerJSON(entityID: .mediaPlayerPlayroom, state: "playing",
                                      friendlyName: "Lekrummet", volume: 0.4, groupMembers: group))
        await viewModel.reload()

        let entries = viewModel.speakerPickerEntries
        XCTAssertEqual(entries.map(\.leader.entityId),
                       [.mediaPlayerPlayroom, .mediaPlayerGuestRoom, .mediaPlayerLivingRoom,
                        .mediaPlayerOutdoorTable, .mediaPlayerSpa])
        let groupEntry = entries.first
        XCTAssertEqual(groupEntry?.isGroup, true)
        XCTAssertEqual(groupEntry?.members.map(\.entityId), [.mediaPlayerPlayroom, .mediaPlayerKitchen])
        XCTAssertEqual(groupEntry?.title, "Lekrummet + Köket")
        XCTAssertEqual(groupEntry?.averageVolume ?? 0, 0.3, accuracy: 0.0001)
        XCTAssertEqual(groupEntry?.contains(.mediaPlayerKitchen), true)
        XCTAssertEqual(groupEntry?.contains(.mediaPlayerSpa), false)
    }

    func testSeparateGroupsGetSeparateEntries() async {
        stubAllSpeakers()
        let firstGroup = [EntityId.mediaPlayerKitchen.rawValue, EntityId.mediaPlayerGuestRoom.rawValue]
        let secondGroup = [EntityId.mediaPlayerSpa.rawValue, EntityId.mediaPlayerOutdoorTable.rawValue]
        for (entityID, members) in [(EntityId.mediaPlayerKitchen, firstGroup), (.mediaPlayerGuestRoom, firstGroup),
                                    (.mediaPlayerSpa, secondGroup), (.mediaPlayerOutdoorTable, secondGroup)] {
            stubSpeaker(entityID, data: speakerJSON(entityID: entityID, state: "playing",
                                                    friendlyName: entityID.rawValue, groupMembers: members))
        }
        await viewModel.reload()

        let entries = viewModel.speakerPickerEntries
        XCTAssertEqual(entries.map { $0.members.map(\.entityId) },
                       [[.mediaPlayerKitchen, .mediaPlayerGuestRoom],
                        [.mediaPlayerPlayroom],
                        [.mediaPlayerLivingRoom],
                        [.mediaPlayerSpa, .mediaPlayerOutdoorTable]])
    }

    func testGroupWithOnlyOneReachableMemberIsASingleEntry() async {
        stubAllSpeakers(unavailable: [.mediaPlayerPlayroom])
        let group = [EntityId.mediaPlayerPlayroom.rawValue, EntityId.mediaPlayerKitchen.rawValue]
        stubSpeaker(.mediaPlayerKitchen,
                    data: speakerJSON(entityID: .mediaPlayerKitchen, state: "playing",
                                      friendlyName: "Köket", groupMembers: group))
        await viewModel.reload()

        let kitchenEntry = viewModel.speakerPickerEntries.first
        XCTAssertEqual(kitchenEntry?.leader.entityId, .mediaPlayerKitchen)
        XCTAssertEqual(kitchenEntry?.isGroup, false)
    }

    func testSetGroupVolumeForPickerEntryUpdatesOnlyItsMembers() async {
        stubAllSpeakers()
        let group = [EntityId.mediaPlayerPlayroom.rawValue, EntityId.mediaPlayerKitchen.rawValue]
        for entityID in [EntityId.mediaPlayerPlayroom, .mediaPlayerKitchen] {
            stubSpeaker(entityID, data: speakerJSON(entityID: entityID, state: "playing",
                                                    friendlyName: entityID.rawValue, groupMembers: group))
        }
        await viewModel.reload()
        guard let groupEntry = viewModel.speakerPickerEntries.first(where: \.isGroup) else {
            return XCTFail("Expected a grouped picker entry")
        }
        let recorder = RequestRecorder { $0.httpMethod == "POST" && $0.url?.path.contains("/volume_set") == true }
        stubPostService(path: "/api/services/media_player/volume_set")

        viewModel.setGroupVolume(0.5, for: groupEntry)

        XCTAssertEqual(viewModel.speakers[.mediaPlayerPlayroom]?.volumeLevel, 0.5)
        XCTAssertEqual(viewModel.speakers[.mediaPlayerKitchen]?.volumeLevel, 0.5)
        XCTAssertEqual(viewModel.speakers[.mediaPlayerSpa]?.volumeLevel, 0.3)
        await recorder.waitForRequests(count: 2)
    }
}
