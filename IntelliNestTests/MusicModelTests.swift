@testable import IntelliNest
import XCTest

// Covers the music feature's model decoding (MediaPlayerEntity, MusicSearchResult)
// and the RestAPIService+Music external-URL fallback paths. The ViewModel itself is
// covered in MusicViewModelTests.
final class MusicModelTests: XCTestCase {
    // Fixed, grep-searchable literals — no random data.
    private let trackURI = "spotify://track/3SjXx3rbNGk8nCho8YEoz5"
    private let trackName = "Bohemian Rhapsody"
    private let trackArtist = "Queen"

    // MARK: - MediaPlayerEntity decoding

    func testMediaPlayerDecodesAllAttributes() throws {
        let json = makeEntityJSON(
            entityId: EntityId.mediaPlayerKitchen.rawValue,
            state: "playing",
            attributes: [
                "friendly_name": "Kitchen",
                "volume_level": 0.42,
                "media_title": trackName,
                "media_artist": trackArtist,
                "media_album_name": "A Night at the Opera",
                "media_content_id": trackURI,
                "entity_picture": "/api/media_player_proxy/kitchen.jpg",
                "group_members": [
                    EntityId.mediaPlayerKitchen.rawValue,
                    EntityId.mediaPlayerLivingRoom.rawValue,
                    "media_player.phantom_unknown"
                ],
                "shuffle": true,
                "repeat": "all"
            ]
        )

        let entity = try JSONDecoder().decode(MediaPlayerEntity.self, from: json)

        XCTAssertEqual(entity.entityId, .mediaPlayerKitchen)
        XCTAssertEqual(entity.state, "playing")
        XCTAssertEqual(entity.friendlyName, "Kitchen")
        XCTAssertEqual(entity.volumeLevel, 0.42)
        XCTAssertEqual(entity.mediaTitle, trackName)
        XCTAssertEqual(entity.mediaArtist, trackArtist)
        XCTAssertEqual(entity.mediaAlbumName, "A Night at the Opera")
        XCTAssertEqual(entity.mediaContentID, trackURI)
        XCTAssertEqual(entity.entityPicture, "/api/media_player_proxy/kitchen.jpg")
        // Unknown phantom id is dropped; only the two real ids remain.
        XCTAssertEqual(entity.groupMembers, [.mediaPlayerKitchen, .mediaPlayerLivingRoom])
        XCTAssertTrue(entity.shuffle)
        XCTAssertEqual(entity.repeatMode, .all)
    }

    func testMediaPlayerDecodesWithMissingAttributesUsesDefaults() throws {
        // No `attributes` object at all — the decoder takes the fallback branch.
        let json = Data("""
        {"entity_id":"\(EntityId.mediaPlayerSpa.rawValue)","state":"idle"}
        """.utf8)

        let entity = try JSONDecoder().decode(MediaPlayerEntity.self, from: json)

        XCTAssertEqual(entity.entityId, .mediaPlayerSpa)
        XCTAssertEqual(entity.state, "idle")
        XCTAssertEqual(entity.friendlyName, "")
        XCTAssertEqual(entity.volumeLevel, 0)
        XCTAssertNil(entity.mediaTitle)
        XCTAssertTrue(entity.groupMembers.isEmpty)
        XCTAssertFalse(entity.shuffle)
        XCTAssertEqual(entity.repeatMode, .off)
    }

    private struct StateFlagsCase {
        let state: String
        let isPlaying: Bool
        let isActive: Bool
        let isUnavailable: Bool
    }

    func testMediaPlayerDecodesAttributesPresentButKeysMissingUsesDefaults() throws {
        // `attributes` exists but omits friendly_name, volume_level, group_members,
        // shuffle, and repeat — exercising each `?? default` autoclosure.
        let json = makeEntityJSON(
            entityId: EntityId.mediaPlayerGuestRoom.rawValue,
            state: "idle",
            attributes: ["media_title": trackName]
        )

        let entity = try JSONDecoder().decode(MediaPlayerEntity.self, from: json)

        XCTAssertEqual(entity.mediaTitle, trackName)
        XCTAssertEqual(entity.friendlyName, "")
        XCTAssertEqual(entity.volumeLevel, 0)
        XCTAssertTrue(entity.groupMembers.isEmpty)
        XCTAssertFalse(entity.shuffle)
        XCTAssertEqual(entity.repeatMode, .off)
    }

