@testable import IntelliNest
import XCTest

@MainActor
final class RecentMusicSearchesTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "RecentMusicSearchesTests")
        defaults.removePersistentDomain(forName: "RecentMusicSearchesTests")
    }

    private func item(_ name: String, mediaType: MusicMediaType = .track) -> MusicSearchItem {
        MusicSearchItem(uri: "spotify://\(mediaType.rawValue)/\(name)", name: name, mediaType: mediaType,
                        imageURL: "https://i.scdn.co/image/ab67616d0000b273", artist: "Victor Leksell")
    }

    func testRecordPutsNewestFirstAndDedupesByURI() {
        let searches = RecentMusicSearches(defaults: defaults)
        searches.record(item("Tänk om"))
        searches.record(item("Victor Leksell", mediaType: .artist))
        searches.record(item("Tänk om"))
        XCTAssertEqual(searches.items.map(\.name), ["Tänk om", "Victor Leksell"])
    }

    func testRecordKeepsOnlyTheNewestTen() {
        let searches = RecentMusicSearches(defaults: defaults)
        for index in 1 ... 12 {
            searches.record(item("Låt \(index)"))
        }
        XCTAssertEqual(searches.items.count, RecentMusicSearches.maximumCount)
        XCTAssertEqual(searches.items.first?.name, "Låt 12")
        XCTAssertEqual(searches.items.last?.name, "Låt 3")
    }

    func testItemsSurviveAcrossInstancesWithEveryField() {
        let searches = RecentMusicSearches(defaults: defaults)
        let artist = item("Victor Leksell", mediaType: .artist)
        searches.record(artist)
        XCTAssertEqual(RecentMusicSearches(defaults: defaults).items, [artist])
    }

    func testRemoveAndClearPersistAcrossInstances() {
        let searches = RecentMusicSearches(defaults: defaults)
        searches.record(item("Natthimlen"))
        searches.record(item("Eld & lågor"))
        searches.remove(item("Eld & lågor"))
        XCTAssertEqual(RecentMusicSearches(defaults: defaults).items.map(\.name), ["Natthimlen"])

        searches.clear()
        XCTAssertEqual(RecentMusicSearches(defaults: defaults).items, [])
    }
}
