@testable import IntelliNest
import XCTest

final class VolumeButtonPressDetectorTests: XCTestCase {
    func testRestingVolumeIsMovedInFromTheEnds() {
        let cases: [(starting: Float, resting: Float)] = [(0, 0.1), (0.05, 0.1), (0.5, 0.5), (0.95, 0.9), (1, 0.9)]
        for testCase in cases {
            let detector = VolumeButtonPressDetector(startingVolume: testCase.starting)
            XCTAssertEqual(detector.restingVolume, testCase.resting, "starting at \(testCase.starting)")
        }
    }

    func testPressDirection() {
        let detector = VolumeButtonPressDetector(startingVolume: 0.5)
        let cases: [(volume: Float, raising: Bool?)] = [(0.5625, true), (0.625, true), (0.4375, false), (0.5, nil)]
        for testCase in cases {
            XCTAssertEqual(detector.isRaising(newVolume: testCase.volume), testCase.raising, "volume \(testCase.volume)")
        }
    }

    func testMiniPlayerSwipeDirection() {
        let cases: [(translation: CGSize, swipe: MiniPlayerSwipe?)] = [
            (CGSize(width: -80, height: 5), .next),
            (CGSize(width: 80, height: -5), .previous),
            (CGSize(width: -40, height: 0), nil),
            (CGSize(width: 70, height: 120), nil)
        ]
        for testCase in cases {
            XCTAssertEqual(MiniPlayerSwipe(translation: testCase.translation), testCase.swipe, "\(testCase.translation)")
        }
    }
}