    func testMediaPlayerStateFlags() {
        let cases: [StateFlagsCase] = [
            StateFlagsCase(state: "playing", isPlaying: true, isActive: true, isUnavailable: false),
            StateFlagsCase(state: "paused", isPlaying: false, isActive: false, isUnavailable: false),
            StateFlagsCase(state: "idle", isPlaying: false, isActive: false, isUnavailable: false),
            StateFlagsCase(state: "unavailable", isPlaying: false, isActive: false, isUnavailable: true)
        ]
        for testCase in cases {
            var entity = MediaPlayerEntity(entityId: .mediaPlayerKitchen)
            entity.state = testCase.state
            XCTAssertEqual(entity.isPlaying, testCase.isPlaying, "isPlaying for \(testCase.state)")
            XCTAssertEqual(entity.isActive, testCase.isActive, "isActive for \(testCase.state)")
            XCTAssertEqual(entity.isUnavailable, testCase.isUnavailable, "isUnavailable for \(testCase.state)")
        }
    }

    func testPlaybackTargetIDResolvesGroupLeader() {
        // Ungrouped speaker targets itself.
        var solo = MediaPlayerEntity(entityId: .mediaPlayerSpa)
        XCTAssertEqual(solo.playbackTargetID, .mediaPlayerSpa)

        // A synced follower routes playback to the group leader (the first member).
        var follower = MediaPlayerEntity(entityId: .mediaPlayerPlayroom)
        follower.groupMembers = [.mediaPlayerGuestRoom, .mediaPlayerPlayroom]
        XCTAssertEqual(follower.playbackTargetID, .mediaPlayerGuestRoom)

        // The leader itself still targets itself.
        var leader = MediaPlayerEntity(entityId: .mediaPlayerGuestRoom)
        leader.groupMembers = [.mediaPlayerGuestRoom, .mediaPlayerPlayroom]
        XCTAssertEqual(leader.playbackTargetID, .mediaPlayerGuestRoom)
    }

    func testMediaPlayerSetNextUpdateTimeMovesIntoFuture() {
        var entity = MediaPlayerEntity(entityId: .mediaPlayerKitchen)
        let before = Date()
        entity.setNextUpdateTime()
        XCTAssertGreaterThan(entity.nextUpdate, before)
    }

    func testMediaPlayerEquality() {
        var base = MediaPlayerEntity(entityId: .mediaPlayerKitchen, state: "playing", friendlyName: "Kitchen")
        base.volumeLevel = 0.5
        base.mediaTitle = trackName
        base.mediaArtist = trackArtist
        base.mediaAlbumName = "A Night at the Opera"
        base.mediaContentID = trackURI
        base.entityPicture = "/api/media_player_proxy/kitchen.jpg"
        base.groupMembers = [.mediaPlayerLivingRoom]
        base.shuffle = true
        base.repeatMode = .one

        var same = base
        XCTAssertEqual(base, same)

        // Each mutated property must break equality, exercising every clause of ==.
        same = base; same.state = "paused"; XCTAssertNotEqual(base, same)
        same = base; same.friendlyName = "Köket"; XCTAssertNotEqual(base, same)
        same = base; same.volumeLevel = 0.9; XCTAssertNotEqual(base, same)
        same = base; same.mediaTitle = "Other"; XCTAssertNotEqual(base, same)
        same = base; same.mediaArtist = "Other"; XCTAssertNotEqual(base, same)
        same = base; same.mediaAlbumName = "Other album"; XCTAssertNotEqual(base, same)
        same = base; same.mediaContentID = "spotify://track/other"; XCTAssertNotEqual(base, same)
        same = base; same.entityPicture = "/api/media_player_proxy/other.jpg"; XCTAssertNotEqual(base, same)
        same = base; same.groupMembers = []; XCTAssertNotEqual(base, same)
        same = base; same.shuffle = false; XCTAssertNotEqual(base, same)
        same = base; same.repeatMode = .off; XCTAssertNotEqual(base, same)

        var differentEntityId = base
        differentEntityId.entityId = .mediaPlayerSpa
        XCTAssertNotEqual(base, differentEntityId)
    }

