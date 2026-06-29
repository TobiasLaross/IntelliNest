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
        // Memory-only cache (directory: nil) so tests never touch the shared on-disk
        // cache and each gets a clean slate.
        service = LyricsApiService(session: URLProtocolStub.createStubbedURLSession(),
                                   userAgent: userAgent,
                                   cache: LyricsCache(directory: nil))
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

    func testSecondLookupIsServedFromCacheWithoutRefetching() async {
        stub(lrclibGetURL(duration: 233), json: """
        {"duration":233,"plainLyrics":null,"syncedLyrics":"[00:01.00]Hello world"}
        """)
        let first = await service.fetchLyrics(title: title, artist: artist, album: nil, durationSeconds: 233)
        XCTAssertEqual(first, .synced([LyricLine(time: 1.0, text: "Hello world")]))

        // The provider now misses; a cached track must still resolve from the cache
        // rather than fall through to the (now empty) network result.
        stub(lrclibGetURL(duration: 233), json: "{}", statusCode: 404)
        stub(lrclibSearchURL(), json: "[]")
        stub(lyricsOvhURL(), json: "{}", statusCode: 404)
        let second = await service.fetchLyrics(title: title, artist: artist, album: nil, durationSeconds: 233)
        XCTAssertEqual(second, first, "a cached hit is served without re-fetching")
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

// MARK: - LyricsCache

final class LyricsCacheTests: XCTestCase {
    private let synced = LyricsResult.synced([LyricLine(time: 1, text: "hi")])
    private let plain = LyricsResult.plain("words")

    // A fresh temp directory per test for the persistence cases, cleaned up after.
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("lyrics-cache-tests")
        try? FileManager.default.removeItem(at: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testStoresAndReturnsAHit() async {
        let cache = LyricsCache(directory: nil)
        await cache.insert(synced, forKey: "k")
        let value = await cache.value(forKey: "k")
        XCTAssertEqual(value, synced)
    }

    func testDoesNotCacheNotFoundSoItStaysRetryable() async {
        let cache = LyricsCache(directory: nil)
        await cache.insert(.notFound, forKey: "k")
        let value = await cache.value(forKey: "k")
        XCTAssertNil(value)
    }

    func testKeyNormalizesCaseAndSurroundingWhitespace() {
        let messy = LyricsCache.key(title: "  Bohemian Rhapsody ", artist: "QUEEN", album: nil)
        let clean = LyricsCache.key(title: "bohemian rhapsody", artist: "queen", album: nil)
        XCTAssertEqual(messy, clean)
        // Album is part of the identity, so a different album is a different key.
        XCTAssertNotEqual(clean, LyricsCache.key(title: "bohemian rhapsody", artist: "queen", album: "A Night at the Opera"))
    }

    func testEvictsTheLeastRecentlyUsedBeyondCapacity() async {
        let cache = LyricsCache(capacity: 2, directory: nil)
        await cache.insert(synced, forKey: "a")
        await cache.insert(plain, forKey: "b")
        // Touch "a" so "b" becomes the least-recently-used before "c" pushes one out.
        _ = await cache.value(forKey: "a")
        await cache.insert(synced, forKey: "c")
        let aValue = await cache.value(forKey: "a")
        let bValue = await cache.value(forKey: "b")
        let cValue = await cache.value(forKey: "c")
        XCTAssertEqual(aValue, synced, "the recently-used entry survives")
        XCTAssertNil(bValue, "the least-recently-used entry is evicted")
        XCTAssertEqual(cValue, synced)
    }

    func testPersistsAcrossInstances() async {
        let first = LyricsCache(directory: directory)
        await first.insert(synced, forKey: "k")
        // A new instance over the same directory loads the entry from disk.
        let second = LyricsCache(directory: directory)
        let value = await second.value(forKey: "k")
        XCTAssertEqual(value, synced, "a cached track survives a relaunch")
    }
}
