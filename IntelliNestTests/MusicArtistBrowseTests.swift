//
//  MusicArtistBrowseTests.swift
//  IntelliNestTests
//
//  Created by Tobias on 2026-11-18.
//

@testable import IntelliNest
import XCTest

final class MusicArtistBrowseTests: XCTestCase {
    /// The shape Music Assistant actually returns: every child's content type is the
    /// generic "music", the real type sits in `media_class`, and titles carry the
    /// artist in front.
    func testArtistBrowseReadsTypeFromMediaClassAndSplitsTitle() throws {
        let json = """
        {"media_player.kitchen":{"children":[
          {"title":"Mamma Mu & Kråkan - Vem är du Mamma Mu?","media_class":"album","media_content_type":"music",
           "media_content_id":"spotify://album/a1","thumbnail":"https://img/a1.jpg"},
          {"title":"Mamma Mu & Kråkan - Hej vädret","media_class":"track","media_content_type":"music",
           "media_content_id":"spotify://track/t1"},
          {"title":"Radio","media_class":"directory","media_content_type":"music","media_content_id":"radio://r1"}
        ]}}
        """
        let items = try JSONDecoder().decode(MusicArtistBrowseResponse.self, from: Data(json.utf8)).items

        XCTAssertEqual(items.map(\.mediaType), [.album, .track])
        XCTAssertEqual(items.map(\.name), ["Vem är du Mamma Mu?", "Hej vädret"])
        XCTAssertEqual(items.map(\.artist), ["Mamma Mu & Kråkan", "Mamma Mu & Kråkan"])
        XCTAssertEqual(items.first?.imageURL, "https://img/a1.jpg")
    }

    func testArtistBrowseFallsBackToContentTypeWithoutMediaClass() throws {
        let json = """
        {"media_player.kitchen":{"children":[
          {"title":"Song","media_content_type":"track","media_content_id":"spotify://track/t1"}
        ]}}
        """
        let items = try JSONDecoder().decode(MusicArtistBrowseResponse.self, from: Data(json.utf8)).items

        XCTAssertEqual(items.map(\.mediaType), [.track])
    }

    /// "artist" or "album" as the content type makes Music Assistant answer 500
    /// "Media not found"; only "music" resolves the uri.
    @MainActor
    func testBrowseArtistItemsSendsMusicContentType() async throws {
        URLProtocolStub.startInterceptingRequests()
        defer { URLProtocolStub.stopInterceptingRequests() }
        let session = URLProtocolStub.createStubbedURLSession()
        let urlCreator = URLCreator(session: session)
        urlCreator.connectionState = .local
        let service = RestAPIService(urlCreator: urlCreator,
                                     session: session,
                                     setErrorBannerText: { _, _ in },
                                     repeatReloadAction: { _ in })
        var components = URLComponents(string: GlobalConstants.baseExternalUrlString)!
        components.path = "/api/services/media_player/browse_media"
        components.queryItems = [URLQueryItem(name: "return_response", value: "true")]
        let url = components.url!
        let body = "{\"service_response\":{\"media_player.kitchen\":{\"children\":[]}}}"
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        URLProtocolStub.setStub(for: url, data: Data(body.utf8), response: response, error: nil)
        let recorder = RequestRecorder { $0.url?.path == "/api/services/media_player/browse_media" }

        _ = try await service.browseArtistItems(uri: "spotify://artist/a1", on: .mediaPlayerKitchen)

        let payloads = recorder.requests.compactMap { request -> [String: Any]? in
            guard let data = request.httpBodyStreamData() ?? request.httpBody else {
                return nil
            }
            return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        }
        XCTAssertFalse(payloads.isEmpty)
        for payload in payloads {
            XCTAssertEqual(payload["media_content_type"] as? String, "music")
            XCTAssertEqual(payload["media_content_id"] as? String, "spotify://artist/a1")
        }
    }
}

// MARK: - Track links ("Gå till artist" / "Gå till album")

