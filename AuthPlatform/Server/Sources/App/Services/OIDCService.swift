import Foundation
import JWTKit
import Vapor

struct OIDCDiscoveryDocument: Decodable {
    let issuer: String
    let authorizationEndpoint: String
    let tokenEndpoint: String
    let jwksURI: String

    enum CodingKeys: String, CodingKey {
        case issuer
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
        case jwksURI = "jwks_uri"
    }
}

struct OIDCTokenResponse: Decodable {
    let idToken: String

    enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
    }
}

struct OIDCClientConfiguration {
    let provider: String
    let clientID: String
    let clientSecret: String?
    let redirectURI: String
    let discoveryURL: String
}

struct VerifiedOIDCIdentity {
    let issuer: String
    let subject: String
    let email: String
    let emailVerified: Bool
    let displayName: String?
}

struct OIDCTransactionSnapshot {
    let provider: String
    let nonce: String
    let codeVerifier: String
    let redirectURI: String
}

private struct OpenAIIdentityToken: JWTPayload {
    let issuer: IssuerClaim
    let subject: SubjectClaim
    let audience: AudienceClaim
    let expires: ExpirationClaim
    let issuedAt: IssuedAtClaim
    let notBefore: NotBeforeClaim?
    let nonce: String?
    let email: String?
    let emailVerified: Bool?
    let name: String?

    enum CodingKeys: String, CodingKey {
        case issuer = "iss"
        case subject = "sub"
        case audience = "aud"
        case expires = "exp"
        case issuedAt = "iat"
        case notBefore = "nbf"
        case nonce
        case email
        case emailVerified = "email_verified"
        case name
    }

    func verify(using _: some JWTAlgorithm) async throws {
        try expires.verifyNotExpired()
        try notBefore?.verifyNotBefore(currentDate: Date().addingTimeInterval(-300))
        guard issuedAt.value <= Date().addingTimeInterval(300) else {
            throw JWTError.claimVerificationFailure(failedClaim: issuedAt, reason: "Issued-at time is in the future.")
        }
        guard issuer.value == "https://auth.openai.com" else {
            throw JWTError.claimVerificationFailure(failedClaim: issuer, reason: "Unexpected OpenAI identity issuer.")
        }
        guard !subject.value.isEmpty else {
            throw JWTError.claimVerificationFailure(failedClaim: subject, reason: "Missing subject.")
        }
    }
}

func oidcClientConfiguration(for provider: String) throws -> OIDCClientConfiguration {
    switch provider.lowercased() {
    case "openai":
        guard let clientID = Environment.get("OPENAI_CLIENT_ID"), !clientID.isEmpty,
              let redirectURI = Environment.get("OPENAI_REDIRECT_URI"), !redirectURI.isEmpty
        else {
            throw Abort(.serviceUnavailable, reason: "OPENAI_CLIENT_ID and OPENAI_REDIRECT_URI must be configured.")
        }
        return OIDCClientConfiguration(
            provider: "openai",
            clientID: clientID,
            clientSecret: Environment.get("OPENAI_CLIENT_SECRET"),
            redirectURI: redirectURI,
            discoveryURL: "https://auth.openai.com/.well-known/openid-configuration"
        )
    case "microsoft":
        guard let clientID = Environment.get("MICROSOFT_CLIENT_ID"), !clientID.isEmpty,
              let clientSecret = Environment.get("MICROSOFT_CLIENT_SECRET"), !clientSecret.isEmpty,
              let redirectURI = Environment.get("MICROSOFT_REDIRECT_URI"), !redirectURI.isEmpty
        else {
            throw Abort(.serviceUnavailable, reason: "MICROSOFT_CLIENT_ID, MICROSOFT_CLIENT_SECRET, and MICROSOFT_REDIRECT_URI must be configured.")
        }
        let tenant = Environment.get("MICROSOFT_TENANT_ID") ?? "common"
        guard tenant.range(of: #"^[A-Za-z0-9.-]+$"#, options: .regularExpression) != nil else {
            throw Abort(.internalServerError, reason: "MICROSOFT_TENANT_ID is invalid.")
        }
        return OIDCClientConfiguration(
            provider: "microsoft",
            clientID: clientID,
            clientSecret: clientSecret,
            redirectURI: redirectURI,
            discoveryURL: "https://login.microsoftonline.com/\(tenant)/v2.0/.well-known/openid-configuration"
        )
    default:
        throw Abort(.notFound, reason: "Unsupported identity provider.")
    }
}

