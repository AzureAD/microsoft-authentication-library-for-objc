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
        XCTAssertFalse(isStrongPassword(String(repeating: "A", count: 129) + "a1"))
    }

    func testBase64URLDecoding() {
        XCTAssertEqual(decodeBase64URL("aGVsbG8"), Array("hello".utf8))
        XCTAssertNil(decodeBase64URL("not valid!"))
    }

    func testOpaqueTokenUsesURLSafeEncodingAndFreshRandomness() {
        let tokens = (0..<64).map { _ in secureToken() }
        XCTAssertEqual(Set(tokens).count, tokens.count)
        XCTAssertTrue(tokens.allSatisfy { $0.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil })
        XCTAssertTrue(tokens.allSatisfy { $0.count >= 40 })
    }

    func testTokenDigestIsDeterministicAndDoesNotStoreRawToken() {
        let token = "sample-refresh-token"
        let digest = tokenDigest(token)
        XCTAssertEqual(digest, tokenDigest(token))
        XCTAssertNotEqual(digest, token)
        XCTAssertEqual(digest.count, 64)
        XCTAssertNotEqual(digest, tokenDigest(token + "-different"))
    }
}
