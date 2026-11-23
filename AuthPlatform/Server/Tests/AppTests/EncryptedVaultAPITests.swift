import XCTest
import Vapor
import Fluent
import XCTVapor
@testable import App

private struct EncryptedVaultItemPayload: Content {
    let clientItemID: UUID
    let ciphertext: String
    let nonce: String
    let authenticationTag: String
    let formatVersion: Int
}

private struct EncryptedVaultItemResponse: Content {
    let clientItemID: UUID
    let ciphertext: String
    let nonce: String
    let authenticationTag: String
    let formatVersion: Int
}

final class EncryptedVaultAPITests: XCTestCase {
    func testVaultRejectsRequestsWithoutBearerSession() async throws {
        guard Environment.get("DATABASE_URL") != nil else {
            throw XCTSkip("Set DATABASE_URL to a disposable PostgreSQL test database.")
        }

        let app = Application(.testing)
        defer { app.shutdown() }
        try await configure(app)
        try await app.autoMigrate()

        try await app.test(.GET, "v1/vault/items", afterResponse: { response async in
            XCTAssertEqual(response.status, .unauthorized)
        })
    }

    func testAuthenticatedUserCanCreateReadAndDeleteEncryptedItem() async throws {
        guard Environment.get("DATABASE_URL") != nil else {
            throw XCTSkip("Set DATABASE_URL to a disposable PostgreSQL test database.")
        }

        let app = Application(.testing)
        defer { app.shutdown() }
        try await configure(app)
        try await app.autoMigrate()

        let user = User()
        user.emailNormalized = "vault-\(UUID().uuidString.lowercased())@example.test"
        user.emailVerifiedAt = Date()
        user.passwordHash = "unused-by-vault-test"
        try await user.save(on: app.db)
        let userID = try XCTUnwrap(user.id)

        let accessToken = secureToken()
        let session = AuthSession()
        session.userID = userID
        session.familyID = UUID()
        session.accessTokenHash = tokenDigest(accessToken)
        session.accessExpiresAt = Date().addingTimeInterval(900)
        session.refreshTokenHash = tokenDigest(secureToken())
        session.expiresAt = Date().addingTimeInterval(86_400)
        try await session.save(on: app.db)

        let itemID = UUID()
        let payload = EncryptedVaultItemPayload(
            clientItemID: itemID,
            ciphertext: Data("ciphertext-only-test".utf8).base64EncodedString(),
            nonce: Data(repeating: 7, count: 12).base64EncodedString(),
            authenticationTag: Data(repeating: 9, count: 16).base64EncodedString(),
            formatVersion: 1
        )

        try await app.test(.POST, "v1/vault/items", beforeRequest: { request in
            request.headers.bearerAuthorization = BearerAuthorization(token: accessToken)
            try request.content.encode(payload)
        }, afterResponse: { response async in
            XCTAssertEqual(response.status, .created)
            let saved = try response.content.decode(EncryptedVaultItemResponse.self)
            XCTAssertEqual(saved.clientItemID, itemID)
            XCTAssertEqual(saved.ciphertext, payload.ciphertext)
            XCTAssertEqual(saved.nonce, payload.nonce)
            XCTAssertEqual(saved.authenticationTag, payload.authenticationTag)
        })

        try await app.test(.GET, "v1/vault/items/\(itemID)", beforeRequest: { request in
            request.headers.bearerAuthorization = BearerAuthorization(token: accessToken)
        }, afterResponse: { response async in
            XCTAssertEqual(response.status, .ok)
            let fetched = try response.content.decode(EncryptedVaultItemResponse.self)
            XCTAssertEqual(fetched.clientItemID, itemID)
            XCTAssertEqual(fetched.ciphertext, payload.ciphertext)
        })

        let otherUser = User()
        otherUser.emailNormalized = "other-\(UUID().uuidString.lowercased())@example.test"
        otherUser.emailVerifiedAt = Date()
        otherUser.passwordHash = "unused-by-vault-test"
        try await otherUser.save(on: app.db)
        let otherToken = secureToken()
        let otherSession = AuthSession()
        otherSession.userID = try XCTUnwrap(otherUser.id)
        otherSession.familyID = UUID()
        otherSession.accessTokenHash = tokenDigest(otherToken)
        otherSession.accessExpiresAt = Date().addingTimeInterval(900)
        otherSession.refreshTokenHash = tokenDigest(secureToken())
        otherSession.expiresAt = Date().addingTimeInterval(86_400)
        try await otherSession.save(on: app.db)

        try await app.test(.GET, "v1/vault/items/\(itemID)", beforeRequest: { request in
            request.headers.bearerAuthorization = BearerAuthorization(token: otherToken)
        }, afterResponse: { response async in
            XCTAssertEqual(response.status, .notFound, "A different user must not be able to read this vault item.")
        })

        try await app.test(.DELETE, "v1/vault/items/\(itemID)", beforeRequest: { request in
            request.headers.bearerAuthorization = BearerAuthorization(token: accessToken)
        }, afterResponse: { response async in
            XCTAssertEqual(response.status, .noContent)
        })
    }
}
