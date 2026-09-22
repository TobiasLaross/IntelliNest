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

    func testRecordPutsNewestFirstAndDedupesIgnoringCase() {
        let searches = RecentMusicSearches(defaults: defaults)
        searches.record("Brynäs")
        searches.record("Miriam Bryant")
        searches.record("  brynäs ")
        XCTAssertEqual(searches.queries, ["brynäs", "Miriam Bryant"])
    }

    func testRecordIgnoresQueriesShorterThanTheSearchMinimum() {
        let searches = RecentMusicSearches(defaults: defaults)
        for query in ["", "   ", "a"] {
            searches.record(query)
        }
        XCTAssertEqual(searches.queries, [])
    }

    func testRecordKeepsOnlyTheNewestTen() {
        let searches = RecentMusicSearches(defaults: defaults)
        for index in 1 ... 12 {
            searches.record("Sökning \(index)")
        }
        XCTAssertEqual(searches.queries.count, RecentMusicSearches.maximumCount)
        XCTAssertEqual(searches.queries.first, "Sökning 12")
        XCTAssertEqual(searches.queries.last, "Sökning 3")
    }

    func testRemoveAndClearPersistAcrossInstances() {
        let searches = RecentMusicSearches(defaults: defaults)
        searches.record("Victor Leksell")
        searches.record("Håkan")
        searches.remove("Håkan")
        XCTAssertEqual(RecentMusicSearches(defaults: defaults).queries, ["Victor Leksell"])

        searches.clear()
        XCTAssertEqual(RecentMusicSearches(defaults: defaults).queries, [])
    }
}
