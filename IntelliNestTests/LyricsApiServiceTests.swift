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
        let recorder = RequestRecorder { $0.url == getURL }
        stub(getURL, json: """
        {"duration":233,"plainLyrics":null,"syncedLyrics":"[00:01.00]Hello world"}
        """)

        _ = await service.fetchLyrics(title: title, artist: artist, album: nil, durationSeconds: 233)

        XCTAssertEqual(recorder.requests.first?.value(forHTTPHeaderField: "User-Agent"), userAgent)
    }
}

// MARK: - LyricsCache

final class LyricsCacheTests: XCTestCase {
    private let synced = LyricsResult.synced([LyricLine(time: 1, text: "hi")])
    private let plain = LyricsResult.plain("words")

    /// A fresh temp directory per test for the persistence cases, cleaned up after.
    private var directory: URL!

    override func setUpWithError() throws {
        // Per-test subdirectory (keyed by the deterministic test name, not a runtime
        // UUID) so the persistence fixtures can't collide between tests.
        let safeName = name.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lyrics-cache-tests-\(safeName)", isDirectory: true)
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

// MARK: - Multi-artist names

extension LyricsApiServiceTests {
    private static let multiTitle = "Pilutta-visan"
    private static let multiArtist = "Astrid Lindgren/Madicken"
    private static let primaryArtist = "Astrid Lindgren"

    private func getURL(artist: String) -> URL {
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        components.queryItems = [
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "track_name", value: Self.multiTitle),
            URLQueryItem(name: "duration", value: "147")
        ]
        return components.url!
    }

    private func fieldSearchURL(artist: String) -> URL {
        var components = URLComponents(string: "https://lrclib.net/api/search")!
        components.queryItems = LyricsApiService.fieldSearchItems(title: Self.multiTitle, artist: artist)
        return components.url!
    }

    private func respond(_ url: URL, json: String, statusCode: Int = 200) {
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        URLProtocolStub.setStub(for: url, data: Data(json.utf8), response: response, error: nil)
    }

    func testArtistCandidatesSplitJoinedArtistNames() {
        let cases: [(artist: String, expected: [String])] = [
            ("Queen", ["Queen"]),
            ("Astrid Lindgren/Madicken", ["Astrid Lindgren/Madicken", "Astrid Lindgren"]),
            ("Babyloonz/Vanja Wikström", ["Babyloonz/Vanja Wikström", "Babyloonz"]),
            ("Simon & Garfunkel", ["Simon & Garfunkel", "Simon"]),
            ("Avicii, Aloe Blacc", ["Avicii, Aloe Blacc", "Avicii"]),
            ("Calvin Harris feat. Rihanna", ["Calvin Harris feat. Rihanna", "Calvin Harris"])
        ]
        for testCase in cases {
            XCTAssertEqual(LyricsApiService.artistCandidates(for: testCase.artist), testCase.expected, testCase.artist)
        }
    }

    func testJoinedArtistFallsBackToPrimaryArtistForSyncedLyrics() async {
        respond(getURL(artist: Self.multiArtist), json: "{}", statusCode: 404)
        respond(getURL(artist: Self.primaryArtist), json: """
        {"duration":146,"plainLyrics":"Madicken","syncedLyrics":"[00:03.00]Madicken, Madicken"}
        """)
        let result = await service.fetchLyrics(title: Self.multiTitle, artist: Self.multiArtist,
                                               album: nil, durationSeconds: 147)
        XCTAssertEqual(result, .synced([LyricLine(time: 3.0, text: "Madicken, Madicken")]))
    }

    func testPlainHitIsHeldBackWhileASyncedSearchHitExists() async {
        respond(getURL(artist: Self.multiArtist), json: """
        {"duration":149,"plainLyrics":"Plain only","syncedLyrics":null}
        """)
        respond(getURL(artist: Self.primaryArtist), json: "{}", statusCode: 404)
        respond(fieldSearchURL(artist: Self.primaryArtist), json: """
        [
          {"duration":149,"plainLyrics":"Plain only","syncedLyrics":null},
          {"duration":146,"plainLyrics":"Timed","syncedLyrics":"[00:04.00]Timed"}
        ]
        """)
        let result = await service.fetchLyrics(title: Self.multiTitle, artist: Self.multiArtist,
                                               album: nil, durationSeconds: 147)
        XCTAssertEqual(result, .synced([LyricLine(time: 4.0, text: "Timed")]))
    }

    func testPlainHitIsReturnedWhenNothingSyncedExists() async {
        respond(getURL(artist: Self.multiArtist), json: """
        {"duration":149,"plainLyrics":"Plain only","syncedLyrics":null}
        """)
        let result = await service.fetchLyrics(title: Self.multiTitle, artist: Self.multiArtist,
                                               album: nil, durationSeconds: 147)
        XCTAssertEqual(result, .plain("Plain only"))
    }
}

// MARK: - Miss logging

extension LyricsApiServiceTests {
    private struct MissCase {
        let artist: String
        let album: String?
        let duration: Double?
        let timedOut: Bool
        let expected: String
    }

    func testMissDescriptionCarriesWhatTheLookupMatchedOn() {
        let cases = [
            MissCase(artist: "Queen", album: nil, duration: nil, timedOut: false,
                     expected: #"Lyrics not found: "En apelsin" by "Queen""#),
            MissCase(artist: "Klas Widén/Petra Hellsing", album: "Mattelåtar", duration: 74.4, timedOut: false,
                     expected: #"Lyrics not found: "En apelsin" by "Klas Widén/Petra Hellsing", album "Mattelåtar", 74s, "#
                         + #"artists tried: "Klas Widén/Petra Hellsing", "Klas Widén""#),
            MissCase(artist: "Queen", album: "", duration: 74, timedOut: true,
                     expected: #"Lyrics not found: "En apelsin" by "Queen", 74s, gave up after the 10s timeout"#)
        ]
        for testCase in cases {
            let description = LyricsApiService.missDescription(title: "En apelsin", artist: testCase.artist,
                                                               album: testCase.album,
                                                               durationSeconds: testCase.duration,
                                                               timedOut: testCase.timedOut)
            XCTAssertEqual(description, testCase.expected)
        }
    }

    func testMissIsLoggedAsWarningToHomeAssistant() async {
        Log.resetRemoteReporting()
        defer { Log.resetRemoteReporting() }
        stub(lrclibGetURL(duration: 233), json: "{}", statusCode: 404)
        stub(lrclibSearchURL(), json: "[]")
        stub(lyricsOvhURL(), json: #"{"error":"No lyrics found"}"#, statusCode: 404)

        // Unstubbed requests log their own errors, so wait for the miss line itself.
        let reported = await withCheckedContinuation { (continuation: CheckedContinuation<[String], Never>) in
            var resumed = false
            Log.remoteReporter = { level, message in
                guard !resumed, message.contains("Lyrics not found") else {
                    return
                }
                resumed = true
                continuation.resume(returning: [level, message])
            }
            Task {
                _ = await service.fetchLyrics(title: title, artist: artist, album: nil, durationSeconds: 233)
            }
        }

        XCTAssertEqual(reported.first, "warning")
        XCTAssertTrue(reported.last?.contains(#""Bohemian Rhapsody" by "Queen", 233s"#) == true, reported.last ?? "")
    }
}
