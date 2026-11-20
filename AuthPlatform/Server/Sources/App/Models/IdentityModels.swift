import Fluent
import Foundation

final class User: Model, @unchecked Sendable {
    static let schema = "users"

    @ID(key: .id) var id: UUID?
    @Field(key: "email_normalized") var emailNormalized: String
    @OptionalField(key: "password_hash") var passwordHash: String?
    @OptionalField(key: "email_verified_at") var emailVerifiedAt: Date?
    @OptionalField(key: "disabled_at") var disabledAt: Date?
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?

    init() {}
}

final class PasskeyCredential: Model, @unchecked Sendable {
    static let schema = "passkey_credentials"

    @ID(key: .id) var id: UUID?
    @Field(key: "user_id") var userID: UUID
    @Field(key: "credential_id") var credentialID: String
    @Field(key: "public_key") var publicKey: String
    @Field(key: "signature_counter") var signatureCounter: Int
    @OptionalField(key: "aaguid") var aaguid: String?
    @Field(key: "transports") var transports: String
    @Field(key: "backup_eligible") var backupEligible: Bool
    @Field(key: "backup_state") var backupState: Bool
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    @OptionalField(key: "last_used_at") var lastUsedAt: Date?

    init() {}
}

final class AuthSession: Model, @unchecked Sendable {
    static let schema = "auth_sessions"

    @ID(key: .id) var id: UUID?
    @Field(key: "user_id") var userID: UUID
    @Field(key: "family_id") var familyID: UUID
    @Field(key: "access_token_hash") var accessTokenHash: String
    @Field(key: "access_expires_at") var accessExpiresAt: Date
    @Field(key: "refresh_token_hash") var refreshTokenHash: String
    @Field(key: "expires_at") var expiresAt: Date
    @OptionalField(key: "rotated_at") var rotatedAt: Date?
    @OptionalField(key: "revoked_at") var revokedAt: Date?
    @OptionalField(key: "user_agent") var userAgent: String?
    @OptionalField(key: "risk_metadata") var riskMetadata: String?
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?

    init() {}
}

final class OAuthAccount: Model, @unchecked Sendable {
    static let schema = "oauth_accounts"

    @ID(key: .id) var id: UUID?
    @Field(key: "user_id") var userID: UUID
    @Field(key: "provider") var provider: String
    @Field(key: "issuer") var issuer: String
    @Field(key: "subject") var subject: String
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?

    init() {}
}

final class AuditEvent: Model, @unchecked Sendable {
    static let schema = "audit_events"

    @ID(key: .id) var id: UUID?
    @OptionalField(key: "actor_user_id") var actorUserID: UUID?
    @Field(key: "event_type") var eventType: String
    @Field(key: "occurred_at") var occurredAt: Date
    @OptionalField(key: "request_metadata") var requestMetadata: String?

    init() {}
}


final class RefreshTokenRecord: Model, @unchecked Sendable {
    static let schema = "refresh_token_records"

    @ID(key: .id) var id: UUID?
    @Field(key: "session_id") var sessionID: UUID
    @Field(key: "family_id") var familyID: UUID
    @Field(key: "token_hash") var tokenHash: String
    @Field(key: "expires_at") var expiresAt: Date
    @OptionalField(key: "consumed_at") var consumedAt: Date?
    @OptionalField(key: "revoked_at") var revokedAt: Date?
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?

    init() {}
}


final class OneTimeAuthToken: Model, @unchecked Sendable {
    static let schema = "one_time_auth_tokens"

    @ID(key: .id) var id: UUID?
    @Field(key: "user_id") var userID: UUID
    @Field(key: "purpose") var purpose: String
    @Field(key: "token_hash") var tokenHash: String
    @Field(key: "expires_at") var expiresAt: Date
    @OptionalField(key: "consumed_at") var consumedAt: Date?
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?

    init() {}
}

final class AuthRateLimit: Model, @unchecked Sendable {
    static let schema = "auth_rate_limits"

    @ID(key: .id) var id: UUID?
    @Field(key: "bucket_key") var bucketKey: String
    @Field(key: "window_started_at") var windowStartedAt: Date
    @Field(key: "request_count") var requestCount: Int

    init() {}
}