extension MusicArtistBrowseTests {
    /// Trimmed from a real `music/item_by_uri` reply for a Spotify track.
    func testTrackLinksReadFirstArtistAndAlbumFromItemByURI() {
        let json = """
        {"uri":"spotify--FteCvPQu://track/4uLU6hMCjMI75M1A2tKUQC","name":"Never Gonna Give You Up",
         "artists":[{"uri":"spotify--FteCvPQu://artist/0gxyHStUsqpMadRV0Di1Qt","name":"Rick Astley",
                     "metadata":{"images":[]}},
                    {"uri":"spotify--FteCvPQu://artist/other","name":"Other"}],
         "album":{"uri":"spotify--FteCvPQu://album/6N9PS4QXF1D0OWPk0Sxtb4","name":"Whenever You Need Somebody",
                  "artists":[{"name":"Rick Astley"}],
                  "metadata":{"images":[{"path":"/local/cover.jpg","remotely_accessible":false},
                                        {"path":"https://i.scdn.co/image/cover","remotely_accessible":true}]}}}
        """
        let links = MusicTrackLinks.parse(Data(json.utf8))

        XCTAssertEqual(links?.artist, MusicSearchItem(uri: "spotify--FteCvPQu://artist/0gxyHStUsqpMadRV0Di1Qt",
                                                      name: "Rick Astley", mediaType: .artist,
                                                      imageURL: nil, artist: nil))
        XCTAssertEqual(links?.album, MusicSearchItem(uri: "spotify--FteCvPQu://album/6N9PS4QXF1D0OWPk0Sxtb4",
                                                     name: "Whenever You Need Somebody", mediaType: .album,
                                                     imageURL: "https://i.scdn.co/image/cover", artist: "Rick Astley"))
    }

    func testTrackLinksAreNilWithoutArtistOrAlbumURIs() {
        let cases: [(label: String, json: String)] = [
            ("not an object", "[]"),
            ("no links", "{\"name\":\"Song\"}"),
            ("links without uris", "{\"artists\":[{\"name\":\"A\"}],\"album\":{\"name\":\"B\"}}")
        ]
        for testCase in cases {
            XCTAssertNil(MusicTrackLinks.parse(Data(testCase.json.utf8)), testCase.label)
        }
    }
}

@MainActor
extension MusicViewModelTests {
    func testTrackLinkReturnsTheRequestedKind() async {
        let artist = MusicSearchItem(uri: "spotify://artist/a1", name: "Miss Li", mediaType: .artist,
                                     imageURL: nil, artist: nil)
        let album = MusicSearchItem(uri: "spotify://album/b1", name: "På Måndag", mediaType: .album,
                                    imageURL: nil, artist: "Miss Li")
        let socket = StubMusicAssistantQueueSocket()
        await socket.setLinks(MusicTrackLinks(artist: artist, album: album))
        let viewModel = makeViewModel(socket: socket)

        let openedArtist = await viewModel.trackLink(.artist, ofTrack: "spotify://track/t1")
        let openedAlbum = await viewModel.trackLink(.album, ofTrack: "spotify://track/t1")

        XCTAssertEqual(openedArtist, artist)
        XCTAssertEqual(openedAlbum, album)
        XCTAssertTrue(bannerTitles.isEmpty)
    }

    func testTrackLinkBannersWhenMusicAssistantCannotResolveIt() async {
        let album = MusicSearchItem(uri: "spotify://album/b1", name: "På Måndag", mediaType: .album,
                                    imageURL: nil, artist: nil)
        let cases: [(label: String, links: MusicTrackLinks?)] = [
            ("socket failed", nil),
            ("track has no artist", MusicTrackLinks(artist: nil, album: album))
        ]
        for testCase in cases {
            bannerTitles = []
            let socket = StubMusicAssistantQueueSocket()
            await socket.setLinks(testCase.links)
            let viewModel = makeViewModel(socket: socket)

            let link = await viewModel.trackLink(.artist, ofTrack: "spotify://track/t1")

            XCTAssertNil(link, testCase.label)
            XCTAssertEqual(bannerTitles, ["Kunde inte öppna artisten"], testCase.label)
        }
    }
}
