@testable import IntelliNest
import XCTest

final class MarqueeScrollTests: XCTestCase {
    private let longTitle = MarqueeScroll(textWidth: 260,
                                          containerWidth: 200,
                                          gap: 40,
                                          pointsPerSecond: 30,
                                          pause: 2)

    func testOverflowsOnlyWhenTextIsWiderThanItsFrame() {
        struct OverflowCase {
            let textWidth: CGFloat
            let containerWidth: CGFloat
            let overflows: Bool
        }
        let cases = [
            OverflowCase(textWidth: 120, containerWidth: 200, overflows: false),
            OverflowCase(textWidth: 200, containerWidth: 200, overflows: false),
            OverflowCase(textWidth: 200.4, containerWidth: 200, overflows: false),
            OverflowCase(textWidth: 201, containerWidth: 200, overflows: true),
            OverflowCase(textWidth: 0, containerWidth: 0, overflows: false)
        ]
        for testCase in cases {
            let scroll = MarqueeScroll(textWidth: testCase.textWidth, containerWidth: testCase.containerWidth)
            XCTAssertEqual(scroll.overflows, testCase.overflows, "text \(testCase.textWidth) in \(testCase.containerWidth)")
        }
    }

    func testCycleIsThePausePlusOnePassOfTextAndGap() {
        XCTAssertEqual(longTitle.distance, 300)
        XCTAssertEqual(longTitle.cycleDuration, 12, accuracy: 0.0001)
    }

    func testOffsetRestsThenScrollsLeftAndWrapsToTheStart() {
        let cases: [(elapsed: TimeInterval, offset: CGFloat)] = [
            (elapsed: -1, offset: 0),
            (elapsed: 0, offset: 0),
            (elapsed: 1.5, offset: 0),
            (elapsed: 2, offset: 0),
            (elapsed: 3, offset: -30),
            (elapsed: 7, offset: -150),
            (elapsed: 11.9, offset: -297),
            (elapsed: 12, offset: 0),
            (elapsed: 13, offset: 0),
            (elapsed: 15, offset: -30)
        ]
        for testCase in cases {
            XCTAssertEqual(longTitle.offset(after: testCase.elapsed),
                           testCase.offset,
                           accuracy: 0.0001,
                           "elapsed \(testCase.elapsed)")
        }
    }

    func testTextThatFitsNeverMoves() {
        let shortTitle = MarqueeScroll(textWidth: 120, containerWidth: 200)
        for elapsed in [0.0, 3, 10, 100] {
            XCTAssertEqual(shortTitle.offset(after: elapsed), 0)
        }
    }
}
