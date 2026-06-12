@testable import IntelliNest
import XCTest

/// One save/remove case for the parameterized follow test.
private struct FollowCase {
    let name: String
    let isSave: Bool
    let statusCode: Int
    let expected: Bool
}

/// A token provider that hands back a fixed access token without any web flow, so
/// the API layer can be exercised in isolation.
@MainActor
final class StubSpotifyTokenProvider: SpotifyTokenProviding {
    var authorized: Bool
    var token: String
    var tokenThrows: Bool
    private(set) var authorizeCallCount = 0

    init(authorized: Bool = true, token: String = "stub-access-token", tokenThrows: Bool = false) {
        self.authorized = authorized
        self.token = token
        self.tokenThrows = tokenThrows
    }

    var isAuthorized: Bool { authorized }

    func authorize() async throws {
        authorizeCallCount += 1
        authorized = true
    }

    func validAccessToken() async throws -> String {
        if tokenThrows {
            throw SpotifyAuthError.notAuthorized
        }
        return token
    }
}

@MainActor
final class SpotifyApiServiceTests: XCTestCase {
    var service: SpotifyApiService!
    var tokenProvider: StubSpotifyTokenProvider!

    // Fixed, grep-searchable literals — no random data.
    let playlistID = "37i9dQZF1DXcBWIGoYBM5M"
    let userID = "spotifyuser123"

    override func setUp() async throws {
        URLProtocolStub.startInterceptingRequests()
        let session = URLProtocolStub.createStubbedURLSession()
        tokenProvider = StubSpotifyTokenProvider()
        service = SpotifyApiService(tokenProvider: tokenProvider, session: session)
    }

    override func tearDown() async throws {
        URLProtocolStub.stopInterceptingRequests()
        service = nil
        tokenProvider = nil
    }

    // MARK: - Helpers

    func spotifyURL(path: String, query: [URLQueryItem] = []) -> URL {
        var components = URLComponents(string: "https://api.spotify.com/v1" + path)!
        if query.isNotEmpty {
            components.queryItems = query
        }
        return components.url!
    }

    func stub(url: URL, statusCode: Int, json: String = "") {
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        URLProtocolStub.setStub(for: url, data: Data(json.utf8), response: response, error: nil)
    }

    func stubCurrentUser() {
        stub(url: spotifyURL(path: "/me"), statusCode: 200, json: "{\"id\":\"\(userID)\"}")
    }

    func containsURL() -> URL {
        spotifyURL(path: "/playlists/\(playlistID)/followers/contains", query: [URLQueryItem(name: "ids", value: userID)])
    }

    // MARK: - accountPlaylists

    func mePlaylistsURL(offset: Int) -> URL {
        spotifyURL(path: "/me/playlists", query: [URLQueryItem(name: "limit", value: "50"),
                                                  URLQueryItem(name: "offset", value: "\(offset)")])
    }

    func testAccountPlaylistsMapsItemsWithOwnerID() async {
        let json = """
        {"items":[
          {"id":"abc123","name":"Morgon","images":[{"url":"https://img/a.jpg"}],"owner":{"id":"huset","display_name":"huset"}},
          {"id":"def456","name":"Träning","images":[],"owner":{"id":"tobiasc91","display_name":"Tobias"}},
          {"id":null,"name":"Trasig"}
        ]}
        """
        stub(url: mePlaylistsURL(offset: 0), statusCode: 200, json: json)
        let playlists = await service.accountPlaylists()
        // The null-id item is dropped; the rest map to spotify:// uris with ownerID.
        XCTAssertEqual(playlists.map(\.name), ["Morgon", "Träning"])
        XCTAssertEqual(playlists.first?.uri, "spotify://playlist/abc123")
        XCTAssertEqual(playlists.first?.imageURL, "https://img/a.jpg")
        XCTAssertEqual(playlists.first?.ownerID, "huset")
        XCTAssertEqual(playlists.last?.ownerID, "tobiasc91")
        XCTAssertTrue(playlists.allSatisfy { $0.mediaType == .playlist })
    }

