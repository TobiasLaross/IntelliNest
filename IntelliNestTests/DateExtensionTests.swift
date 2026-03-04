@testable import IntelliNest
import XCTest

class DateExtensionTests: XCTestCase {
    // MARK: - fromISO8601

    // Date.fromISO8601 uses the format yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ.
    // Despite 'Z' being the RFC 822 specifier (+HHMM), Apple's DateFormatter
    // also accepts the ISO 8601 colon form (+HH:MM) in practice.
    func testFromISO8601ValidDate() {
        let result = Date.fromISO8601("2023-06-17T13:30:00.215607+0000")
        XCTAssertNotNil(result)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        let dateString = formatter.string(from: result!)
        XCTAssertEqual(dateString, "2023-06-17 13:30:00")
    }

    func testFromISO8601WithColonTimezoneAlsoParsesSuccessfully() {
        // Apple's DateFormatter accepts both +HHMM and +HH:MM timezone offsets
        // with the 'Z' specifier. Home Assistant sends +00:00 — confirm it works.
        let result = Date.fromISO8601("2023-06-17T13:30:00.215607+00:00")
        XCTAssertNotNil(result, "fromISO8601 should parse the +HH:MM timezone format used by Home Assistant")
    }

    func testFromISO8601InvalidDateReturnsNil() {
        let result = Date.fromISO8601("not-a-date")
        XCTAssertNil(result)
    }

    func testFromISO8601NilInputReturnsNil() {
        let result = Date.fromISO8601(nil)
        XCTAssertNil(result)
    }

    func testFromISO8601EmptyStringReturnsNil() {
        let result = Date.fromISO8601("")
        XCTAssertNil(result)
    }

    // MARK: - humanReadable

    func testHumanReadableJustNow() {
        let now = Date()
        XCTAssertEqual(now.humanReadable, "Just now")
    }

    func testHumanReadable1MinuteAgo() {
        let oneMinuteAgo = Date().addingTimeInterval(-60)
        XCTAssertEqual(oneMinuteAgo.humanReadable, "1 minute ago")
    }

    func testHumanReadableMultipleMinutesAgo() {
        let fiveMinutesAgo = Date().addingTimeInterval(-5 * 60)
        XCTAssertEqual(fiveMinutesAgo.humanReadable, "5 minutes ago")
    }

    func testHumanReadable59MinutesAgoIsStillMinutes() {
        let fiftyNineMinutesAgo = Date().addingTimeInterval(-59 * 60)
        XCTAssertTrue(fiftyNineMinutesAgo.humanReadable.hasSuffix("minutes ago"))
    }

    func testHumanReadable1HourAgo() {
        let oneHourAgo = Date().addingTimeInterval(-60 * 60)
        XCTAssertEqual(oneHourAgo.humanReadable, "1 hour ago")
    }

    func testHumanReadableMultipleHoursAgo() {
        let threeHoursAgo = Date().addingTimeInterval(-3 * 60 * 60)
        XCTAssertEqual(threeHoursAgo.humanReadable, "3 hours ago")
    }

    func testHumanReadable23HoursAgoIsStillHours() {
        let twentyThreeHoursAgo = Date().addingTimeInterval(-23 * 60 * 60)
        XCTAssertTrue(twentyThreeHoursAgo.humanReadable.hasSuffix("hours ago"))
    }

    func testHumanReadableYesterday() {
        // Midnight yesterday is always ≥24h before now, so it skips the "<24 hours ago"
        // branch and reaches the isDateInYesterday check, returning "Yesterday".
        // Noon yesterday would be <24h ago in the morning and return "N hours ago".
        let midnightYesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!
        XCTAssertEqual(midnightYesterday.humanReadable, "Yesterday")
    }

    func testHumanReadableOlderDatesReturnFormattedString() {
        let twoDaysAgo = Date().addingTimeInterval(-2 * 24 * 60 * 60)
        let result = twoDaysAgo.humanReadable
        // Should not match any of the relative formats
        XCTAssertFalse(result.contains("minute"))
        XCTAssertFalse(result.contains("hour"))
        XCTAssertNotEqual(result, "Yesterday")
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - daysRemainingDescription

    func testDaysRemainingTodayReturnsIdag() {
        let today = Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 60 * 60)
        XCTAssertEqual(today.daysRemainingDescription(), "idag")
    }

    func testDaysRemainingTomorrowReturnsImorgon() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
        XCTAssertEqual(tomorrow.daysRemainingDescription(), "imorgon")
    }

    func testDaysRemainingTwoDaysAwayReturnsNil() {
        let twoDays = Calendar.current.date(byAdding: .day, value: 2, to: Calendar.current.startOfDay(for: Date()))!
        XCTAssertNil(twoDays.daysRemainingDescription())
    }

    func testDaysRemainingInThePastReturnsNil() {
        // Use midnight yesterday: always exactly -1 calendar day from startOfDay(today),
        // so dateComponents([.day]) returns -1 → default case → nil.
        // Using "now - 24h" would land at today's current time yesterday, which is
        // 0 full days before startOfDay(today) and would incorrectly return "idag".
        let midnightYesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!
        XCTAssertNil(midnightYesterday.daysRemainingDescription())
    }

    // MARK: - minutesLeft

    func testMinutesLeftInFuture() {
        let thirtyMinutesFromNow = Date().addingTimeInterval(30 * 60)
        let result = thirtyMinutesFromNow.minutesLeft()
        // Allow ±1 minute due to test execution time
        XCTAssertTrue(result >= 29 && result <= 30, "Expected ~30 minutes, got \(result)")
    }

    func testMinutesLeftInPast() {
        let thirtyMinutesAgo = Date().addingTimeInterval(-30 * 60)
        let result = thirtyMinutesAgo.minutesLeft()
        // Past date returns negative minutes
        XCTAssertTrue(result < 0, "Expected negative minutes for a past date, got \(result)")
    }

    func testMinutesLeftNow() {
        let now = Date()
        let result = now.minutesLeft()
        // Should be 0 or -1 depending on exact timing
        XCTAssertTrue(result >= -1 && result <= 0, "Expected ~0 minutes for now, got \(result)")
    }

    func testMinutesLeftOneHourFromNow() {
        let oneHourFromNow = Date().addingTimeInterval(60 * 60)
        let result = oneHourFromNow.minutesLeft()
        XCTAssertTrue(result >= 59 && result <= 60, "Expected ~60 minutes, got \(result)")
    }
}
