import Crypto
import Foundation
import Vapor

private struct CredentialsRequest: Content {
    let email: String
    let password: String
}

private struct RefreshRequest: Content {
    let refreshToken: String
}

private struct AuthResponse: Content {
    let userID: UUID
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let accessTokenExpiresIn: Int
    let emailVerified: Bool
}

private struct UserProfileResponse: Content {
    let userID: UUID
    let email: String
    let emailVerified: Bool
}

private func normalizedEmail(_ value: String) -> String? {
    let email = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard email.count <= 254,
          let at = email.firstIndex(of: "@"),
          at != email.startIndex,
          email[at...].contains("."),
          !email.contains(" "),
          email.last != "."
    else { return nil }
    return email
}

private func secureToken() -> String {
    var generator = SystemRandomNumberGenerator()
    let bytes = (0..<32).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
    return Data(bytes).base64URLEncodedString()
}

private func tokenDigest(_ token: String) -> String {
    SHA256.hash(data: Data(token.utf8)).map { String(format: "%02x", $0) }.joined()
}

private func issueSession(for user: User, on request: Request) async throws -> AuthResponse {
    guard let userID = user.id else { throw Abort(.internalServerError) }
    let accessToken = secureToken()
    let refreshToken = secureToken()
    let accessExpiry = Date().addingTimeInterval(15 * 60)
    let refreshExpiry = Date().addingTimeInterval(30 * 24 * 60 * 60)
    let familyID = UUID()

    let session = AuthSession()
    session.userID = userID
    session.familyID = familyID
    session.accessTokenHash = tokenDigest(accessToken)
    session.accessExpiresAt = accessExpiry
    session.refreshTokenHash = tokenDigest(refreshToken)
    session.expiresAt = refreshExpiry
    session.userAgent = request.headers.first(name: .userAgent)
    try await session.save(on: request.db)

    guard let sessionID = session.id else { throw Abort(.internalServerError) }
    let record = RefreshTokenRecord()
    record.sessionID = sessionID
    record.familyID = familyID
    record.tokenHash = tokenDigest(refreshToken)
    record.expiresAt = refreshExpiry
    try await record.save(on: request.db)

    return AuthResponse(
        userID: userID,
        accessToken: accessToken,
        refreshToken: refreshToken,
        tokenType: "Bearer",
        accessTokenExpiresIn: 900,
        emailVerified: user.emailVerifiedAt != nil
    )
}

private func bearerToken(from request: Request) -> String? {
    guard let authorization = request.headers.first(name: .authorization),
          authorization.lowercased().hasPrefix("bearer ")
    else { return nil }
    let token = String(authorization.dropFirst(7)).trimmingCharacters(in: .whitespaces)
    return token.isEmpty ? nil : token
}

private func authenticatedUser(for request: Request) async throws -> User {
    guard let token = bearerToken(from: request) else {
        throw Abort(.unauthorized, reason: "A bearer access token is required.")
    }
    guard let session = try await AuthSession.query(on: request.db)
        .filter(\.$accessTokenHash == tokenDigest(token))
        .filter(\.$revokedAt == nil)
        .first(),
          session.accessExpiresAt > Date(),
          let user = try await User.find(session.userID, on: request.db),
          user.disabledAt == nil
    else {
        throw Abort(.unauthorized, reason: "Access token is invalid or expired.")
    }
    return user
}

