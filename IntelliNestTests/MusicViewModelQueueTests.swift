@testable import IntelliNest
import XCTest

/// Records queue-socket calls so the view model's read/add/remove queue logic
/// can be tested without the Music Assistant WebSocket.
actor StubMusicAssistantQueueSocket: MusicAssistantQueueSocket {
    var items: [MusicQueueItem]
    var deleteSucceeds: Bool
    var favoriteSucceeds: Bool
    private(set) var deletedItemIDs: [String] = []
    private(set) var addedFavoriteURIs: [String] = []
    private(set) var removedFavorites: [String] = []

    init(items: [MusicQueueItem] = [], deleteSucceeds: Bool = true, favoriteSucceeds: Bool = true) {
        self.items = items
        self.deleteSucceeds = deleteSucceeds
        self.favoriteSucceeds = favoriteSucceeds
    }

    func queueItems(queueID _: String) async -> [MusicQueueItem] { items }

    /// Replaces the items a later `queueItems` read returns, so a test can model
    /// the live queue changing between two `loadQueue` calls.
    func setItems(_ newItems: [MusicQueueItem]) {
        items = newItems
    }

    func deleteItem(queueID _: String, itemID: String) async -> Bool {
        deletedItemIDs.append(itemID)
        return deleteSucceeds
    }

    func addFavorite(uri: String) async -> Bool {
        addedFavoriteURIs.append(uri)
        return favoriteSucceeds
    }

    func removeFavorite(mediaType: String, libraryItemID: String) async -> Bool {
        removedFavorites.append("\(mediaType):\(libraryItemID)")
        return favoriteSucceeds
    }
}

@MainActor
extension MusicViewModelTests {
    func makeViewModel(socket: MusicAssistantQueueSocket) -> MusicViewModel {
        makeViewModel(spotify: StubSpotifyPlaylistService(authorized: false), socket: socket)
    }

    func makeViewModel(spotify: SpotifyPlaylistService, socket: MusicAssistantQueueSocket) -> MusicViewModel {
        MusicViewModel(restAPIService: restAPIService,
                       setErrorBannerText: { [weak self] title, _ in self?.bannerTitles.append(title) },
                       spotify: spotify,
                       queueSocket: socket)
    }

    func stubGetQueue(json: String, statusCode: Int = 200) {
        var components = URLComponents(string: GlobalConstants.baseInternalUrlString)!
        components.path = "/api/services/music_assistant/get_queue"
        components.queryItems = [URLQueryItem(name: "return_response", value: "true")]
        let url = components.url!
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        URLProtocolStub.setStub(for: url, data: Data(json.utf8), response: response, error: nil)
    }

    private func queueItem(_ id: String, uri: String? = nil, title: String = "Song") -> MusicQueueItem {
        MusicQueueItem(queueItemID: id, uri: uri, title: title, artist: nil, imageURL: nil)
    }

    private var getQueueJSON: String {
        // queue_id present plus a current item; the socket supplies the full list.
        #"{"service_response":{"queue_id":"kitchen","current_item":{"queue_item_id":"cur","media_item":{"name":"Now"}}}}"#
    }

    // MARK: - Load

