@testable import IntelliNest
import XCTest

final class LyricsTimelineTests: XCTestCase {
    private let lrc = """
    [ar: Test Artist]
    [ti: Test Song]
    [00:01.00]First line
    [00:03.50]Second line
    [00:03.50]Repeated stamp
    [01:00.00]Last line
    """

    func testParseLRCExtractsTimedLinesAndDropsMetadata() {
        let lines = LyricsTimeline.parseLRC(lrc)
        XCTAssertEqual(lines.count, 4)
        XCTAssertEqual(lines[0], LyricLine(time: 1.0, text: "First line"))
        XCTAssertEqual(lines[1].time, 3.5)
        XCTAssertEqual(lines[3], LyricLine(time: 60.0, text: "Last line"))
    }

    func testParseLRCSupportsMultipleStampsOnOneLine() {
        let lines = LyricsTimeline.parseLRC("[00:10.00][00:20.00]chorus")
        XCTAssertEqual(lines, [
            LyricLine(time: 10.0, text: "chorus"),
            LyricLine(time: 20.0, text: "chorus")
        ])
    }

    func testParseLRCReturnsEmptyForPlainText() {
        XCTAssertTrue(LyricsTimeline.parseLRC("just\nplain\nlyrics").isEmpty)
    }

    func testCurrentLineIndexAcrossElapsedValues() {
        let lines = LyricsTimeline.parseLRC(lrc)
        let cases: [(elapsed: TimeInterval, expected: Int?)] = [
            (0.0, nil), // before the first line
            (1.0, 0), // exactly on the first line
            (2.0, 0),
            (3.5, 2), // last line at-or-before 3.5 (the repeated stamp wins)
            (59.0, 2),
            (120.0, 3) // past the last line
        ]
        for testCase in cases {
            XCTAssertEqual(LyricsTimeline.currentLineIndex(in: lines, at: testCase.elapsed),
                           testCase.expected,
                           "elapsed \(testCase.elapsed)")
        }
    }

    func testCurrentLineIndexEmptyLines() {
        XCTAssertNil(LyricsTimeline.currentLineIndex(in: [], at: 5))
    }

    func testOffsetAlignsChosenLineToNow() {
        let lines = LyricsTimeline.parseLRC(lrc)
        let elapsed = 12.0
        // Realign so line 3 ("Last line", at 60s) is current right now.
        let offset = LyricsTimeline.offset(toAlign: 3, in: lines, at: elapsed)
        XCTAssertEqual(offset, 48.0)
        XCTAssertEqual(LyricsTimeline.currentLineIndex(in: lines, at: elapsed + offset), 3)
    }

    func testOffsetOutOfRangeIsZero() {
        let lines = LyricsTimeline.parseLRC(lrc)
        XCTAssertEqual(LyricsTimeline.offset(toAlign: 99, in: lines, at: 5), 0)
    }
}
