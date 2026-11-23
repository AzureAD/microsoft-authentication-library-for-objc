import Foundation
import JWTKit
import Vapor

func isValidWorkOSSubject(_ subject: String) -> Bool {
    subject.range(of: #"^user_[A-Za-z0-9_]+$"#, options: .regularExpression) != nil
}

struct WorkOSAccessTokenPayload: JWTPayload {
    let issuer: IssuerClaim
    let subject: SubjectClaim
    let expiration: ExpirationClaim
    let issuedAt: IssuedAtClaim
    let notBefore: NotBeforeClaim?
    let sessionID: String

    enum CodingKeys: String, CodingKey {
        case issuer = "iss"
        case subject = "sub"
        case expiration = "exp"
        case issuedAt = "iat"
        case notBefore = "nbf"
        case sessionID = "sid"
    }

    func verify(using _: some JWTAlgorithm) async throws {
        try expiration.verifyNotExpired()
        try notBefore?.verifyNotBefore(currentDate: Date())
        guard issuedAt.value <= Date().addingTimeInterval(60) else {
            throw JWTError.claimVerificationFailure(failedClaim: issuedAt, reason: "Issued-at time is in the future.")
        }
        guard isValidWorkOSSubject(subject.value),
              !sessionID.isEmpty
        else {
            throw JWTError.claimVerificationFailure(failedClaim: subject, reason: "WorkOS user or session identifier is missing.")
        }
    }
}

struct WorkOSUserRecord: Decodable {
    let id: String
    let email: String
    let emailVerified: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case emailVerified = "email_verified"
    }
}

struct VerifiedWorkOSIdentity {
    let issuer: String
    let subject: String
    let sessionID: String
    let email: String
}

func verifyWorkOSAccessToken(_ token: String, on request: Request) async throws -> VerifiedWorkOSIdentity {
    guard token.count <= 16_384,
          let clientID = Environment.get("WORKOS_CLIENT_ID"), !clientID.isEmpty,
          let apiKey = Environment.get("WORKOS_API_KEY"), !apiKey.isEmpty
    else {
        throw Abort(.serviceUnavailable, reason: "WorkOS server configuration is incomplete.")
    }

    let issuer = Environment.get("WORKOS_ISSUER") ?? "https://api.workos.com/"
    let jwksURL = Environment.get("WORKOS_JWKS_URL")
        ?? "https://api.workos.com/sso/jwks/\(clientID)"
    guard let issuerURL = URL(string: issuer),
          issuerURL.scheme == "https",
          let jwksEndpoint = URL(string: jwksURL),
          jwksEndpoint.scheme == "https",
          (jwksEndpoint.host == "api.workos.com" || jwksEndpoint.host == issuerURL.host)
    else {
        throw Abort(.internalServerError, reason: "WorkOS issuer or JWKS configuration is invalid.")
    }

    let jwksResponse = try await request.client.get(URI(string: jwksURL))
    guard jwksResponse.status == .ok else {
        request.logger.error("WorkOS JWKS endpoint returned HTTP \(jwksResponse.status.code).")
        throw Abort(.badGateway, reason: "WorkOS signing keys are temporarily unavailable.")
    }
    let jwks = try jwksResponse.content.decode(JWKS.self)
    let keys = try await JWTKeyCollection().add(jwks: jwks)
    let claims = try await keys.verify(token, as: WorkOSAccessTokenPayload.self)

    guard claims.issuer.value == issuer,
          isValidWorkOSSubject(claims.subject.value)
    else {
        throw Abort(.unauthorized, reason: "WorkOS access token issuer or subject is invalid.")
    }

    // WorkOS access tokens intentionally contain identity/session identifiers, not
    // necessarily profile email claims. Resolve the profile using the server-only API key.
    let profileResponse = try await request.client.get(
        URI(string: "https://api.workos.com/user_management/users/\(claims.subject.value)")
    ) { outbound in
        outbound.headers.add(name: .authorization, value: "Bearer \(apiKey)")
        outbound.headers.add(name: .accept, value: "application/json")
    }
    guard profileResponse.status == .ok else {
        request.logger.warning("WorkOS user profile lookup failed with HTTP \(profileResponse.status.code).")
        throw Abort(.unauthorized, reason: "The WorkOS identity could not be resolved.")
    }
    let profile = try profileResponse.content.decode(WorkOSUserRecord.self)
    guard profile.id == claims.subject.value,
          profile.emailVerified,
          let email = normalizedEmail(profile.email)
    else {
        throw Abort(.forbidden, reason: "A verified WorkOS email address is required.")
    }

    return VerifiedWorkOSIdentity(
        issuer: claims.issuer.value,
        subject: claims.subject.value,
        sessionID: claims.sessionID,
        email: email
    )
}