func routes(_ app: Application) throws {
    app.get("health") { _ async -> [String: String] in
        ["status": "ok", "service": "auth-platform"]
    }

    app.get("v1", "auth", "capabilities") { _ async -> [String: [String]] in
        [
            "protocols": ["openid-connect", "oauth2"],
            "methods": ["email-password", "webauthn-passkey", "microsoft-oidc"],
            "clients": ["ios", "web"]
        ]
    }

    app.post("v1", "auth", "register") { request async throws -> AuthResponse in
        let input = try request.content.decode(CredentialsRequest.self)
        guard let email = normalizedEmail(input.email) else {
            throw Abort(.badRequest, reason: "Enter a valid email address.")
        }
        guard (12...128).contains(input.password.count),
              input.password.rangeOfCharacter(from: .lowercaseLetters) != nil,
              input.password.rangeOfCharacter(from: .uppercaseLetters) != nil,
              input.password.rangeOfCharacter(from: .decimalDigits) != nil
        else {
            throw Abort(.unprocessableEntity, reason: "Password must be 12–128 characters and include uppercase, lowercase, and a number.")
        }

        if try await User.query(on: request.db)
            .filter(\.$emailNormalized == email).first() != nil {
            throw Abort(.conflict, reason: "An account with this email already exists.")
        }

        let user = User()
        user.emailNormalized = email
        user.passwordHash = try request.password.hash(input.password)
        try await user.save(on: request.db)
        return try await issueSession(for: user, on: request)
    }

    app.post("v1", "auth", "login") { request async throws -> AuthResponse in
        let input = try request.content.decode(CredentialsRequest.self)
        guard let email = normalizedEmail(input.email),
              let user = try await User.query(on: request.db)
                .filter(\.$emailNormalized == email).first(),
              let passwordHash = user.passwordHash,
              user.disabledAt == nil,
              try request.password.verify(input.password, created: passwordHash)
        else {
            throw Abort(.unauthorized, reason: "Email or password is incorrect.")
        }
        return try await issueSession(for: user, on: request)
    }

    app.post("v1", "auth", "refresh") { request async throws -> AuthResponse in
        let input = try request.content.decode(RefreshRequest.self)
        let digest = tokenDigest(input.refreshToken)
        guard let record = try await RefreshTokenRecord.query(on: request.db)
            .filter(\.$tokenHash == digest).first(),
              let session = try await AuthSession.find(record.sessionID, on: request.db)
        else {
            throw Abort(.unauthorized, reason: "Refresh token is invalid.")
        }

        // A previously consumed token indicates possible token theft. Revoke every
        // session in the family before rejecting the replay.
        if record.consumedAt != nil {
            let familySessions = try await AuthSession.query(on: request.db)
                .filter(\.$familyID == record.familyID).all()
            for familySession in familySessions {
                familySession.revokedAt = Date()
                try await familySession.save(on: request.db)
            }
            throw Abort(.unauthorized, reason: "Refresh-token reuse detected; this session family was revoked.")
        }

        guard record.revokedAt == nil,
              record.expiresAt > Date(),
              session.revokedAt == nil,
              session.expiresAt > Date(),
              let user = try await User.find(session.userID, on: request.db),
              user.disabledAt == nil
        else {
            throw Abort(.unauthorized, reason: "Refresh token is expired or revoked.")
        }

        let now = Date()
        record.consumedAt = now
        try await record.save(on: request.db)

        let accessToken = secureToken()
        let refreshToken = secureToken()
        let accessExpiry = now.addingTimeInterval(15 * 60)
        let refreshExpiry = now.addingTimeInterval(30 * 24 * 60 * 60)
        session.accessTokenHash = tokenDigest(accessToken)
        session.accessExpiresAt = accessExpiry
        session.refreshTokenHash = tokenDigest(refreshToken)
        session.expiresAt = refreshExpiry
        session.rotatedAt = now
        try await session.save(on: request.db)

        guard let sessionID = session.id, let userID = user.id else {
            throw Abort(.internalServerError)
        }
        let nextRecord = RefreshTokenRecord()
        nextRecord.sessionID = sessionID
        nextRecord.familyID = session.familyID
        nextRecord.tokenHash = tokenDigest(refreshToken)
        nextRecord.expiresAt = refreshExpiry
        try await nextRecord.save(on: request.db)

        return AuthResponse(
            userID: userID,
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenType: "Bearer",
            accessTokenExpiresIn: 900,
            emailVerified: user.emailVerifiedAt != nil
        )
    }

    app.post("v1", "auth", "logout") { request async throws -> HTTPStatus in
        let input = try request.content.decode(RefreshRequest.self)
        let digest = tokenDigest(input.refreshToken)
        guard let record = try await RefreshTokenRecord.query(on: request.db)
            .filter(\.$tokenHash == digest).first(),
              let session = try await AuthSession.find(record.sessionID, on: request.db)
        else {
            return .noContent
        }
        let now = Date()
        record.revokedAt = now
        try await record.save(on: request.db)
        session.revokedAt = now
        try await session.save(on: request.db)
        return .noContent
    }

    app.get("v1", "users", "me") { request async throws -> UserProfileResponse in
        let user = try await authenticatedUser(for: request)
        guard let userID = user.id else { throw Abort(.internalServerError) }
        return UserProfileResponse(
            userID: userID,
            email: user.emailNormalized,
            emailVerified: user.emailVerifiedAt != nil
        )
    }
}
