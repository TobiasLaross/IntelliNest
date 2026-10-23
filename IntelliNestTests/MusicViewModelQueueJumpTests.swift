@testable import IntelliNest
import XCTest

@MainActor
extension MusicViewModelTests {
    func queueItem(_ id: String, uri: String? = nil, title: String = "Song") -> MusicQueueItem {
        MusicQueueItem(queueItemID: id, uri: uri, title: title, artist: nil, imageURL: nil)
    }

    var getQueueJSON: String {
        // queue_id present plus a current item; the socket supplies the full list.
        #"{"service_response":{"queue_id":"kitchen","current_item":{"queue_item_id":"cur","media_item":{"name":"Now"}}}}"#
    }

    private func loadedQueueModel(socket: StubMusicAssistantQueueSocket) async -> MusicViewModel {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        stubGetQueue(json: getQueueJSON)
        let model = makeViewModel(socket: socket)
        model.selectSpeaker(.mediaPlayerKitchen)
        await model.loadQueue()
        return model
    }

    func testPlayQueueItemJumpsAndSkipsEarlierTracks() async {
        let socket = StubMusicAssistantQueueSocket(items: [
            queueItem("cur", title: "Now"),
            queueItem("next1", title: "Next One"),
            queueItem("next2", title: "Next Two"),
            queueItem("next3", title: "Next Three")
        ])
        let model = await loadedQueueModel(socket: socket)

        await model.playQueueItem(model.queue.upcomingItems[1])

        XCTAssertEqual(model.queue.currentItem?.queueItemID, "next2")
        XCTAssertEqual(model.queue.upcomingItems.map(\.queueItemID), ["next3"])
        let played = await socket.playedItemIDs
        XCTAssertEqual(played, ["next2"])
    }

    func testPlayQueueItemRevertsAndBannersOnFailure() async {
        let socket = StubMusicAssistantQueueSocket(items: [
            queueItem("cur", title: "Now"),
            queueItem("next1", title: "Next One"),
            queueItem("next2", title: "Next Two")
        ])
        await socket.setPlaySucceeds(false)
        let model = await loadedQueueModel(socket: socket)

        await model.playQueueItem(model.queue.upcomingItems[1])

        XCTAssertEqual(model.queue.currentItem?.queueItemID, "cur")
        XCTAssertEqual(model.queue.upcomingItems.map(\.queueItemID), ["next1", "next2"])
        XCTAssertTrue(bannerTitles.contains("Kunde inte spela låten"))
    }

    func testPlayQueueItemDropsSkippedManualTracks() async {
        stubPlayMedia(statusCode: 200)
        let socket = StubMusicAssistantQueueSocket(items: [
            queueItem("cur", title: "Now"),
            queueItem("manual1", uri: "spotify://track/m", title: "Mine"),
            queueItem("ctx1", title: "Context One"),
            queueItem("ctx2", title: "Context Two")
        ])
        let model = await loadedQueueModel(socket: socket)
        await model.addToQueue(uri: "spotify://track/m", title: "Mine", artist: nil, imageURL: nil, placement: .next)
        await model.loadQueue()
        XCTAssertEqual(model.queue.manualUpcoming.map(\.queueItemID), ["manual1"])

        await model.playQueueItem(model.queue.contextUpcoming[0])

        XCTAssertTrue(model.queue.manualUpcoming.isEmpty)
        XCTAssertTrue(model.sessionEnqueuedItems.isEmpty)
        XCTAssertEqual(model.queue.upcomingItems.map(\.queueItemID), ["ctx2"])
    }

    func testPlayQueueItemIgnoresSessionOnlyRow() async {
        stubPlayMedia(statusCode: 200)
        let socket = StubMusicAssistantQueueSocket(items: [])
        let model = await loadedQueueModel(socket: socket)
        await model.addToQueue(uri: "spotify://track/x", title: "Enqueued", artist: nil, imageURL: nil)
        let sessionRow = model.queue.upcomingItems[0]

        XCTAssertFalse(model.canPlayQueueItem(sessionRow))
        await model.playQueueItem(sessionRow)

        XCTAssertEqual(model.queue.upcomingItems.map(\.title), ["Enqueued"])
        let played = await socket.playedItemIDs
        XCTAssertTrue(played.isEmpty)
    }
}