    func testAccountPlaylistsToleratesNullArrayEntries() async {
        // Spotify can return a bare `null` element in `items` for an unavailable
        // playlist; it must be skipped, not throw away the whole (populated) page.
        let json = """
        {"items":[null,{"id":"own1","name":"Träning","owner":{"id":"tobiasc91"}},null]}
        """
        stub(url: mePlaylistsURL(offset: 0), statusCode: 200, json: json)
        let playlists = await service.accountPlaylists()
        XCTAssertEqual(playlists.map(\.name), ["Träning"])
    }

    func testAccountPlaylistsPaginatesPastFiftyUntilShortPage() async {
        // A full 50-item page triggers a second fetch at offset 50; the short page
        // there ends paging, so the whole library is returned, not just the first 50.
        let firstPage = (0 ..< 50).map { index in
            "{\"id\":\"p\(index)\",\"name\":\"P\(index)\",\"owner\":{\"id\":\"huset\"}}"
        }.joined(separator: ",")
        stub(url: mePlaylistsURL(offset: 0), statusCode: 200, json: "{\"items\":[\(firstPage)]}")
        stub(url: mePlaylistsURL(offset: 50), statusCode: 200,
             json: "{\"items\":[{\"id\":\"p50\",\"name\":\"P50\",\"owner\":{\"id\":\"huset\"}}]}")
        let playlists = await service.accountPlaylists()
        XCTAssertEqual(playlists.count, 51)
        XCTAssertEqual(playlists.last?.name, "P50")
    }

    func testAccountPlaylistsReturnsEmptyOnFailure() async {
        stub(url: mePlaylistsURL(offset: 0), statusCode: 401, json: "{}")
        let playlists = await service.accountPlaylists()
        XCTAssertTrue(playlists.isEmpty)
    }

    // MARK: - isPlaylistSaved

    func testIsPlaylistSavedReturnsTrueWhenFollowed() async {
        stubCurrentUser()
        stub(url: containsURL(), statusCode: 200, json: "[true]")
        let saved = await service.isPlaylistSaved(playlistID: playlistID)
        XCTAssertTrue(saved)
    }

    func testIsPlaylistSavedReturnsFalseWhenNotFollowed() async {
        stubCurrentUser()
        stub(url: containsURL(), statusCode: 200, json: "[false]")
        let saved = await service.isPlaylistSaved(playlistID: playlistID)
        XCTAssertFalse(saved)
    }

    func testIsPlaylistSavedReturnsFalseWhenTokenUnavailable() async {
        tokenProvider.tokenThrows = true
        let saved = await service.isPlaylistSaved(playlistID: playlistID)
        XCTAssertFalse(saved)
    }

    // MARK: - Save / remove

    func testSaveAndRemoveReturnSuccessFlag() async {
        let cases = [
            FollowCase(name: "save success", isSave: true, statusCode: 200, expected: true),
            FollowCase(name: "save forbidden", isSave: true, statusCode: 403, expected: false),
            FollowCase(name: "remove success", isSave: false, statusCode: 200, expected: true),
            FollowCase(name: "remove failure", isSave: false, statusCode: 500, expected: false)
        ]
        for testCase in cases {
            stub(url: spotifyURL(path: "/playlists/\(playlistID)/followers"), statusCode: testCase.statusCode)
            let result = testCase.isSave
                ? await service.savePlaylist(playlistID: playlistID)
                : await service.removePlaylist(playlistID: playlistID)
            XCTAssertEqual(result, testCase.expected, testCase.name)
        }
    }

    func testSaveSendsBearerTokenAndPutMethod() async {
        let expectation = XCTestExpectation(description: "PUT followers with bearer token")
        URLProtocolStub.observerRequests { request in
            if request.httpMethod == "PUT",
               request.url?.path == "/v1/playlists/\(self.playlistID)/followers",
               request.value(forHTTPHeaderField: "Authorization") == "Bearer stub-access-token" {
                expectation.fulfill()
            }
        }
        stub(url: spotifyURL(path: "/playlists/\(playlistID)/followers"), statusCode: 200)
        let result = await service.savePlaylist(playlistID: playlistID)
        XCTAssertTrue(result)
        await fulfillment(of: [expectation], timeout: 2.0)
    }
}
