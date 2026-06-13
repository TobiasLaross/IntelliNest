@testable import IntelliNest
import XCTest

/// Decoding coverage for the Music Assistant queue payloads: the `get_queue`
/// REST body (which carries the queue id and current item) and the queue-item
/// shape shared with the WebSocket `player_queues/items` list.
final class MusicQueueModelTests: XCTestCase {
    func testGetQueueParsesServiceResponseEnvelope() {
        let json = """
        {"service_response":{"queue_id":"kitchen","current_item":{"queue_item_id":"item-1",
        "media_item":{"uri":"spotify://track/abc","name":"Röda sten","artists":[{"name":"Albin Lee Meldau"}]}}}}
        """
        let result = MusicGetQueueParser.parse(Data(json.utf8))
        XCTAssertEqual(result.queueID, "kitchen")
        XCTAssertEqual(result.currentItem?.queueItemID, "item-1")
        XCTAssertEqual(result.currentItem?.title, "Röda sten")
        XCTAssertEqual(result.currentItem?.artist, "Albin Lee Meldau")
        XCTAssertEqual(result.currentItem?.uri, "spotify://track/abc")
    }

    func testGetQueueParsesEntityKeyedShape() {
        let json = """
        {"service_response":{"media_player.kitchen":{"queue_id":"kitchen","current_item":{"queue_item_id":"item-9",
        "name":"Fallback Name"}}}}
        """
        let result = MusicGetQueueParser.parse(Data(json.utf8))
        XCTAssertEqual(result.queueID, "kitchen")
        XCTAssertEqual(result.currentItem?.queueItemID, "item-9")
        // No media_item, so the queue item's own name is used.
        XCTAssertEqual(result.currentItem?.title, "Fallback Name")
    }

    func testGetQueueParsesDirectShape() {
        let json = #"{"queue_id":"spa","current_item":{"queue_item_id":"i1","media_item":{"name":"Låt"}}}"#
        let result = MusicGetQueueParser.parse(Data(json.utf8))
        XCTAssertEqual(result.queueID, "spa")
        XCTAssertEqual(result.currentItem?.title, "Låt")
    }

    func testGetQueueReturnsEmptyForUnexpectedBody() {
        let result = MusicGetQueueParser.parse(Data("not json".utf8))
        XCTAssertNil(result.queueID)
        XCTAssertNil(result.currentItem)
    }

    func testGetQueueParsesNextItem() {
        let json = """
        {"service_response":{"queue_id":"kitchen","current_item":{"queue_item_id":"cur","media_item":{"name":"Now"}},
        "next_item":{"queue_item_id":"nxt","media_item":{"name":"Up Next","artists":[{"name":"Band"}]}}}}
        """
        let result = MusicGetQueueParser.parse(Data(json.utf8))
        XCTAssertEqual(result.nextItem?.queueItemID, "nxt")
        XCTAssertEqual(result.nextItem?.title, "Up Next")
        XCTAssertEqual(result.nextItem?.artist, "Band")
    }

    func testQueuePlacementMapsToEnqueueMode() {
        XCTAssertEqual(QueuePlacement.next.enqueueMode, "next")
        XCTAssertEqual(QueuePlacement.last.enqueueMode, "add")
    }

    func testGetQueueParsesCurrentItemWithStringImage() {
        // `get_queue` serializes `media_item.image` as a bare URL string (not the
        // object the socket sends). A strict object decode threw and lost the whole
        // queue, leaving queue_id nil and the upcoming list silently empty.
        let json = """
        {"service_response":{"media_player.kitchen":{"queue_id":"kitchen","current_item":{"queue_item_id":"item-1",
        "media_item":{"uri":"spotify://track/abc","name":"Det sista jag behöver","artists":[{"name":"Darin"}],
        "image":"https://i.scdn.co/image/cover.jpg"}}}}}
        """
        let result = MusicGetQueueParser.parse(Data(json.utf8))
        XCTAssertEqual(result.queueID, "kitchen")
        XCTAssertEqual(result.currentItem?.title, "Det sista jag behöver")
        XCTAssertEqual(result.currentItem?.imageURL, "https://i.scdn.co/image/cover.jpg")
    }

    func testQueueItemDecodesObjectImageFromSocket() {
        // The socket sends `image` as an object with a `path`; both shapes resolve.
        let json = #"{"queue_item_id":"i1","image":{"path":"https://i.scdn.co/image/sock.jpg"},"media_item":{"name":"X"}}"#
        let dto = try? JSONDecoder().decode(MusicQueueItemDTO.self, from: Data(json.utf8))
        XCTAssertEqual(dto?.queueItem?.imageURL, "https://i.scdn.co/image/sock.jpg")
    }

    func testQueueItemDropsNonHttpImage() {
        let json = """
        {"queue_item_id":"i1","media_item":{"uri":"spotify://track/x","name":"X",
        "metadata":{"images":[{"path":"local/file.png"},{"path":"https://img/cover.jpg"}]}}}
        """
        let dto = try? JSONDecoder().decode(MusicQueueItemDTO.self, from: Data(json.utf8))
        // The first remotely-reachable (http) image wins; the local path is skipped.
        XCTAssertEqual(dto?.queueItem?.imageURL, "https://img/cover.jpg")
    }

    func testQueueItemListDecodesForWebSocketItems() {
        let json = """
        [{"queue_item_id":"a","media_item":{"uri":"spotify://track/1","name":"One"}},
         {"queue_item_id":"b","media_item":{"uri":"spotify://track/2","name":"Two","artists":[{"name":"Band"}]}}]
        """
        let items = try? JSONDecoder().decode([MusicQueueItemDTO].self, from: Data(json.utf8))
        let mapped = items?.compactMap(\.queueItem)
        XCTAssertEqual(mapped?.map(\.queueItemID), ["a", "b"])
        XCTAssertEqual(mapped?.last?.title, "Two")
        XCTAssertEqual(mapped?.last?.artist, "Band")
    }
}