func loadOIDCDiscovery(_ configuration: OIDCClientConfiguration, on request: Request) async throws -> OIDCDiscoveryDocument {
    let response = try await request.client.get(URI(string: configuration.discoveryURL))
    guard response.status == .ok else {
        throw Abort(.badGateway, reason: "Identity provider discovery failed.")
    }
    let document = try response.content.decode(OIDCDiscoveryDocument.self)
    let expectedHost = configuration.provider == "openai" ? "auth.openai.com" : "login.microsoftonline.com"
    let endpointURLs = [
        URL(string: document.authorizationEndpoint),
        URL(string: document.tokenEndpoint),
        URL(string: document.jwksURI)
    ]
    guard endpointURLs.allSatisfy({ $0?.scheme == "https" && $0?.host == expectedHost }) else {
        throw Abort(.badGateway, reason: "Identity provider discovery returned an unexpected or insecure endpoint.")
    }

    if configuration.provider == "openai" {
        guard document.issuer == "https://auth.openai.com" else {
            throw Abort(.badGateway, reason: "OpenAI discovery issuer did not match the configured provider.")
        }
    } else {
        guard document.issuer.hasPrefix("https://login.microsoftonline.com/"),
              document.issuer.hasSuffix("/v2.0"),
              !document.issuer.contains("..")
        else {
            throw Abort(.badGateway, reason: "Microsoft discovery issuer is invalid.")
        }
    }
    return document
}

private func formEncodedComponent(_ value: String) -> String {
    var components = URLComponents()
    components.queryItems = [URLQueryItem(name: "v", value: value)]
    return String((components.percentEncodedQuery ?? "v=").dropFirst(2))
}

func exchangeOIDCCode(
    _ code: String,
    configuration: OIDCClientConfiguration,
    discovery: OIDCDiscoveryDocument,
    codeVerifier: String,
    on request: Request
) async throws -> String {
    var fields = [
        URLQueryItem(name: "grant_type", value: "authorization_code"),
        URLQueryItem(name: "code", value: code),
        URLQueryItem(name: "redirect_uri", value: configuration.redirectURI),
        URLQueryItem(name: "client_id", value: configuration.clientID),
        URLQueryItem(name: "code_verifier", value: codeVerifier)
    ]

    var components = URLComponents()
    if configuration.provider == "microsoft", let secret = configuration.clientSecret {
        fields.append(URLQueryItem(name: "client_secret", value: secret))
    }
    components.queryItems = fields
    guard let body = components.percentEncodedQuery else {
        throw Abort(.internalServerError, reason: "Unable to encode OIDC token request.")
    }

    let response = try await request.client.post(URI(string: discovery.tokenEndpoint)) { outbound in
        outbound.headers.add(name: "Content-Type", value: "application/x-www-form-urlencoded")
        outbound.headers.add(name: "Accept", value: "application/json")
        if configuration.provider == "openai", let secret = configuration.clientSecret {
            let credentials = "\(formEncodedComponent(configuration.clientID)):\(formEncodedComponent(secret))"
            let encoded = Data(credentials.utf8).base64EncodedString()
            outbound.headers.add(name: .authorization, value: "Basic \(encoded)")
        }
        outbound.body = .init(string: body)
    }

    guard response.status == .ok else {
        request.logger.warning("OIDC token exchange failed for provider \(configuration.provider)")
        throw Abort(.unauthorized, reason: "Identity provider rejected the authorization code.")
    }
    let tokenResponse = try response.content.decode(OIDCTokenResponse.self)
    return tokenResponse.idToken
}

func verifyOIDCIdentity(
    provider: String,
    idToken: String,
    nonce: String,
    clientID: String,
    discovery: OIDCDiscoveryDocument,
    on request: Request
) async throws -> VerifiedOIDCIdentity {
    let jwksResponse = try await request.client.get(URI(string: discovery.jwksURI))
    guard jwksResponse.status == .ok else {
        throw Abort(.badGateway, reason: "Identity provider signing keys could not be loaded.")
    }
    let jwks = try jwksResponse.content.decode(JWKS.self)
    let keys = try await JWTKeyCollection().add(jwks: jwks)

    switch provider {
    case "openai":
        let claims = try await keys.verify(idToken, as: OpenAIIdentityToken.self)
        guard claims.audience.value.contains(clientID),
              claims.issuer.value == discovery.issuer,
              claims.nonce == nonce,
              let email = claims.email,
              !email.isEmpty,
              claims.emailVerified == true
        else {
            throw Abort(.unauthorized, reason: "OpenAI identity token claims are invalid or the email is not verified.")
        }
        return VerifiedOIDCIdentity(
            issuer: claims.issuer.value,
            subject: claims.subject.value,
            email: email,
            emailVerified: true,
            displayName: claims.name
        )
    case "microsoft":
        let claims = try await keys.verify(idToken, as: MicrosoftIdentityToken.self)
        guard claims.audience.value.contains(clientID),
              claims.issuedAt.value <= Date().addingTimeInterval(300),
              claims.notBefore.value <= Date(),
              claims.nonce == nonce,
              let tenantID = claims.tenantId.value,
              UUID(uuidString: tenantID) != nil,
              claims.issuer.value == discovery.issuer.replacingOccurrences(
                of: "{tenantid}",
                with: tenantID,
                options: .caseInsensitive
              ),
              let email = claims.email ?? claims.preferredUsername,
              !email.isEmpty
        else {
            throw Abort(.unauthorized, reason: "Microsoft identity token claims are invalid or no email claim is available.")
        }
        return VerifiedOIDCIdentity(
            issuer: claims.issuer.value,
            subject: claims.subject.value,
            email: email,
            emailVerified: false,
            displayName: claims.name
        )
    default:
        throw Abort(.notFound, reason: "Unsupported identity provider.")
    }
}
