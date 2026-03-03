@testable import IntelliNest
import XCTest

class StringExtensionTests: XCTestCase {
    // MARK: - removingHTTPSchemeAndTrailingSlash

    func testRemovingHTTPScheme() {
        XCTAssertEqual("http://example.com".removingHTTPSchemeAndTrailingSlash, "example.com")
    }

    func testRemovingHTTPSScheme() {
        XCTAssertEqual("https://example.com".removingHTTPSchemeAndTrailingSlash, "example.com")
    }

    func testRemovingTrailingSlash() {
        XCTAssertEqual("example.com/".removingHTTPSchemeAndTrailingSlash, "example.com")
    }

    func testRemovingSchemeAndTrailingSlash() {
        XCTAssertEqual("https://example.com/".removingHTTPSchemeAndTrailingSlash, "example.com")
    }

    func testRemovingSchemeWithPath() {
        XCTAssertEqual("http://example.com/api/".removingHTTPSchemeAndTrailingSlash, "example.com/api")
    }

    func testNoSchemeNoSlashUnchanged() {
        XCTAssertEqual("example.com".removingHTTPSchemeAndTrailingSlash, "example.com")
    }

    // MARK: - removingTrailingSlash

    func testRemovingTrailingSlashOnly() {
        XCTAssertEqual("path/to/resource/".removingTrailingSlash, "path/to/resource")
    }

    func testNoTrailingSlashUnchanged() {
        XCTAssertEqual("path/to/resource".removingTrailingSlash, "path/to/resource")
    }

    func testEmptyStringRemovingTrailingSlash() {
        XCTAssertEqual("".removingTrailingSlash, "")
    }

    // MARK: - toKW

    func testToKWValidNumber() {
        // "1000" → 1000W = 1.0kW
        XCTAssertEqual("1000".toKW, "1.0kW")
    }

    func testToKWSmallValueReturnsZero() {
        XCTAssertEqual("59".toKW, "0kW")
    }

    func testToKWNegativeValue() {
        XCTAssertEqual("-1000".toKW, "-1.0kW")
    }

    func testToKWInvalidStringReturnsFallback() {
        XCTAssertEqual("not-a-number".toKW, "?kW")
    }

    func testToKWEmptyStringReturnsFallback() {
        XCTAssertEqual("".toKW, "?kW")
    }

    // MARK: - toKWh

    func testToKWhValidNumber() {
        XCTAssertEqual("5.5".toKWh, "5.5kWh")
    }

    func testToKWhZeroReturnsIntegerFormat() {
        XCTAssertEqual("0".toKWh, "0kWh")
    }

    func testToKWhRoundsToOneDecimal() {
        XCTAssertEqual("12.34".toKWh, "12.3kWh")
    }

    func testToKWhInvalidStringReturnsFallback() {
        XCTAssertEqual("abc".toKWh, "?kWh")
    }

    // MARK: - toOre

    func testToOreValidDecimal() {
        // "0.42" → 0.42 * 100 = 42 → "42 Öre"
        XCTAssertEqual("0.42".toOre, "42 Öre")
    }

    func testToOreRoundsCorrectly() {
        // "0.425" → 42.5 → rounds to 43
        XCTAssertEqual("0.425".toOre, "43 Öre")
    }

    func testToOreZero() {
        XCTAssertEqual("0".toOre, "0 Öre")
    }

    func testToOreInvalidStringReturnsFallback() {
        XCTAssertEqual("bad".toOre, "? Öre")
    }

    // MARK: - toKr

    func testToKrValidDecimal() {
        XCTAssertEqual("1.5".toKr, "1.5 Kr")
    }

    func testToKrRoundsToOneDecimal() {
        XCTAssertEqual("1.25".toKr, "1.3 Kr")
    }

    func testToKrZero() {
        XCTAssertEqual("0".toKr, "0.0 Kr")
    }

    func testToKrInvalidStringReturnsFallback() {
        XCTAssertEqual("nope".toKr, "? Kr")
    }

    // MARK: - roundedWithOneDecimal

    func testRoundedWithOneDecimalValidString() {
        XCTAssertEqual("3.456".roundedWithOneDecimal, 3.5, accuracy: 0.001)
    }

    func testRoundedWithOneDecimalInvalidStringReturnsZero() {
        XCTAssertEqual("abc".roundedWithOneDecimal, 0.0)
    }

    // MARK: - addNewLineAndAppend

    func testAddNewLineAndAppendToEmptyString() {
        var text = ""
        text.addNewLineAndAppend("Hello")
        XCTAssertEqual(text, "Hello")
    }

    func testAddNewLineAndAppendToNonEmptyString() {
        var text = "First"
        text.addNewLineAndAppend("Second")
        XCTAssertEqual(text, "First\nSecond")
    }

    func testAddNewLineAndAppendMultipleTimes() {
        var text = ""
        text.addNewLineAndAppend("Line 1")
        text.addNewLineAndAppend("Line 2")
        text.addNewLineAndAppend("Line 3")
        XCTAssertEqual(text, "Line 1\nLine 2\nLine 3")
    }

    // MARK: - removeDoubleSpaces

    func testRemoveDoubleSpaces() {
        XCTAssertEqual("Hello  World".removeDoubleSpaces, "Hello World")
    }

    func testRemoveMultipleConsecutiveSpaces() {
        XCTAssertEqual("a   b    c".removeDoubleSpaces, "a b c")
    }

    func testSingleSpacesUnchanged() {
        XCTAssertEqual("Hello World".removeDoubleSpaces, "Hello World")
    }

    func testEmptyStringRemoveDoubleSpaces() {
        XCTAssertEqual("".removeDoubleSpaces, "")
    }
}