    // MARK: - MusicSearchResult

    func testSwedishTitleForEachMediaType() {
        let expected: [MusicMediaType: String] = [
            .track: "Låtar",
            .album: "Album",
            .artist: "Artister",
            .playlist: "Spellistor"
        ]
        for mediaType in MusicMediaType.allCases {
            XCTAssertEqual(mediaType.swedishTitle, expected[mediaType])
        }
    }

    func testSearchItemAndSectionIDsDeriveFromContent() {
        let item = MusicSearchItem(uri: trackURI, name: trackName, mediaType: .track, imageURL: nil, artist: trackArtist)
        XCTAssertEqual(item.id, trackURI)

        let section = MusicSearchSection(mediaType: .album, items: [item])
        XCTAssertEqual(section.id, MusicMediaType.album.rawValue)
    }

    func testSearchResponseDropsItemsMissingURIOrNameAndEmptySections() throws {
        // One valid track, one missing uri, one missing name; albums all invalid (section dropped).
        let json = Data("""
        {
          "tracks": [
            {"uri":"\(trackURI)","name":"\(trackName)","media_image":"https://img/track.jpg",
             "artists":[{"name":"\(trackArtist)"}]},
            {"name":"No URI Track"},
            {"uri":"spotify://track/missing-name"}
          ],
          "albums": [
            {"name":"No URI Album"}
          ]
        }
        """.utf8)

        let response = try JSONDecoder().decode(MusicSearchResponse.self, from: json)

        // Only the track section survives, with exactly the one valid item.
        XCTAssertEqual(response.sections.count, 1)
        let section = try XCTUnwrap(response.sections.first)
        XCTAssertEqual(section.mediaType, .track)
        XCTAssertEqual(section.items.count, 1)
        let item = try XCTUnwrap(section.items.first)
        XCTAssertEqual(item.uri, trackURI)
        XCTAssertEqual(item.name, trackName)
        // `media_image` is read when `image` is absent.
        XCTAssertEqual(item.imageURL, "https://img/track.jpg")
        XCTAssertEqual(item.artist, trackArtist)
    }

    // MARK: - RestAPIService+Music external fallback

    @MainActor
    private func makeService() -> (RestAPIService, URLCreator) {
        let stubbedSession = URLProtocolStub.createStubbedURLSession()
        let urlCreator = URLCreator(session: stubbedSession)
        urlCreator.connectionState = .local
        let service = RestAPIService(
            urlCreator: urlCreator,
            session: stubbedSession,
            setErrorBannerText: { _, _ in },
            repeatReloadAction: { _ in }
        )
        return (service, urlCreator)
    }

    private func searchURL(baseURLString: String) -> URL {
        var components = URLComponents(string: baseURLString)!
        components.path = "/api/services/music_assistant/search"
        components.queryItems = [URLQueryItem(name: "return_response", value: "true")]
        return components.url!
    }

    private func stubSearch(baseURLString: String, json: String, statusCode: Int) {
        let url = searchURL(baseURLString: baseURLString)
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        URLProtocolStub.setStub(for: url, data: Data(json.utf8), response: response, error: nil)
    }

    @MainActor
    func testSearchMusicFallsBackToExternalURL() async throws {
        URLProtocolStub.startInterceptingRequests()
        defer { URLProtocolStub.stopInterceptingRequests() }
        let (service, _) = makeService()
        // Internal URL has no stub — only external succeeds.
        let json = """
        {"tracks":[{"uri":"\(trackURI)","name":"\(trackName)"}]}
        """
        stubSearch(baseURLString: GlobalConstants.baseExternalUrlString, json: json, statusCode: 200)

        let response = try await service.searchMusic(query: trackName)

        XCTAssertEqual(response.sections.count, 1)
        XCTAssertEqual(response.sections.first?.items.first?.uri, trackURI)
    }

