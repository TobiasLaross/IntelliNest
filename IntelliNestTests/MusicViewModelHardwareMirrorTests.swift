@testable import IntelliNest
import XCTest

@MainActor
extension MusicViewModelTests {
    // MARK: - Hardware twin mirroring

    /// Stubs the native Sonos entity that backs `speakerID`. Asserts the room has a
    /// twin so a typo can't silently make the stub unreachable.
    func stubTwin(for speakerID: EntityId,
                  state: String,
                  title: String? = nil,
                  artist: String? = nil,
                  album: String? = nil,
                  contentID: String? = nil,
                  entityPicture: String? = nil) {
        guard let twinID = MusicViewModel.hardwareTwinIDs[speakerID] else {
            XCTFail("\(speakerID) has no hardware twin")
            return
        }
        stubSpeaker(twinID, data: speakerJSON(entityID: twinID,
                                              state: state,
                                              friendlyName: twinID.rawValue,
                                              title: title,
                                              artist: artist,
                                              album: album,
                                              contentID: contentID,
                                              entityPicture: entityPicture))
    }

    func testTwinMirrorsNowPlayingWhenMAQueueIsStale() async {
        // The MA queue entity is frozen on its last track, idle; the real Sonos is
        // playing something else that was started outside the app's queue.
        stubAllSpeakers()
        stubSpeaker(.mediaPlayerLivingRoom,
                    data: speakerJSON(entityID: .mediaPlayerLivingRoom,
                                      state: "idle",
                                      friendlyName: "Vardagsrummet",
                                      title: "Bara Bada Bastu",
                                      artist: "KAJ",
                                      contentID: trackURI))
        stubTwin(for: .mediaPlayerLivingRoom,
                 state: "playing",
                 title: "Sankta Lucia",
                 artist: "Lucia Choir",
                 album: "Lucia",
                 entityPicture: "/api/media_player_proxy/media_player.arc")
        await viewModel.reload()

        let displayed = viewModel.displayedSpeaker(.mediaPlayerLivingRoom)
        XCTAssertEqual(displayed?.mediaTitle, "Sankta Lucia")
        XCTAssertEqual(displayed?.mediaArtist, "Lucia Choir")
        XCTAssertEqual(displayed?.mediaAlbumName, "Lucia")
        XCTAssertTrue(displayed?.isPlaying == true)
        // The MA Spotify URI no longer matches what's audible, so it's dropped —
        // the favourite star and playlist-jump must not act on the wrong track.
        XCTAssertNil(displayed?.mediaContentID)
    }

    func testTwinKeepsMAContentIDWhenSameTrack() async {
        // Normal in-app playback: MA and the Sonos agree on the track, so the MA
        // Spotify URI is preserved for the favourite star.
        stubAllSpeakers()
        stubSpeaker(.mediaPlayerLivingRoom,
                    data: speakerJSON(entityID: .mediaPlayerLivingRoom,
                                      state: "playing",
                                      friendlyName: "Vardagsrummet",
                                      title: trackName,
                                      artist: trackArtist,
                                      contentID: trackURI))
        stubTwin(for: .mediaPlayerLivingRoom,
                 state: "playing",
                 title: trackName,
                 artist: trackArtist)
        await viewModel.reload()

        let displayed = viewModel.displayedSpeaker(.mediaPlayerLivingRoom)
        XCTAssertEqual(displayed?.mediaContentID, trackURI)
        XCTAssertTrue(displayed?.isPlaying == true)
    }

    func testIdleTwinLeavesMAEntityUntouched() async {
        // When the Sonos is idle, the MA entity's own now-playing stands.
        stubAllSpeakers()
        stubSpeaker(.mediaPlayerLivingRoom,
                    data: speakerJSON(entityID: .mediaPlayerLivingRoom,
                                      state: "playing",
                                      friendlyName: "Vardagsrummet",
                                      title: trackName,
                                      artist: trackArtist,
                                      contentID: trackURI))
        stubTwin(for: .mediaPlayerLivingRoom, state: "idle")
        await viewModel.reload()

        let displayed = viewModel.displayedSpeaker(.mediaPlayerLivingRoom)
        XCTAssertEqual(displayed?.mediaTitle, trackName)
        XCTAssertEqual(displayed?.mediaContentID, trackURI)
    }

