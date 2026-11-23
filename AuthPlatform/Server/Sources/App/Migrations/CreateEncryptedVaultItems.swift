import Fluent

struct CreateEncryptedVaultItems: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(EncryptedVaultItem.schema)
            .id()
            .field("user_id", .uuid, .required, .references(User.schema, "id", onDelete: .cascade))
            .field("client_item_id", .uuid, .required)
            .field("ciphertext", .string, .required)
            .field("nonce", .string, .required)
            .field("authentication_tag", .string, .required)
            .field("format_version", .int, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("deleted_at", .datetime)
            .unique(on: "user_id", "client_item_id")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(EncryptedVaultItem.schema).delete()
    }
}
