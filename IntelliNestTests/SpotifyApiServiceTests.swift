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

    func testAccountPlaylistsMapsItems() async {
        let json = """
        {"items":[
          {"id":"abc123","name":"Morgon","images":[{"url":"https://img/a.jpg"}],"owner":{"display_name":"huset"}},
          {"id":"def456","name":"Träning","images":[],"owner":{"display_name":"huset"}},
          {"id":null,"name":"Trasig"}
        ]}
        """
        stub(url: spotifyURL(path: "/me/playlists", query: [URLQueryItem(name: "limit", value: "50")]),
             statusCode: 200, json: json)
        let playlists = await service.accountPlaylists()
        // The null-id item is dropped; the rest map to spotify:// uris.
        XCTAssertEqual(playlists.map(\.name), ["Morgon", "Träning"])
        XCTAssertEqual(playlists.first?.uri, "spotify://playlist/abc123")
        XCTAssertEqual(playlists.first?.imageURL, "https://img/a.jpg")
        XCTAssertEqual(playlists.first?.artist, "huset")
        XCTAssertTrue(playlists.allSatisfy { $0.mediaType == .playlist })
    }

    func testAccountPlaylistsReturnsEmptyOnFailure() async {
        stub(url: spotifyURL(path: "/me/playlists", query: [URLQueryItem(name: "limit", value: "50")]),
             statusCode: 401, json: "{}")
        let playlists = await service.accountPlaylists()
        XCTAssertTrue(playlists.isEmpty)
    }

    // MARK: - userPlaylists

    func userPlaylistsURL(userID: String) -> URL {
        spotifyURL(path: "/users/\(userID)/playlists", query: [URLQueryItem(name: "limit", value: "50")])
    }

    func testUserPlaylistsMapsOwnedAndFollowedItems() async {
        // A public profile lists both owned playlists and ones it merely follows;
        // there is no owner filtering, so both map through.
        let json = """
        {"items":[
          {"id":"own1","name":"Träning","images":[{"url":"https://img/t.jpg"}],"owner":{"display_name":"tobiasc91"}},
          {"id":"fol1","name":"Lugnt & skönt","images":[],"owner":{"display_name":"Spotify"}},
          {"id":null,"name":"Trasig"}
        ]}
        """
        stub(url: userPlaylistsURL(userID: "tobiasc91"), statusCode: 200, json: json)
        let playlists = await service.userPlaylists(userID: "tobiasc91")
        XCTAssertEqual(playlists.map(\.name), ["Träning", "Lugnt & skönt"])
        XCTAssertEqual(playlists.first?.uri, "spotify://playlist/own1")
        XCTAssertEqual(playlists.first?.imageURL, "https://img/t.jpg")
        XCTAssertEqual(playlists.last?.uri, "spotify://playlist/fol1")
        XCTAssertTrue(playlists.allSatisfy { $0.mediaType == .playlist })
    }

    func testUserPlaylistsReturnsEmptyWhenNoPlaylists() async {
        stub(url: userPlaylistsURL(userID: "tobiasc91"), statusCode: 200, json: "{\"items\":[]}")
        let playlists = await service.userPlaylists(userID: "tobiasc91")
        XCTAssertTrue(playlists.isEmpty)
    }

    func testUserPlaylistsReturnsEmptyOnFailure() async {
        stub(url: userPlaylistsURL(userID: "tobiasc91"), statusCode: 404, json: "{}")
        let playlists = await service.userPlaylists(userID: "tobiasc91")
        XCTAssertTrue(playlists.isEmpty)
    }

    func testUserPlaylistsSendsBearerTokenToUserPath() async {
        let expectation = XCTestExpectation(description: "GET user playlists with bearer token")
        URLProtocolStub.observerRequests { request in
            if request.httpMethod == "GET",
               request.url?.path == "/v1/users/tobiasc91/playlists",
               request.value(forHTTPHeaderField: "Authorization") == "Bearer stub-access-token" {
                expectation.fulfill()
            }
        }
        stub(url: userPlaylistsURL(userID: "tobiasc91"), statusCode: 200, json: "{\"items\":[]}")
        _ = await service.userPlaylists(userID: "tobiasc91")
        await fulfillment(of: [expectation], timeout: 2.0)
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
