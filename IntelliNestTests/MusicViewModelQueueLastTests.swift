@testable import IntelliNest
import XCTest

/// "Sist i kön" places a track after the user's own queue but ahead of the rest
/// of the playing playlist, which takes a `next` add plus a socket move.
@MainActor
extension MusicViewModelTests {
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
        // The hand-added track lands in "I kö", ahead of the rest of the playlist.
        XCTAssertEqual(model.queue.upcomingItems.map(\.title), ["Mine", "Context One", "Context Two"])
        XCTAssertEqual(model.queue.manualUpcoming.map(\.title), ["Mine"])
        // Nothing queued by hand yet, so `next` already puts it in place: no move.
        let moves = await socket.movedItems
        XCTAssertTrue(moves.isEmpty)
    }

    func testAddLastMovesPastEarlierManualTracksButNotPastPlaylist() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        stubGetQueue(json: getQueueJSON)
        stubPlayMedia(statusCode: 200)
        let socket = StubMusicAssistantQueueSocket(items: [
            queueItem("cur", title: "Now"),
            queueItem("ctx1", uri: "spotify://track/c1", title: "Context One")
        ])
        let model = makeViewModel(socket: socket)
        model.selectSpeaker(.mediaPlayerKitchen)
        await model.addToQueue(uri: "spotify://track/m1", title: "First", artist: nil, imageURL: nil, placement: .last)
        let first = queueItem("real-m1", uri: "spotify://track/m1", title: "First")
        let context = queueItem("ctx1", uri: "spotify://track/c1", title: "Context One")
        // Before the second add the live queue holds the first manual track; `next`
        // then lands the second one straight after the current track.
        await socket.setPendingReads([
            [queueItem("cur", title: "Now"), first, context],
            [queueItem("cur", title: "Now"), queueItem("real-m2", uri: "spotify://track/m2", title: "Second"), first, context]
        ])
        await model.addToQueue(uri: "spotify://track/m2", title: "Second", artist: nil, imageURL: nil, placement: .last)
        let moves = await socket.movedItems
        XCTAssertEqual(moves.map(\.itemID), ["real-m2"])
        XCTAssertEqual(moves.map(\.positions), [1])
        XCTAssertEqual(model.queue.upcomingItems.map(\.title), ["First", "Second", "Context One"])
    }

    func testAddLastSkipsMoveWhenJustQueuedTrackIsNotNext() async {
        viewModel.selectSpeaker(.mediaPlayerKitchen)
        stubGetQueue(json: getQueueJSON)
        stubPlayMedia(statusCode: 200)
        let first = queueItem("real-m1", uri: "spotify://track/m1", title: "First")
        let socket = StubMusicAssistantQueueSocket(items: [queueItem("cur", title: "Now"), first])
        let model = makeViewModel(socket: socket)
        model.selectSpeaker(.mediaPlayerKitchen)
        await model.addToQueue(uri: "spotify://track/m1", title: "First", artist: nil, imageURL: nil, placement: .last)
        // The socket still shows only the first track, so the second isn't found
        // where `next` should have put it, and nothing is moved.
        await model.addToQueue(uri: "spotify://track/m2", title: "Second", artist: nil, imageURL: nil, placement: .last)
        let moves = await socket.movedItems
        XCTAssertTrue(moves.isEmpty)
    }
}
