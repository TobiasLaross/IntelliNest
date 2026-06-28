@testable import IntelliNest
import XCTest

@MainActor
final class LyricsApiServiceTests: XCTestCase {
    private var service: LyricsApiService!
    private let userAgent = "IntelliNestTest/1.0"
    private let title = "Bohemian Rhapsody"
    private let artist = "Queen"

    override func setUp() {
        URLProtocolStub.startInterceptingRequests()
        service = LyricsApiService(session: URLProtocolStub.createStubbedURLSession(), userAgent: userAgent)
    }

    override func tearDown() {
        URLProtocolStub.stopInterceptingRequests()
        service = nil
    }

    // MARK: - URL builders (mirror the service exactly so stubs match)

    private func lrclibGetURL(album: String? = nil, duration: Int? = nil) -> URL {
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        var items = [
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "track_name", value: title)
        ]
        if let album {
            items.append(URLQueryItem(name: "album_name", value: album))
        }
        if let duration {
            items.append(URLQueryItem(name: "duration", value: String(duration)))
        }
        components.queryItems = items
        return components.url!
    }

    private func lrclibSearchURL() -> URL {
        var components = URLComponents(string: "https://lrclib.net/api/search")!
        components.queryItems = [URLQueryItem(name: "q", value: "\(title) \(artist)")]
        return components.url!
    }

    private func lyricsOvhURL() -> URL {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove("/")
        let escapedArtist = artist.addingPercentEncoding(withAllowedCharacters: allowed)!
        let escapedTitle = title.addingPercentEncoding(withAllowedCharacters: allowed)!
        return URL(string: "https://api.lyrics.ovh/v1/\(escapedArtist)/\(escapedTitle)")!
    }

    // MARK: - Stub helpers

    private func stub(_ url: URL, json: String, statusCode: Int = 200) {
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        URLProtocolStub.setStub(for: url, data: Data(json.utf8), response: response, error: nil)
    }

    // MARK: - Tests

    func testReturnsSyncedLyricsFromLRCLIB() async {
        stub(lrclibGetURL(duration: 233), json: """
        {"duration":233,"plainLyrics":null,"syncedLyrics":"[00:01.00]Hello world"}
        """)
        let result = await service.fetchLyrics(title: title, artist: artist, album: nil, durationSeconds: 233)
        XCTAssertEqual(result, .synced([LyricLine(time: 1.0, text: "Hello world")]))
    }

    func testFallsBackToPlainLyricsFromLRCLIB() async {
        stub(lrclibGetURL(duration: 233), json: """
        {"duration":233,"plainLyrics":"Just plain text","syncedLyrics":null}
        """)
        let result = await service.fetchLyrics(title: title, artist: artist, album: nil, durationSeconds: 233)
        XCTAssertEqual(result, .plain("Just plain text"))
    }

    func testSearchPicksClosestDurationWhenGetMisses() async {
        stub(lrclibGetURL(duration: 233), json: "{}", statusCode: 404)
        stub(lrclibSearchURL(), json: """
        [
          {"duration":100,"plainLyrics":null,"syncedLyrics":"[00:02.00]Wrong"},
          {"duration":230,"plainLyrics":null,"syncedLyrics":"[00:02.00]Right"}
        ]
        """)
        let result = await service.fetchLyrics(title: title, artist: artist, album: nil, durationSeconds: 233)
        XCTAssertEqual(result, .synced([LyricLine(time: 2.0, text: "Right")]))
    }

    func testFallsBackToLyricsOvhWhenLRCLIBEmpty() async {
        stub(lrclibGetURL(duration: 233), json: "{}", statusCode: 404)
        stub(lrclibSearchURL(), json: "[]")
        stub(lyricsOvhURL(), json: #"{"lyrics":"Backup words"}"#)
        let result = await service.fetchLyrics(title: title, artist: artist, album: nil, durationSeconds: 233)
        XCTAssertEqual(result, .plain("Backup words"))
    }

    func testReturnsNotFoundWhenAllSourcesMiss() async {
        stub(lrclibGetURL(duration: 233), json: "{}", statusCode: 404)
        stub(lrclibSearchURL(), json: "[]")
        stub(lyricsOvhURL(), json: #"{"error":"No lyrics found"}"#, statusCode: 404)
        let result = await service.fetchLyrics(title: title, artist: artist, album: nil, durationSeconds: 233)
        XCTAssertEqual(result, .notFound)
    }

    func testSendsDescriptiveUserAgentToLRCLIB() async {
        let getURL = lrclibGetURL(duration: 233)
        let expectation = XCTestExpectation(description: "User-Agent on LRCLIB request")
        URLProtocolStub.observerRequests { request in
            if request.url == getURL {
                XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), self.userAgent)
                expectation.fulfill()
            }
        }
        stub(getURL, json: """
        {"duration":233,"plainLyrics":null,"syncedLyrics":"[00:01.00]Hello world"}
        """)
        _ = await service.fetchLyrics(title: title, artist: artist, album: nil, durationSeconds: 233)
        await fulfillment(of: [expectation], timeout: 2.0)
    }
}
