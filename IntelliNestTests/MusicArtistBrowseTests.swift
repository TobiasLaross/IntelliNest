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
