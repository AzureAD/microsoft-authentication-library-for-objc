import Crypto
import Foundation
import Vapor
import Fluent
import SQLKit
import WebAuthn

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

private struct PasskeyRegistrationOptionsResponse: Content {
    let challengeID: UUID
    let publicKey: PublicKeyCredentialCreationOptions
}

private struct PasskeyRegistrationFinishRequest: Content {
    let challengeID: UUID
    let credential: RegistrationCredential
}

private struct PasskeyAuthenticationOptionsResponse: Content {
    let challengeID: UUID
    let publicKey: PublicKeyCredentialRequestOptions
}

private struct PasskeyAuthenticationOptionsRequest: Content {
    let email: String
}

private struct PasskeyAuthenticationFinishRequest: Content {
    let challengeID: UUID
    let credential: AuthenticationCredential
}


private struct EncryptedVaultItemWriteRequest: Content {
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
    let createdAt: Date?
    let updatedAt: Date?
    let deletedAt: Date?

    init(_ item: EncryptedVaultItem) {
        clientItemID = item.clientItemID
        ciphertext = item.ciphertext
        nonce = item.nonce
        authenticationTag = item.authenticationTag
        formatVersion = item.formatVersion
        createdAt = item.createdAt
        updatedAt = item.updatedAt
        deletedAt = item.deletedAt
    }
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

func secureToken() -> String {
    var generator = SystemRandomNumberGenerator()
    let bytes = (0..<32).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
    return Data(bytes).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

func tokenDigest(_ token: String) -> String {
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

func isStrongPassword(_ password: String) -> Bool {
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

private func webAuthnManager() throws -> WebAuthnManager {
    guard let relyingPartyID = Environment.get("WEBAUTHN_RP_ID"),
          !relyingPartyID.isEmpty,
          let origin = Environment.get("WEBAUTHN_ORIGIN"),
          !origin.isEmpty
    else {
        throw Abort(.serviceUnavailable, reason: "WEBAUTHN_RP_ID and WEBAUTHN_ORIGIN must be configured.")
    }
    return WebAuthnManager(configuration: .init(
        relyingPartyID: relyingPartyID,
        relyingPartyName: Environment.get("WEBAUTHN_RP_NAME") ?? "AuthPlatform",
        relyingPartyOrigin: origin
    ))
}

func decodeBase64URL(_ value: String) -> [UInt8]? {
    var base64 = value.replacing("-", with: "+").replacing("_", with: "/")
    while base64.count % 4 != 0 { base64.append("=") }
    return Data(base64Encoded: base64).map { Array($0) }
}

private func opaqueWebAuthnUserID(_ id: UUID) -> [UInt8] {
    Array(SHA256.hash(data: Data(id.uuidString.utf8)))
}

private func cookieValue(named name: String, from request: Request) -> String? {
    guard let cookieHeader = request.headers.first(name: .cookie) else { return nil }
    for component in cookieHeader.split(separator: ";") {
        let pair = component.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        if pair.count == 2, pair[0].trimmingCharacters(in: .whitespaces) == name {
            return pair[1].trimmingCharacters(in: .whitespaces)
        }
    }
    return nil
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
            "methods": ["email-password", "webauthn-passkey", "microsoft-oidc", "openai-oidc"],
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
            .filter(\.$emailNormalized == email).first() != nil {
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
            .filter(\.$emailNormalized == email).first(),
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
                .filter(\.$tokenHash == digest)
                .filter(\.$purpose == "email_verification").first(),
                  token.consumedAt == nil,
                  token.expiresAt > Date(),
                  let tokenID = token.id
            else { return false }

            let userID = token.userID
            // Serialize all verification links for this account. The first
            // successful link consumes every other outstanding verification link.
            _ = try await sql.raw("SELECT id FROM users WHERE id = \(bind: userID) FOR UPDATE").all()
            guard let currentToken = try await OneTimeAuthToken.find(tokenID, on: database),
                  currentToken.consumedAt == nil,
                  currentToken.expiresAt > Date(),
                  let user = try await User.find(userID, on: database),
                  user.disabledAt == nil
            else { return false }

            let now = Date()
            let pendingTokens = try await OneTimeAuthToken.query(on: database)
                .filter(\.$userID == userID)
                .filter(\.$purpose == "email_verification")
                .filter(\.$consumedAt == nil).all()
            for pendingToken in pendingTokens {
                pendingToken.consumedAt = now
                try await pendingToken.save(on: database)
            }
            user.emailVerifiedAt = now
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
                .filter(\.$emailNormalized == email).first(),
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
                .filter(\.$tokenHash == digest)
                .filter(\.$purpose == "password_reset").first(),
                  token.consumedAt == nil,
                  token.expiresAt > Date(),
                  let user = try await User.find(token.userID, on: database),
                  user.disabledAt == nil,
                  let userID = user.id,
                  let tokenID = token.id
            else { return false }

            // Serialize resets for one account, then re-read the token so a
            // concurrent reset cannot reuse a second still-pending link.
            _ = try await sql.raw("SELECT id FROM users WHERE id = \(bind: userID) FOR UPDATE").all()
            guard let currentToken = try await OneTimeAuthToken.find(tokenID, on: database),
                  currentToken.consumedAt == nil,
                  currentToken.expiresAt > Date()
            else { return false }

            let now = Date()
            let resetTokens = try await OneTimeAuthToken.query(on: database)
                .filter(\.$userID == userID)
                .filter(\.$purpose == "password_reset")
                .filter(\.$consumedAt == nil).all()
            for resetToken in resetTokens {
                resetToken.consumedAt = now
                try await resetToken.save(on: database)
            }

            user.passwordHash = try request.password.hash(input.newPassword)
            try await user.save(on: database)
            let sessions = try await AuthSession.query(on: database)
                .filter(\.$userID == userID).all()
            for session in sessions {
                session.revokedAt = now
                try await session.save(on: database)
            }
            return true
        }
        guard changed else { throw Abort(.unprocessableEntity, reason: "Password-reset token is invalid, expired, or already used.") }
        return MessageResponse(message: "Password updated. Sign in again with your new password.")
    }

    app.get("v1", "oidc", ":provider", "start") { request async throws -> Response in
        let provider = try request.parameters.require("provider").lowercased()
        let configuration = try oidcClientConfiguration(for: provider)
        let discovery = try await loadOIDCDiscovery(configuration, on: request)

        let state = secureToken()
        let nonce = secureToken()
        let verifier = secureToken()
        let browserSession = secureToken()
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncodedString().asString()

        let transaction = OIDCLoginTransaction()
        transaction.provider = provider
        transaction.stateHash = tokenDigest(state)
        transaction.browserSessionHash = tokenDigest(browserSession)
        transaction.nonce = nonce
        transaction.codeVerifier = verifier
        transaction.redirectURI = configuration.redirectURI
        transaction.expiresAt = Date().addingTimeInterval(10 * 60)
        try await transaction.save(on: request.db)

        var authorization = URLComponents(string: discovery.authorizationEndpoint)
        authorization?.queryItems = [
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid profile email"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "nonce", value: nonce),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        guard let destination = authorization?.url?.absoluteString else {
            throw Abort(.internalServerError, reason: "Unable to construct the identity provider authorization URL.")
        }

        let response = Response(status: .seeOther)
        response.headers.add(name: "Location", value: destination)
        response.headers.add(
            name: "Set-Cookie",
            value: "__Host-oidc-session=\(browserSession); Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=600"
        )
        return response
    }

    app.get("v1", "oidc", ":provider", "callback") { request async throws -> Response in
        let provider = try request.parameters.require("provider").lowercased()
        let code = try request.query.get(String.self, at: "code")
        let state = try request.query.get(String.self, at: "state")
        guard let browserSession = cookieValue(named: "__Host-oidc-session", from: request) else {
            throw Abort(.unauthorized, reason: "OIDC browser session is missing.")
        }

        let stateHash = tokenDigest(state)
        let transaction = try await request.db.transaction { database -> OIDCTransactionSnapshot? in
            guard let sql = database as? SQLDatabase else {
                throw Abort(.internalServerError, reason: "OIDC transactions require PostgreSQL.")
            }
            _ = try await sql.raw("SELECT id FROM oidc_login_transactions WHERE state_hash = \(bind: stateHash) FOR UPDATE").all()
            guard let stored = try await OIDCLoginTransaction.query(on: database)
                .filter(\.$stateHash == stateHash)
                .filter(\.$provider == provider).first(),
                  stored.consumedAt == nil,
                  stored.expiresAt > Date(),
                  stored.browserSessionHash == tokenDigest(browserSession)
            else { return nil }

            stored.consumedAt = Date()
            try await stored.save(on: database)
            return OIDCTransactionSnapshot(
                provider: stored.provider,
                nonce: stored.nonce,
                codeVerifier: stored.codeVerifier,
                redirectURI: stored.redirectURI
            )
        }

        guard let transaction else {
            throw Abort(.unauthorized, reason: "OIDC state is invalid, expired, reused, or bound to another browser session.")
        }

        let configuration = try oidcClientConfiguration(for: provider)
        guard configuration.redirectURI == transaction.redirectURI else {
            throw Abort(.unauthorized, reason: "OIDC redirect URI no longer matches the stored transaction.")
        }
        let discovery = try await loadOIDCDiscovery(configuration, on: request)
        let idToken = try await exchangeOIDCCode(
            code,
            configuration: configuration,
            discovery: discovery,
            codeVerifier: transaction.codeVerifier,
            on: request
        )
        let identity = try await verifyOIDCIdentity(
            provider: provider,
            idToken: idToken,
            nonce: transaction.nonce,
            clientID: configuration.clientID,
            discovery: discovery,
            on: request
        )

        guard let email = normalizedEmail(identity.email) else {
            throw Abort(.unauthorized, reason: "The identity provider did not return a usable email address.")
        }

        let user: User
        if let linkedAccount = try await OAuthAccount.query(on: request.db)
            .filter(\.$issuer == identity.issuer)
            .filter(\.$subject == identity.subject).first(),
           let linkedUser = try await User.find(linkedAccount.userID, on: request.db) {
            guard linkedUser.disabledAt == nil else {
                throw Abort(.forbidden, reason: "This account is disabled.")
            }
            user = linkedUser
        } else {
            if try await User.query(on: request.db)
                .filter(\.$emailNormalized == email).first() != nil {
                throw Abort(.conflict, reason: "An account already uses this email. Sign in to that account before linking another identity provider.")
            }
            let newUser = User()
            newUser.emailNormalized = email
            newUser.emailVerifiedAt = identity.emailVerified ? Date() : nil
            try await newUser.save(on: request.db)
            guard let newUserID = newUser.id else { throw Abort(.internalServerError) }

            let account = OAuthAccount()
            account.userID = newUserID
            account.provider = provider
            account.issuer = identity.issuer
            account.subject = identity.subject
            try await account.save(on: request.db)
            user = newUser
        }

        let auth = try await issueSession(for: user, on: request)
        var response = Response(status: .ok)
        try response.content.encode(auth)
        response.headers.add(
            name: "Set-Cookie",
            value: "__Host-oidc-session=; Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=0"
        )
        return response
    }

    app.post("v1", "passkeys", "registration", "options") { request async throws -> PasskeyRegistrationOptionsResponse in
        let user = try await authenticatedUser(for: request)
        guard let userID = user.id else { throw Abort(.internalServerError) }
        let manager = try webAuthnManager()
        let options = manager.beginRegistration(
            user: PublicKeyCredentialUserEntity(
                id: opaqueWebAuthnUserID(userID),
                name: user.emailNormalized,
                displayName: user.emailNormalized
            )
        )
        let challenge = PasskeyChallenge()
        challenge.userID = userID
        challenge.ceremony = "registration"
        challenge.challenge = Data(options.challenge).base64URLEncodedString().asString()
        challenge.expiresAt = Date().addingTimeInterval(5 * 60)
        try await challenge.save(on: request.db)
        guard let challengeID = challenge.id else { throw Abort(.internalServerError) }
        return PasskeyRegistrationOptionsResponse(challengeID: challengeID, publicKey: options)
    }

    app.post("v1", "passkeys", "registration", "verify") { request async throws -> MessageResponse in
        let user = try await authenticatedUser(for: request)
        guard let userID = user.id else { throw Abort(.internalServerError) }
        let input = try request.content.decode(PasskeyRegistrationFinishRequest.self)
        let manager = try webAuthnManager()

        let registered = try await request.db.transaction { database -> Bool in
            guard let sql = database as? SQLDatabase else {
                throw Abort(.internalServerError, reason: "Passkey registration requires PostgreSQL.")
            }
            _ = try await sql.raw("SELECT id FROM passkey_challenges WHERE id = \(bind: input.challengeID) FOR UPDATE").all()
            guard let challenge = try await PasskeyChallenge.find(input.challengeID, on: database),
                  challenge.userID == userID,
                  challenge.ceremony == "registration",
                  challenge.consumedAt == nil,
                  challenge.expiresAt > Date(),
                  let challengeBytes = decodeBase64URL(challenge.challenge)
            else { return false }

            let credential = try await manager.finishRegistration(
                challenge: challengeBytes,
                credentialCreationData: input.credential,
                requireUserVerification: true,
                confirmCredentialIDNotRegisteredYet: { credentialID in
                    try await PasskeyCredential.query(on: database)
                        .filter(\.$credentialID == credentialID).first() == nil
                }
            )

            let stored = PasskeyCredential()
            stored.userID = userID
            stored.credentialID = credential.id
                .replacing("+", with: "-")
                .replacing("/", with: "_")
                .replacing("=", with: "")
            stored.publicKey = Data(credential.publicKey).base64URLEncodedString().asString()
            stored.signatureCounter = Int(credential.signCount)
            stored.aaguid = credential.aaguid.map { String(describing: $0) }
            stored.transports = ""
            stored.backupEligible = credential.backupEligible
            stored.backupState = credential.isBackedUp
            try await stored.save(on: database)

            challenge.consumedAt = Date()
            try await challenge.save(on: database)
            return true
        }

        guard registered else {
            throw Abort(.unprocessableEntity, reason: "Passkey registration challenge is invalid, expired, or already used.")
        }
        return MessageResponse(message: "Passkey registered.")
    }

    app.post("v1", "passkeys", "authentication", "options") { request async throws -> PasskeyAuthenticationOptionsResponse in
        let input = try request.content.decode(PasskeyAuthenticationOptionsRequest.self)
        guard let email = normalizedEmail(input.email),
              let user = try await User.query(on: request.db)
                .filter(\.$emailNormalized == email).first(),
              user.disabledAt == nil,
              user.emailVerifiedAt != nil,
              let userID = user.id
        else { throw Abort(.unauthorized, reason: "Passkey sign-in could not be started.") }

        let storedCredentials = try await PasskeyCredential.query(on: request.db)
            .filter(\.$userID == userID).all()
        let descriptors = storedCredentials.compactMap { item -> PublicKeyCredentialDescriptor? in
            guard let bytes = decodeBase64URL(item.credentialID) else { return nil }
            return PublicKeyCredentialDescriptor(id: bytes)
        }
        guard !descriptors.isEmpty else { throw Abort(.unauthorized, reason: "No passkeys are registered for this account.") }

        let options = try webAuthnManager().beginAuthentication(
            allowCredentials: descriptors,
            userVerification: .required
        )
        let challenge = PasskeyChallenge()
        challenge.userID = userID
        challenge.ceremony = "authentication"
        challenge.challenge = Data(options.challenge).base64URLEncodedString().asString()
        challenge.expiresAt = Date().addingTimeInterval(5 * 60)
        try await challenge.save(on: request.db)
        guard let challengeID = challenge.id else { throw Abort(.internalServerError) }
        return PasskeyAuthenticationOptionsResponse(challengeID: challengeID, publicKey: options)
    }

    app.post("v1", "passkeys", "authentication", "verify") { request async throws -> AuthResponse in
        let input = try request.content.decode(PasskeyAuthenticationFinishRequest.self)
        let manager = try webAuthnManager()
        let userID = try await request.db.transaction { database -> UUID? in
            guard let sql = database as? SQLDatabase else {
                throw Abort(.internalServerError, reason: "Passkey authentication requires PostgreSQL.")
            }
            _ = try await sql.raw("SELECT id FROM passkey_challenges WHERE id = \(bind: input.challengeID) FOR UPDATE").all()
            guard let challenge = try await PasskeyChallenge.find(input.challengeID, on: database),
                  challenge.ceremony == "authentication",
                  challenge.consumedAt == nil,
                  challenge.expiresAt > Date(),
                  let challengeBytes = decodeBase64URL(challenge.challenge),
                  let stored = try await PasskeyCredential.query(on: database)
                    .filter(\.$credentialID == input.credential.id.asString()).first(),
                  stored.userID == challenge.userID,
                  stored.signatureCounter >= 0,
                  stored.signatureCounter <= Int(UInt32.max),
                  let publicKey = decodeBase64URL(stored.publicKey),
                  let user = try await User.find(stored.userID, on: database),
                  user.disabledAt == nil,
                  user.emailVerifiedAt != nil,
                  let verifiedUserID = user.id
            else { return nil }

            let verified = try manager.finishAuthentication(
                credential: input.credential,
                expectedChallenge: challengeBytes,
                credentialPublicKey: publicKey,
                credentialCurrentSignCount: UInt32(max(0, stored.signatureCounter)),
                requireUserVerification: true
            )
            stored.signatureCounter = Int(verified.newSignCount)
            stored.backupState = verified.credentialBackedUp
            stored.lastUsedAt = Date()
            try await stored.save(on: database)
            challenge.consumedAt = Date()
            try await challenge.save(on: database)
            return verifiedUserID
        }

        guard let userID,
              let user = try await User.find(userID, on: request.db)
        else { throw Abort(.unauthorized, reason: "Passkey assertion is invalid, expired, or already used.") }
        return try await issueSession(for: user, on: request)
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
                .filter(\.$tokenHash == digest).first(),
                  let session = try await AuthSession.find(record.sessionID, on: database)
            else {
                throw Abort(.unauthorized, reason: "Refresh token is invalid.")
            }

            if record.consumedAt != nil {
                let familySessions = try await AuthSession.query(on: database)
                    .filter(\.$familyID == record.familyID).all()
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
    app.post("v1", "auth", "workos", "exchange") { request async throws -> AuthResponse in
        guard let workOSToken = bearerToken(from: request) else {
            throw Abort(.unauthorized, reason: "A WorkOS access token is required.")
        }
        let identity = try await verifyWorkOSAccessToken(workOSToken, on: request)

        // A transaction-scoped advisory lock serializes simultaneous first logins
        // for this external subject. The unique (issuer, subject) constraint remains
        // the final integrity guard in PostgreSQL.
        let user = try await request.db.transaction { database -> User in
            guard let sql = database as? SQLDatabase else {
                throw Abort(.internalServerError, reason: "WorkOS identity mapping requires PostgreSQL.")
            }
            let lockKey = "workos:\(identity.issuer):\(identity.subject)"
            _ = try await sql.raw("SELECT pg_advisory_xact_lock(hashtext(\(bind: lockKey)))").all()

            if let account = try await OAuthAccount.query(on: database)
                .filter(\.$provider == "workos")
                .filter(\.$issuer == identity.issuer)
                .filter(\.$subject == identity.subject)
                .first(),
               let existing = try await User.find(account.userID, on: database),
               existing.disabledAt == nil,
               existing.emailVerifiedAt != nil {
                return existing
            }

            // Never silently link a WorkOS identity to a local account by email.
            // The user must complete an authenticated, explicit account-link flow.
            if try await User.query(on: database)
                .filter(\.$emailNormalized == identity.email).first() != nil {
                throw Abort(.conflict, reason: "An account already uses this email. Sign in to that account and explicitly link WorkOS first.")
            }

            let created = User()
            created.emailNormalized = identity.email
            created.emailVerifiedAt = Date()
            try await created.save(on: database)
            guard let createdID = created.id else { throw Abort(.internalServerError) }

            let account = OAuthAccount()
            account.userID = createdID
            account.provider = "workos"
            account.issuer = identity.issuer
            account.subject = identity.subject
            try await account.save(on: database)
            return created
        }

        guard let userID = user.id else { throw Abort(.internalServerError) }
        let event = AuditEvent()
        event.actorUserID = userID
        event.eventType = "auth.workos.login"
        event.occurredAt = Date()
        try await event.save(on: request.db)

        // WorkOS tokens are never returned to the iOS app as AuthPlatform tokens.
        // This issues the project's own short-lived access + rotating refresh session.
        return try await issueSession(for: user, on: request)
    }

    app.post("v1", "auth", "workos", "link") { request async throws -> HTTPStatus in
        let localUser = try await authenticatedUser(for: request)
        guard let header = request.headers.first(name: "X-WorkOS-Authorization"),
              header.lowercased().hasPrefix("bearer "),
              !header.dropFirst(7).trimmingCharacters(in: .whitespaces).isEmpty
        else {
            throw Abort(.unauthorized, reason: "A WorkOS bearer token is required to link this identity.")
        }
        let workOSToken = String(header.dropFirst(7)).trimmingCharacters(in: .whitespaces)
        let identity = try await verifyWorkOSAccessToken(workOSToken, on: request)
        guard let localUserID = localUser.id else { throw Abort(.internalServerError) }

        try await request.db.transaction { database in
            guard let sql = database as? SQLDatabase else {
                throw Abort(.internalServerError, reason: "WorkOS identity linking requires PostgreSQL.")
            }
            let lockKey = "workos:\(identity.issuer):\(identity.subject)"
            _ = try await sql.raw("SELECT pg_advisory_xact_lock(hashtext(\(bind: lockKey)))").all()

            if let existing = try await OAuthAccount.query(on: database)
                .filter(\.$provider == "workos")
                .filter(\.$issuer == identity.issuer)
                .filter(\.$subject == identity.subject)
                .first() {
                guard existing.userID == localUserID else {
                    throw Abort(.conflict, reason: "This WorkOS identity is already linked to another account.")
                }
                return
            }

            let account = OAuthAccount()
            account.userID = localUserID
            account.provider = "workos"
            account.issuer = identity.issuer
            account.subject = identity.subject
            try await account.save(on: database)
        }

        let event = AuditEvent()
        event.actorUserID = localUserID
        event.eventType = "auth.workos.link"
        event.occurredAt = Date()
        try await event.save(on: request.db)
        return .noContent
    }

    // Encrypted vault synchronization. The API stores opaque client-encrypted
    // AES-GCM envelopes and never receives or derives a vault decryption key.
    app.get("v1", "vault", "items") { request async throws -> [EncryptedVaultItemResponse] in
        let user = try await authenticatedUser(for: request)
        guard let userID = user.id else { throw Abort(.internalServerError) }
        let items = try await EncryptedVaultItem.query(on: request.db)
            .filter(\.$userID == userID)
            .sort(\.$updatedAt, .descending)
            .all()
        return items.map(EncryptedVaultItemResponse.init)
    }

    app.post("v1", "vault", "items") { request async throws -> Response in
        let user = try await authenticatedUser(for: request)
        guard let userID = user.id else { throw Abort(.internalServerError) }
        let input = try request.content.decode(EncryptedVaultItemWriteRequest.self)

        guard input.formatVersion == 1 else {
            throw Abort(.unprocessableEntity, reason: "Unsupported encrypted vault format version.")
        }
        guard input.ciphertext.utf8.count <= 1_400_000,
              let ciphertext = Data(base64Encoded: input.ciphertext),
              ciphertext.count <= 1_000_000,
              let nonce = Data(base64Encoded: input.nonce), nonce.count == 12,
              let tag = Data(base64Encoded: input.authenticationTag), tag.count == 16
        else {
            throw Abort(.unprocessableEntity, reason: "Vault item must contain a base64 AES-GCM ciphertext, 12-byte nonce, and 16-byte authentication tag.")
        }

        let existing = try await EncryptedVaultItem.query(on: request.db)
            .filter(\.$userID == userID)
            .filter(\.$clientItemID == input.clientItemID)
            .first()
        let item = existing ?? EncryptedVaultItem()
        item.userID = userID
        item.clientItemID = input.clientItemID
        item.ciphertext = input.ciphertext
        item.nonce = input.nonce
        item.authenticationTag = input.authenticationTag
        item.formatVersion = input.formatVersion
        item.deletedAt = nil
        try await item.save(on: request.db)

        let response = Response(status: existing == nil ? .created : .ok)
        try response.content.encode(EncryptedVaultItemResponse(item))
        return response
    }

    app.get("v1", "vault", "items", ":clientItemID") { request async throws -> EncryptedVaultItemResponse in
        let user = try await authenticatedUser(for: request)
        guard let userID = user.id,
              let clientItemID = request.parameters.get("clientItemID", as: UUID.self),
              let item = try await EncryptedVaultItem.query(on: request.db)
                .filter(\.$userID == userID)
                .filter(\.$clientItemID == clientItemID)
                .first()
        else {
            throw Abort(.notFound, reason: "Vault item was not found.")
        }
        return EncryptedVaultItemResponse(item)
    }

    app.delete("v1", "vault", "items", ":clientItemID") { request async throws -> HTTPStatus in
        let user = try await authenticatedUser(for: request)
        guard let userID = user.id,
              let clientItemID = request.parameters.get("clientItemID", as: UUID.self),
              let item = try await EncryptedVaultItem.query(on: request.db)
                .filter(\.$userID == userID)
                .filter(\.$clientItemID == clientItemID)
                .first()
        else {
            throw Abort(.notFound, reason: "Vault item was not found.")
        }
        item.deletedAt = Date()
        try await item.save(on: request.db)
        return .noContent
    }

}