    func testLoadQueueSlicesUpcomingAfterCurrent() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        stubGetQueue(json: getQueueJSON)
        let socket = StubMusicAssistantQueueSocket(items: [
            queueItem("cur", title: "Now"),
            queueItem("next1", title: "Next One"),
            queueItem("next2", title: "Next Two")
        ])
        let model = makeViewModel(socket: socket)
        model.selectSpeaker(.mediaPlayerKitchen)
        await model.loadQueue()
        XCTAssertEqual(model.queue.queueID, "kitchen")
        XCTAssertEqual(model.queue.currentItem?.queueItemID, "cur")
        XCTAssertEqual(model.queue.upcomingItems.map(\.queueItemID), ["next1", "next2"])
    }

    func testLoadQueueFallsBackToSessionItemsWhenSocketEmpty() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        stubGetQueue(json: getQueueJSON)
        stubPlayMedia(statusCode: 200)
        let model = makeViewModel(socket: StubMusicAssistantQueueSocket(items: []))
        model.selectSpeaker(.mediaPlayerKitchen)
        await model.addToQueue(uri: "spotify://track/x", title: "Enqueued", artist: nil, imageURL: nil)
        await model.loadQueue()
        // Socket returns nothing, so the session-enqueued track is the fallback.
        XCTAssertEqual(model.queue.upcomingItems.map(\.title), ["Enqueued"])
    }

    func testLoadQueueShowsNextItemWhenSocketEmpty() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        // The socket is LAN-only; away from home it returns nothing. get_queue still
        // carries next_item over REST, so the up-next list shows at least that.
        let json = """
        {"service_response":{"queue_id":"kitchen","current_item":{"queue_item_id":"cur","media_item":{"name":"Now"}},
        "next_item":{"queue_item_id":"nxt","media_item":{"name":"Up Next"}}}}
        """
        stubGetQueue(json: json)
        let model = makeViewModel(socket: StubMusicAssistantQueueSocket(items: []))
        model.selectSpeaker(.mediaPlayerKitchen)
        await model.loadQueue()
        XCTAssertEqual(model.queue.upcomingItems.map(\.queueItemID), ["nxt"])
        XCTAssertEqual(model.queue.upcomingItems.map(\.title), ["Up Next"])
    }

    // MARK: - Add

    func testAddToQueueNextInsertsAtFront() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        stubPlayMedia(statusCode: 200)
        let model = makeViewModel(socket: StubMusicAssistantQueueSocket())
        model.selectSpeaker(.mediaPlayerKitchen)
        await model.addToQueue(uri: "spotify://track/a", title: "Last", artist: nil, imageURL: nil, placement: .last)
        await model.addToQueue(uri: "spotify://track/b", title: "Next", artist: nil, imageURL: nil, placement: .next)
        // .next jumps to the front of both the visible list and the session fallback.
        XCTAssertEqual(model.queue.upcomingItems.map(\.title), ["Next", "Last"])
        XCTAssertEqual(model.sessionEnqueuedItems.map(\.title), ["Next", "Last"])
    }

    func testAddToQueueAppendsOptimisticallyOnSuccess() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        stubPlayMedia(statusCode: 200)
        let model = makeViewModel(socket: StubMusicAssistantQueueSocket())
        model.selectSpeaker(.mediaPlayerKitchen)
        await model.addToQueue(uri: "spotify://track/x", title: "Enqueued", artist: "A", imageURL: nil)
        XCTAssertEqual(model.sessionEnqueuedItems.map(\.title), ["Enqueued"])
        XCTAssertEqual(model.queue.upcomingItems.map(\.title), ["Enqueued"])
        XCTAssertTrue(bannerTitles.isEmpty)
    }

    func testAddToQueueBannersOnFailure() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        stubPlayMedia(statusCode: 500)
        let model = makeViewModel(socket: StubMusicAssistantQueueSocket())
        model.selectSpeaker(.mediaPlayerKitchen)
        await model.addToQueue(uri: "spotify://track/x", title: "Enqueued", artist: nil, imageURL: nil)
        XCTAssertTrue(model.sessionEnqueuedItems.isEmpty)
        XCTAssertTrue(bannerTitles.contains("Kunde inte lägga till i kön"))
    }

    func testAddToQueueWithoutSpeakerBanners() async {
        let model = makeViewModel(socket: StubMusicAssistantQueueSocket())
        await model.addToQueue(uri: "spotify://track/x", title: "X", artist: nil, imageURL: nil)
        XCTAssertTrue(bannerTitles.contains("Ingen högtalare vald"))
    }

    // MARK: - Remove

    func testRemoveRealQueueItemCallsSocketAndDropsRow() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        stubGetQueue(json: getQueueJSON)
        let socket = StubMusicAssistantQueueSocket(items: [
            queueItem("cur", title: "Now"),
            queueItem("next1", title: "Next One")
        ])
        let model = makeViewModel(socket: socket)
        model.selectSpeaker(.mediaPlayerKitchen)
        await model.loadQueue()
        let target = model.queue.upcomingItems[0]
        await model.removeFromQueue(target)
        XCTAssertTrue(model.queue.upcomingItems.isEmpty)
        let deleted = await socket.deletedItemIDs
        XCTAssertEqual(deleted, ["next1"])
    }

    func testRemoveRealQueueItemRevertsAndBannersOnFailure() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        stubGetQueue(json: getQueueJSON)
        let socket = StubMusicAssistantQueueSocket(items: [
            queueItem("cur", title: "Now"),
            queueItem("next1", title: "Next One")
        ], deleteSucceeds: false)
        let model = makeViewModel(socket: socket)
        model.selectSpeaker(.mediaPlayerKitchen)
        await model.loadQueue()
        let target = model.queue.upcomingItems[0]
        await model.removeFromQueue(target)
        XCTAssertEqual(model.queue.upcomingItems.map(\.queueItemID), ["next1"])
        XCTAssertTrue(bannerTitles.contains("Kunde inte ta bort från kön"))
    }

    // MARK: - Grouping (I kö vs. playlist context)

    func testManualAddGroupsSeparatelyFromContext() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        stubGetQueue(json: getQueueJSON)
        stubPlayMedia(statusCode: 200)
        let socket = StubMusicAssistantQueueSocket(items: [
            queueItem("cur", title: "Now"),
            queueItem("ctx1", uri: "spotify://track/c1", title: "Context One"),
            queueItem("ctx2", uri: "spotify://track/c2", title: "Context Two")
        ])
        let model = makeViewModel(socket: socket)
        model.selectSpeaker(.mediaPlayerKitchen)
        await model.loadQueue()
        await model.addToQueue(uri: "spotify://track/m1", title: "Mine", artist: nil, imageURL: nil, placement: .last)
        // The hand-added track lands in "I kö"; the playlist tracks stay in context.
        XCTAssertEqual(model.queue.manualUpcoming.map(\.title), ["Mine"])
        XCTAssertEqual(model.queue.contextUpcoming.map(\.title), ["Context One", "Context Two"])
    }

    func testReconcileMapsSessionAddToRealQueueItemByURI() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        stubGetQueue(json: getQueueJSON)
        stubPlayMedia(statusCode: 200)
        let socket = StubMusicAssistantQueueSocket(items: [
            queueItem("cur", title: "Now"),
            queueItem("ctx1", uri: "spotify://track/c1", title: "Context One")
        ])
        let model = makeViewModel(socket: socket)
        model.selectSpeaker(.mediaPlayerKitchen)
        await model.loadQueue()
        await model.addToQueue(uri: "spotify://track/m1", title: "Mine", artist: nil, imageURL: nil, placement: .last)
        // The server now reports the manual add as a real queue item with a server id.
        await socket.setItems([
            queueItem("cur", title: "Now"),
            queueItem("ctx1", uri: "spotify://track/c1", title: "Context One"),
            queueItem("real-m1", uri: "spotify://track/m1", title: "Mine")
        ])
        await model.loadQueue()
        // The synthetic session id is swapped for the real one, so "I kö" still
        // points at the user's track and the playlist track stays in context.
        XCTAssertEqual(model.queue.manualUpcoming.map(\.queueItemID), ["real-m1"])
        XCTAssertEqual(model.queue.contextUpcoming.map(\.queueItemID), ["ctx1"])
    }

    func testStartingNewPlaybackClearsManualGrouping() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        stubPlayMedia(statusCode: 200)
        let model = makeViewModel(socket: StubMusicAssistantQueueSocket())
        model.selectSpeaker(.mediaPlayerKitchen)
        await model.addToQueue(uri: "spotify://track/m1", title: "Mine", artist: nil, imageURL: nil)
        XCTAssertFalse(model.manualQueueItemIDs.isEmpty)
        // Playing something new replaces the queue, so the manual grouping is dropped.
        let playlist = MusicSearchItem(uri: "spotify://playlist/p", name: "P", mediaType: .playlist, imageURL: nil, artist: nil)
        await model.play(item: playlist)
        XCTAssertTrue(model.manualQueueItemIDs.isEmpty)
        XCTAssertTrue(model.sessionEnqueuedItems.isEmpty)
    }

    func testRemovingManualTrackDropsItFromGroup() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        stubPlayMedia(statusCode: 200)
        let model = makeViewModel(socket: StubMusicAssistantQueueSocket())
        model.selectSpeaker(.mediaPlayerKitchen)
        await model.addToQueue(uri: "spotify://track/m1", title: "Mine", artist: nil, imageURL: nil)
        let manualTrack = model.queue.manualUpcoming[0]
        await model.removeFromQueue(manualTrack)
        XCTAssertTrue(model.queue.manualUpcoming.isEmpty)
        XCTAssertFalse(model.manualQueueItemIDs.contains(manualTrack.id))
    }

    func testRemoveSessionItemIsLocalOnlyNoSocketCall() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        stubPlayMedia(statusCode: 200)
        let socket = StubMusicAssistantQueueSocket(items: [])
        let model = makeViewModel(socket: socket)
        model.selectSpeaker(.mediaPlayerKitchen)
        await model.addToQueue(uri: "spotify://track/x", title: "Enqueued", artist: nil, imageURL: nil)
        let sessionItem = model.queue.upcomingItems[0]
        await model.removeFromQueue(sessionItem)
        XCTAssertTrue(model.queue.upcomingItems.isEmpty)
        XCTAssertTrue(model.sessionEnqueuedItems.isEmpty)
        let deleted = await socket.deletedItemIDs
        XCTAssertTrue(deleted.isEmpty)
    }
}
