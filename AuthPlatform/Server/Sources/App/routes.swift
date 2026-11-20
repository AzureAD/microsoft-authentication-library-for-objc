import Crypto
import Foundation
import Vapor

private struct CredentialsRequest: Content {
    let email: String
    let password: String
}

private struct AuthResponse: Content {
    let userID: UUID
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let accessTokenExpiresIn: Int
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

    let session = AuthSession()
    session.userID = userID
    session.familyID = UUID()
    session.accessTokenHash = tokenDigest(accessToken)
    session.accessExpiresAt = accessExpiry
    session.refreshTokenHash = tokenDigest(refreshToken)
    session.expiresAt = refreshExpiry
    session.userAgent = request.headers.first(name: .userAgent)
    try await session.save(on: request.db)

    return AuthResponse(
        userID: userID,
        accessToken: accessToken,
        refreshToken: refreshToken,
        tokenType: "Bearer",
        accessTokenExpiresIn: 900,
        emailVerified: user.emailVerifiedAt != nil
    )
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
}
