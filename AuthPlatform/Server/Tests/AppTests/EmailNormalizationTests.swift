import XCTest
@testable import App

final class EmailNormalizationTests: XCTestCase {
    func testEmailIsTrimmedAndLowercased() {
        XCTAssertEqual(normalizedEmail("  Person@Example.COM  "), "person@example.com")
    }

    func testRejectsMalformedEmailAddresses() {
        XCTAssertNil(normalizedEmail("not-an-email"))
        XCTAssertNil(normalizedEmail("@example.com"))
        XCTAssertNil(normalizedEmail("person@example"))
        XCTAssertNil(normalizedEmail("person @example.com"))
    }
}
