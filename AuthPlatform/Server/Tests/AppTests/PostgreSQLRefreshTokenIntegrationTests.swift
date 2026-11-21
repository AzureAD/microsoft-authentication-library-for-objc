import XCTest
import Vapor
import Fluent
import XCTVapor
@testable import App

private struct RefreshPayload: Content {
    let refreshToken: String
}

final class PostgreSQLRefreshTokenIntegrationTests: XCTestCase {
    func testConcurrentRefreshAllowsOneRotationAndRevokesFamilyOnReplay() async throws {
        guard Environment.get("DATABASE_URL") != nil else {
            throw XCTSkip("Set DATABASE_URL to a disposable PostgreSQL test database.")
        }

        let app = Application(.testing)
        defer { app.shutdown() }

        try await configure(app)
        try await app.autoMigrate()

        let user = User()
        user.emailNormalized = "refresh-concurrency@example.test"
        user.emailVerifiedAt = Date()
        user.passwordHash = "unused-by-refresh-route"
        try await user.save(on: app.db)
        let userID = try XCTUnwrap(user.id)

        let rawRefreshToken = secureToken()
        let familyID = UUID()
        let session = AuthSession()
        session.userID = userID
        session.familyID = familyID
        session.accessTokenHash = tokenDigest(secureToken())
        session.accessExpiresAt = Date().addingTimeInterval(900)
        session.refreshTokenHash = tokenDigest(rawRefreshToken)
        session.expiresAt = Date().addingTimeInterval(86_400)
        try await session.save(on: app.db)
        let sessionID = try XCTUnwrap(session.id)

        let refreshRecord = RefreshTokenRecord()
        refreshRecord.sessionID = sessionID
        refreshRecord.familyID = familyID
        refreshRecord.tokenHash = tokenDigest(rawRefreshToken)
        refreshRecord.expiresAt = Date().addingTimeInterval(86_400)
        try await refreshRecord.save(on: app.db)

        async let first = refresh(app, token: rawRefreshToken)
        async let second = refresh(app, token: rawRefreshToken)
        let statuses = try await [first, second]

        XCTAssertEqual(statuses.filter { $0 == .ok }.count, 1,
                       "Exactly one concurrent request may rotate a refresh token.")
        XCTAssertEqual(statuses.filter { $0 == .unauthorized }.count, 1,
                       "The losing replay must be rejected.")

        let fetchedSession = try await AuthSession.find(sessionID, on: app.db)
        let persistedSession = try XCTUnwrap(fetchedSession)
        XCTAssertNotNil(persistedSession.revokedAt,
                        "Replay detection must revoke the entire token family.")
    }

    private func refresh(_ app: Application, token: String) async throws -> HTTPStatus {
        var responseStatus: HTTPStatus = .internalServerError
        try await app.test(.POST, "v1/auth/refresh", beforeRequest: { request in
            try request.content.encode(RefreshPayload(refreshToken: token))
        }, afterResponse: { response async in
            responseStatus = response.status
        })
        return responseStatus
    }
}