    @MainActor
    func testSearchMusicThrowsWhenBothURLsFail() async {
        URLProtocolStub.startInterceptingRequests()
        defer { URLProtocolStub.stopInterceptingRequests() }
        let (service, _) = makeService()
        // No stubs — both internal and external fail.
        do {
            _ = try await service.searchMusic(query: trackName)
            XCTFail("Expected searchMusic to throw when both URLs fail")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    @MainActor
    func testPlayMediaFallsBackToExternalURL() async {
        URLProtocolStub.startInterceptingRequests()
        defer { URLProtocolStub.stopInterceptingRequests() }
        let (service, _) = makeService()
        // Internal URL has no stub — only external POST succeeds.
        var components = URLComponents(string: GlobalConstants.baseExternalUrlString)!
        components.path = "/api/services/music_assistant/play_media"
        let url = components.url!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        URLProtocolStub.setStub(for: url, data: Data("[]".utf8), response: response, error: nil)

        let success = await service.playMedia(on: .mediaPlayerKitchen, mediaID: trackURI, mediaType: .track)

        XCTAssertTrue(success)
    }

    @MainActor
    func testPlayMediaReturnsFalseWhenBothURLsFail() async {
        URLProtocolStub.startInterceptingRequests()
        defer { URLProtocolStub.stopInterceptingRequests() }
        let (service, _) = makeService()
        // No stubs — both internal and external POST fail.
        let success = await service.playMedia(on: .mediaPlayerKitchen, mediaID: trackURI, mediaType: .track)

        XCTAssertFalse(success)
    }
}

// MARK: - Playlist browse

extension MusicModelTests {
    func testPlaylistBrowseResponseDecodesTracksAndDropsInvalid() throws {
        let json = """
        {"media_player.kitchen":{"title":"Sommar","media_class":"playlist","children":[
          {"title":"Song A","media_content_id":"spotify://track/a","thumbnail":"https://img/a.jpg"},
          {"title":"Song B","media_content_id":"spotify://track/b","thumbnail":null},
          {"title":null,"media_content_id":"spotify://track/c"},
          {"title":"Missing uri","media_content_id":null}
        ]}}
        """
        let response = try JSONDecoder().decode(MusicPlaylistBrowseResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.tracks.count, 2)
        XCTAssertEqual(response.tracks.first?.uri, "spotify://track/a")
        XCTAssertEqual(response.tracks.first?.title, "Song A")
        XCTAssertEqual(response.tracks.first?.imageURL, "https://img/a.jpg")
        XCTAssertNil(response.tracks.last?.imageURL)
    }

    func testPlaylistBrowseResponseEmptyWhenNoChildren() throws {
        let json = "{\"media_player.kitchen\":{\"title\":\"Sommar\"}}"
        let response = try JSONDecoder().decode(MusicPlaylistBrowseResponse.self, from: Data(json.utf8))
        XCTAssertTrue(response.tracks.isEmpty)
    }

    func testPlaylistBrowseResponseThrowsOnMalformedPayload() {
        // No entity-id node at all — must surface as a failure, not an empty playlist.
        let json = "{}"
        XCTAssertThrowsError(try JSONDecoder().decode(MusicPlaylistBrowseResponse.self, from: Data(json.utf8)))
    }

    @MainActor
    func testBrowsePlaylistTracksUnwrapsEnvelopeAndFallsBackToExternalURL() async throws {
        URLProtocolStub.startInterceptingRequests()
        defer { URLProtocolStub.stopInterceptingRequests() }
        let (service, _) = makeService()
        // Only the external URL is stubbed, so the internal attempt must fail over.
        var components = URLComponents(string: GlobalConstants.baseExternalUrlString)!
        components.path = "/api/services/media_player/browse_media"
        components.queryItems = [URLQueryItem(name: "return_response", value: "true")]
        let url = components.url!
        let body = "{\"service_response\":{\"media_player.kitchen\":{\"children\":" +
            "[{\"title\":\"Song A\",\"media_content_id\":\"spotify://track/a\"}]}}}"
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        URLProtocolStub.setStub(for: url, data: Data(body.utf8), response: response, error: nil)

        let tracks = try await service.browsePlaylistTracks(playlistURI: "spotify://playlist/p1", on: .mediaPlayerKitchen)

        XCTAssertEqual(tracks.count, 1)
        XCTAssertEqual(tracks.first?.uri, "spotify://track/a")
        XCTAssertEqual(tracks.first?.title, "Song A")
    }
}