    func testAirPlayRoomHasNoTwinAndShowsMAState() async {
        // The spa is AirPlay — no hardware twin — so it always shows the MA entity.
        stubAllSpeakers()
        stubSpeaker(.mediaPlayerSpa,
                    data: speakerJSON(entityID: .mediaPlayerSpa,
                                      state: "playing",
                                      friendlyName: "Spa",
                                      title: trackName,
                                      artist: trackArtist,
                                      contentID: trackURI))
        await viewModel.reload()

        XCTAssertNil(MusicViewModel.hardwareTwinIDs[.mediaPlayerSpa])
        let displayed = viewModel.displayedSpeaker(.mediaPlayerSpa)
        XCTAssertEqual(displayed?.mediaTitle, trackName)
        XCTAssertEqual(displayed?.mediaContentID, trackURI)
    }

    func testDefaultSelectionPicksRoomPlayingOnlyOnHardwareTwin() async {
        // Every MA queue entity is idle, but the living-room Sonos is playing —
        // the default selection must still land on that room.
        stubAllSpeakers(playing: nil)
        stubTwin(for: .mediaPlayerLivingRoom,
                 state: "playing",
                 title: "Sankta Lucia",
                 artist: "Lucia Choir")
        await viewModel.reload()
        XCTAssertEqual(viewModel.activeSpeakerID, .mediaPlayerLivingRoom)
    }

    func testSourcePlaylistClearedWhenTwinDiverges() async {
        stubAllSpeakers(playing: .mediaPlayerLivingRoom)
        stubSpeaker(.mediaPlayerLivingRoom,
                    data: speakerJSON(entityID: .mediaPlayerLivingRoom,
                                      state: "playing",
                                      friendlyName: "Vardagsrummet",
                                      title: "Bara Bada Bastu",
                                      artist: "KAJ"))
        stubTwin(for: .mediaPlayerLivingRoom,
                 state: "playing",
                 title: "Sankta Lucia",
                 artist: "Lucia Choir")
        viewModel.activeSpeakerID = .mediaPlayerLivingRoom
        viewModel.nowPlayingSourcePlaylist = MusicSearchItem(uri: "spotify://playlist/9",
                                                             name: "Låtar som går och går",
                                                             mediaType: .playlist,
                                                             imageURL: nil,
                                                             artist: nil)
        await viewModel.reload()
        XCTAssertNil(viewModel.nowPlayingSourcePlaylist)
    }

    func testSourcePlaylistKeptWhenTwinMatches() async {
        stubAllSpeakers(playing: .mediaPlayerLivingRoom)
        stubSpeaker(.mediaPlayerLivingRoom,
                    data: speakerJSON(entityID: .mediaPlayerLivingRoom,
                                      state: "playing",
                                      friendlyName: "Vardagsrummet",
                                      title: trackName,
                                      artist: trackArtist))
        stubTwin(for: .mediaPlayerLivingRoom,
                 state: "playing",
                 title: trackName,
                 artist: trackArtist)
        viewModel.activeSpeakerID = .mediaPlayerLivingRoom
        let playlist = MusicSearchItem(uri: "spotify://playlist/9",
                                       name: "Låtar som går och går",
                                       mediaType: .playlist,
                                       imageURL: nil,
                                       artist: nil)
        viewModel.nowPlayingSourcePlaylist = playlist
        await viewModel.reload()
        XCTAssertEqual(viewModel.nowPlayingSourcePlaylist?.uri, playlist.uri)
    }
}
