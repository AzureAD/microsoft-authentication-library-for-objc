import XCTest
@testable import App

final class AuthenticationValidationTests: XCTestCase {
    func testEmailIsTrimmedAndLowercased() {
        XCTAssertEqual(normalizedEmail("  Person@Example.COM  "), "person@example.com")
    }

    func testRejectsMalformedEmailAddresses() {
        XCTAssertNil(normalizedEmail("not-an-email"))
        XCTAssertNil(normalizedEmail("@example.com"))
        XCTAssertNil(normalizedEmail("person@example"))
        XCTAssertNil(normalizedEmail("person @example.com"))
    }

    func testPasswordPolicy() {
        XCTAssertTrue(isStrongPassword("CorrectHorse123"))
        XCTAssertFalse(isStrongPassword("short1A"))
        XCTAssertFalse(isStrongPassword("alllowercase123"))
        XCTAssertFalse(isStrongPassword("ALLUPPERCASE123"))
    }

    func testBase64URLDecoding() {
        XCTAssertEqual(decodeBase64URL("aGVsbG8"), Array("hello".utf8))
        XCTAssertNil(decodeBase64URL("not valid!"))
    }
}
