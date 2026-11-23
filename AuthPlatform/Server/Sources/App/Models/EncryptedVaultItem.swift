import Fluent
import Foundation

/// Stores only an authenticated user's client-encrypted vault envelope.
/// The server deliberately has no API for decrypting this payload.
final class EncryptedVaultItem: Model, @unchecked Sendable {
    static let schema = "encrypted_vault_items"

    @ID(key: .id) var id: UUID?
    @Field(key: "user_id") var userID: UUID
    @Field(key: "client_item_id") var clientItemID: UUID
    @Field(key: "ciphertext") var ciphertext: String
    @Field(key: "nonce") var nonce: String
    @Field(key: "authentication_tag") var authenticationTag: String
    @Field(key: "format_version") var formatVersion: Int
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?
    @OptionalField(key: "deleted_at") var deletedAt: Date?

    init() {}
}
