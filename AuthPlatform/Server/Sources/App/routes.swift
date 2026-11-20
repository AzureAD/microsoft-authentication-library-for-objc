import Crypto
import Foundation
import Vapor
import SQLKit

private struct CredentialsRequest: Content {
    let email: String
    let password: String
}

private struct RefreshRequest: Content {
    let refreshToken: String
}

private struct EmailRequest: Content {
    let email: String
}

private struct TokenRequest: Content {
    let token: String
}

private struct PasswordResetRequest: Content {
    let token: String
    let newPassword: String
}

private struct RegistrationResponse: Content {
    let userID: UUID
    let emailVerificationRequired: Bool
}

private struct MessageResponse: Content {
    let message: String
}

private struct ResendEmailPayload: Content {
    let from: String
    let to: [String]
    let subject: String
    let html: String
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

func normalizedEmail(_ value: String) -> String? {
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

private func isStrongPassword(_ password: String) -> Bool {
    (12...128).contains(password.count)
        && password.rangeOfCharacter(from: .lowercaseLetters) != nil
        && password.rangeOfCharacter(from: .uppercaseLetters) != nil
        && password.rangeOfCharacter(from: .decimalDigits) != nil
}

private func createOneTimeToken(for user: User, purpose: String, lifetime: TimeInterval, on database: Database) async throws -> String {
    guard let userID = user.id else { throw Abort(.internalServerError) }
    let rawToken = secureToken()
    let record = OneTimeAuthToken()
    record.userID = userID
    record.purpose = purpose
    record.tokenHash = tokenDigest(rawToken)
    record.expiresAt = Date().addingTimeInterval(lifetime)
    try await record.save(on: database)
    return rawToken
}

private func sendAuthEmail(to email: String, subject: String, actionPath: String, token: String, on request: Request) async throws {
    guard let apiKey = Environment.get("RESEND_API_KEY"), !apiKey.isEmpty,
          let sender = Environment.get("AUTH_EMAIL_FROM"), !sender.isEmpty,
          let publicURL = Environment.get("AUTH_PUBLIC_URL"), !publicURL.isEmpty
    else {
        throw Abort(.serviceUnavailable, reason: "Email delivery is not configured. Set RESEND_API_KEY, AUTH_EMAIL_FROM, and AUTH_PUBLIC_URL.")
    }

    var components = URLComponents(string: publicURL)
    components?.path = actionPath
    components?.queryItems = [URLQueryItem(name: "token", value: token)]
    guard let actionURL = components?.url?.absoluteString else {
        throw Abort(.internalServerError, reason: "AUTH_PUBLIC_URL is invalid.")
    }

    let payload = ResendEmailPayload(
        from: sender,
        to: [email],
        subject: subject,
        html: "<p>Use the secure link below. It expires automatically and can only be used once.</p><p><a href=\"\(actionURL)\">Continue</a></p>"
    )
    let response = try await request.client.post(URI(string: "https://api.resend.com/emails")) { outbound in
        outbound.headers.add(name: .authorization, value: "Bearer \(apiKey)")
        try outbound.content.encode(payload)
    }
    guard response.status == .ok || response.status == .created else {
        request.logger.error("Auth email provider returned status \(response.status.code)")
        throw Abort(.badGateway, reason: "The verification email could not be delivered.")
    }
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

    app.post("v1", "auth", "register") { request async throws -> RegistrationResponse in
        let input = try request.content.decode(CredentialsRequest.self)
        guard let email = normalizedEmail(input.email) else {
            throw Abort(.badRequest, reason: "Enter a valid email address.")
        }
        guard isStrongPassword(input.password) else {
            throw Abort(.unprocessableEntity, reason: "Password must be 12–128 characters and include uppercase, lowercase, and a number.")
        }
        if try await User.query(on: request.db)
            .filter(\\.$emailNormalized == email).first() != nil {
            throw Abort(.conflict, reason: "An account with this email already exists.")
        }

        let user = User()
        user.emailNormalized = email
        user.passwordHash = try request.password.hash(input.password)
        try await user.save(on: request.db)
        let token = try await createOneTimeToken(for: user, purpose: "email_verification", lifetime: 24 * 60 * 60, on: request.db)
        try await sendAuthEmail(to: email, subject: "Verify your email", actionPath: "/verify-email", token: token, on: request)
        guard let userID = user.id else { throw Abort(.internalServerError) }
        return RegistrationResponse(userID: userID, emailVerificationRequired: true)
    }

    app.post("v1", "auth", "login") { request async throws -> AuthResponse in
        let input = try request.content.decode(CredentialsRequest.self)
        guard let email = normalizedEmail(input.email),
              let user = try await User.query(on: request.db)
                .filter(\.$emailNormalized == email).first(),
              let passwordHash = user.passwordHash,
              user.disabledAt == nil,
              user.emailVerifiedAt != nil,
              try request.password.verify(input.password, created: passwordHash)
        else {
            throw Abort(.unauthorized, reason: "Email or password is incorrect.")
        }
        return try await issueSession(for: user, on: request)
    }

    app.post("v1", "auth", "verification", "request") { request async throws -> MessageResponse in
        let input = try request.content.decode(EmailRequest.self)
        guard let email = normalizedEmail(input.email) else {
            return MessageResponse(message: "If the account exists and needs verification, an email will be sent.")
        }
        if let user = try await User.query(on: request.db)
            .filter(\\.$emailNormalized == email).first(),
           user.emailVerifiedAt == nil,
           user.disabledAt == nil {
            let token = try await createOneTimeToken(for: user, purpose: "email_verification", lifetime: 24 * 60 * 60, on: request.db)
            try await sendAuthEmail(to: email, subject: "Verify your email", actionPath: "/verify-email", token: token, on: request)
        }
        return MessageResponse(message: "If the account exists and needs verification, an email will be sent.")
    }

    app.post("v1", "auth", "verify-email") { request async throws -> MessageResponse in
        let input = try request.content.decode(TokenRequest.self)
        let digest = tokenDigest(input.token)
        let verified = try await request.db.transaction { database -> Bool in
            guard let sql = database as? SQLDatabase else {
                throw Abort(.internalServerError, reason: "One-time token verification requires PostgreSQL.")
            }
            _ = try await sql.raw("SELECT id FROM one_time_auth_tokens WHERE token_hash = \(bind: digest) FOR UPDATE").all()
            guard let token = try await OneTimeAuthToken.query(on: database)
                .filter(\\.$tokenHash == digest)
                .filter(\\.$purpose == "email_verification").first(),
                  token.consumedAt == nil,
                  token.expiresAt > Date(),
                  let user = try await User.find(token.userID, on: database),
                  user.disabledAt == nil
            else { return false }
            token.consumedAt = Date()
            try await token.save(on: database)
            user.emailVerifiedAt = Date()
            try await user.save(on: database)
            return true
        }
        guard verified else { throw Abort(.unprocessableEntity, reason: "Verification token is invalid, expired, or already used.") }
        return MessageResponse(message: "Email verified. You can now sign in.")
    }

    app.post("v1", "auth", "password", "forgot") { request async throws -> MessageResponse in
        let input = try request.content.decode(EmailRequest.self)
        if let email = normalizedEmail(input.email),
           let user = try await User.query(on: request.db)
                .filter(\\.$emailNormalized == email).first(),
           user.disabledAt == nil {
            let token = try await createOneTimeToken(for: user, purpose: "password_reset", lifetime: 30 * 60, on: request.db)
            try await sendAuthEmail(to: email, subject: "Reset your password", actionPath: "/reset-password", token: token, on: request)
        }
        return MessageResponse(message: "If the account exists, password-reset instructions will be sent.")
    }

    app.post("v1", "auth", "password", "reset") { request async throws -> MessageResponse in
        let input = try request.content.decode(PasswordResetRequest.self)
        guard isStrongPassword(input.newPassword) else {
            throw Abort(.unprocessableEntity, reason: "Password must be 12–128 characters and include uppercase, lowercase, and a number.")
        }
        let digest = tokenDigest(input.token)
        let changed = try await request.db.transaction { database -> Bool in
            guard let sql = database as? SQLDatabase else {
                throw Abort(.internalServerError, reason: "Password reset requires PostgreSQL.")
            }
            _ = try await sql.raw("SELECT id FROM one_time_auth_tokens WHERE token_hash = \(bind: digest) FOR UPDATE").all()
            guard let token = try await OneTimeAuthToken.query(on: database)
                .filter(\\.$tokenHash == digest)
                .filter(\\.$purpose == "password_reset").first(),
                  token.consumedAt == nil,
                  token.expiresAt > Date(),
                  let user = try await User.find(token.userID, on: database),
                  user.disabledAt == nil
            else { return false }
            token.consumedAt = Date()
            try await token.save(on: database)
            user.passwordHash = try request.password.hash(input.newPassword)
            try await user.save(on: database)
            guard let userID = user.id else { throw Abort(.internalServerError) }
            let sessions = try await AuthSession.query(on: database)
                .filter(\\.$userID == userID).all()
            for session in sessions {
                session.revokedAt = Date()
                try await session.save(on: database)
            }
            return true
        }
        guard changed else { throw Abort(.unprocessableEntity, reason: "Password-reset token is invalid, expired, or already used.") }
        return MessageResponse(message: "Password updated. Sign in again with your new password.")
    }

    app.post("v1", "auth", "refresh") { request async throws -> AuthResponse in
        let input = try request.content.decode(RefreshRequest.self)
        let digest = tokenDigest(input.refreshToken)

        // Lock the presented token row inside the transaction. A concurrent
        // request waits here, then observes consumed_at and triggers reuse defense.
        let rotated: AuthResponse? = try await request.db.transaction { database in
            guard let sql = database as? SQLDatabase else {
                throw Abort(.internalServerError, reason: "Atomic refresh requires PostgreSQL.")
            }
            _ = try await sql.raw("""
                SELECT id FROM refresh_token_records
                WHERE token_hash = \(bind: digest)
                FOR UPDATE
                """).all()

            guard let record = try await RefreshTokenRecord.query(on: database)
                .filter(\\.$tokenHash == digest).first(),
                  let session = try await AuthSession.find(record.sessionID, on: database)
            else {
                throw Abort(.unauthorized, reason: "Refresh token is invalid.")
            }

            if record.consumedAt != nil {
                let familySessions = try await AuthSession.query(on: database)
                    .filter(\\.$familyID == record.familyID).all()
                for familySession in familySessions {
                    familySession.revokedAt = Date()
                    try await familySession.save(on: database)
                }
                // Return nil so revocations commit; throwing here would roll back.
                return nil
            }

            guard record.revokedAt == nil,
                  record.expiresAt > Date(),
                  session.revokedAt == nil,
                  session.expiresAt > Date(),
                  let user = try await User.find(session.userID, on: database),
                  user.disabledAt == nil
            else {
                throw Abort(.unauthorized, reason: "Refresh token is expired or revoked.")
            }

            let now = Date()
            record.consumedAt = now
            try await record.save(on: database)

            let accessToken = secureToken()
            let refreshToken = secureToken()
            let accessExpiry = now.addingTimeInterval(15 * 60)
            let refreshExpiry = now.addingTimeInterval(30 * 24 * 60 * 60)
            session.accessTokenHash = tokenDigest(accessToken)
            session.accessExpiresAt = accessExpiry
            session.refreshTokenHash = tokenDigest(refreshToken)
            session.expiresAt = refreshExpiry
            session.rotatedAt = now
            try await session.save(on: database)

            guard let sessionID = session.id, let userID = user.id else {
                throw Abort(.internalServerError)
            }
            let nextRecord = RefreshTokenRecord()
            nextRecord.sessionID = sessionID
            nextRecord.familyID = session.familyID
            nextRecord.tokenHash = tokenDigest(refreshToken)
            nextRecord.expiresAt = refreshExpiry
            try await nextRecord.save(on: database)

            return AuthResponse(
                userID: userID,
                accessToken: accessToken,
                refreshToken: refreshToken,
                tokenType: "Bearer",
                accessTokenExpiresIn: 900,
                emailVerified: user.emailVerifiedAt != nil
            )
        }

        guard let rotated else {
            throw Abort(.unauthorized, reason: "Refresh-token reuse detected; this session family was revoked.")
        }
        return rotated
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
