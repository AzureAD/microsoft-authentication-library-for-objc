import XCTest
import Vapor
import Fluent
import XCTVapor
@testable import App

private struct RegistrationPayload: Content {
    let email: String
    let password: String
}

private actor MockAuthEmailProvider {
    private var failNextDelivery: Bool
    private(set) var attempts = 0
    private(set) var deliveredTokens: [String] = []

    init(failFirstDelivery: Bool) {
        self.failNextDelivery = failFirstDelivery
    }

    func deliver(email: String, subject: String, actionPath: String, token: String) throws {
        attempts += 1
        if failNextDelivery {
            failNextDelivery = false
            throw Abort(.badGateway, reason: "Mock email provider failure.")
        }
        deliveredTokens.append(token)
    }

    func snapshot() -> (attempts: Int, tokens: [String]) {
        (attempts, deliveredTokens)
    }
}

final class RegistrationEmailDeliveryTests: XCTestCase {
    func testUnverifiedRegistrationCanRetryAfterEmailProviderFailure() async throws {
        guard Environment.get("DATABASE_URL") != nil else {
            throw XCTSkip("Set DATABASE_URL to a disposable PostgreSQL test database.")
        }

        let app = try await Application.make(.testing)
        addTeardownBlock { try await app.asyncShutdown() }

        let provider = MockAuthEmailProvider(failFirstDelivery: true)
        try await configure(app, emailSender: { email, subject, actionPath, token, _ in
            try await provider.deliver(email: email, subject: subject, actionPath: actionPath, token: token)
        })
        try await app.autoMigrate()

        let email = "registration-retry-\(UUID().uuidString.lowercased())@example.test"
        let originalPassword = "OriginalPassword123"
        let firstPayload = RegistrationPayload(email: email, password: originalPassword)

        try await app.test(.POST, "v1/auth/register", beforeRequest: { request in
            try request.content.encode(firstPayload)
        }, afterResponse: { response async in
            XCTAssertEqual(response.status, .badGateway)
        })

        let persistedUserResult = try await User.query(on: app.db)
            .filter(\.$emailNormalized == email).first()
        let persistedUser = try XCTUnwrap(persistedUserResult)
        let userID = try XCTUnwrap(persistedUser.id)
        let originalPasswordHash = try XCTUnwrap(persistedUser.passwordHash)
        XCTAssertNil(persistedUser.emailVerifiedAt)

        let retryPayload = RegistrationPayload(
            email: email,
            password: "DifferentPassword456"
        )
        try await app.test(.POST, "v1/auth/register", beforeRequest: { request in
            try request.content.encode(retryPayload)
        }, afterResponse: { response async in
            XCTAssertEqual(response.status, .ok)
        })

        let users = try await User.query(on: app.db)
            .filter(\.$emailNormalized == email).all()
        XCTAssertEqual(users.count, 1, "Retry must not create a duplicate account.")
        XCTAssertEqual(users.first?.passwordHash, originalPasswordHash,
                       "Retry must not replace the password chosen during the original registration.")

        let tokens = try await OneTimeAuthToken.query(on: app.db)
            .filter(\.$userID == userID)
            .filter(\.$purpose == "email_verification").all()
        XCTAssertEqual(tokens.filter { $0.consumedAt == nil }.count, 1,
                       "Only the latest verification token should remain active.")
        XCTAssertEqual(tokens.filter { $0.consumedAt != nil }.count, 1,
                       "The token from the failed delivery attempt should be invalidated.")

        let delivery = await provider.snapshot()
        XCTAssertEqual(delivery.attempts, 2)
        XCTAssertEqual(delivery.tokens.count, 1,
                       "The mock provider should record exactly one successful delivery.")
        XCTAssertEqual(tokens.first(where: { $0.consumedAt == nil })?.tokenHash,
                       delivery.tokens.first.map(tokenDigest),
                       "The successfully delivered token must match the sole active database token.")
    }

    func testConcurrentRegistrationRetriesLeaveExactlyOneActiveVerificationToken() async throws {
        guard Environment.get("DATABASE_URL") != nil else {
            throw XCTSkip("Set DATABASE_URL to a disposable PostgreSQL test database.")
        }

        let app = try await Application.make(.testing)
        addTeardownBlock { try await app.asyncShutdown() }

        let provider = MockAuthEmailProvider(failFirstDelivery: true)
        try await configure(app, emailSender: { email, subject, actionPath, token, _ in
            try await provider.deliver(email: email, subject: subject, actionPath: actionPath, token: token)
        })
        try await app.autoMigrate()

        let email = "registration-concurrent-retry-\(UUID().uuidString.lowercased())@example.test"
        let payload = RegistrationPayload(email: email, password: "OriginalPassword123")

        // Persist the unverified account and its first token while simulating
        // the provider failure that makes the account eligible for retry.
        try await app.test(.POST, "v1/auth/register", beforeRequest: { request in
            try request.content.encode(payload)
        }, afterResponse: { response async in
            XCTAssertEqual(response.status, .badGateway)
        })

        let persistedUserResult = try await User.query(on: app.db)
            .filter(\.$emailNormalized == email).first()
        let persistedUser = try XCTUnwrap(persistedUserResult)
        let originalPasswordHash = try XCTUnwrap(persistedUser.passwordHash)
        let retryPayload = RegistrationPayload(email: email, password: "DifferentPassword456")
        let performRetry: () async -> Void = {
            _ = await app.test(.POST, "v1/auth/register", beforeRequest: { request in
                try request.content.encode(retryPayload)
            }, afterResponse: { response async in
                XCTAssertEqual(response.status, .ok)
            })
        }
        async let firstRetry = performRetry()
        async let secondRetry = performRetry()
        await firstRetry
        await secondRetry

        let users = try await User.query(on: app.db)
            .filter(\.$emailNormalized == email).all()
        XCTAssertEqual(users.count, 1, "Concurrent retries must not create duplicate accounts.")
        let user = try XCTUnwrap(users.first)
        let userID = try XCTUnwrap(user.id)
        XCTAssertEqual(user.passwordHash, originalPasswordHash,
                       "Retries must not replace the original password.")

        let tokens = try await OneTimeAuthToken.query(on: app.db)
            .filter(\.$userID == userID)
            .filter(\.$purpose == "email_verification").all()
        let activeTokens = tokens.filter { $0.consumedAt == nil }
        XCTAssertEqual(activeTokens.count, 1,
                       "Concurrent retries must leave exactly one active verification token.")
        XCTAssertEqual(tokens.filter { $0.consumedAt != nil }.count, 2,
                       "The initial token and superseded concurrent retry token must be consumed.")

        let delivery = await provider.snapshot()
        XCTAssertEqual(delivery.attempts, 3)
        XCTAssertEqual(delivery.tokens.count, 2,
                       "Both retry sends may complete, but only the latest token remains valid.")
        XCTAssertTrue(delivery.tokens.map(tokenDigest).contains(activeTokens[0].tokenHash),
                      "The active token must be one of the delivered retry tokens.")
    }
}
