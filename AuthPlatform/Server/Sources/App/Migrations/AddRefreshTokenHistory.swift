import Fluent

struct AddRefreshTokenHistory: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(RefreshTokenRecord.schema)
            .id()
            .field("session_id", .uuid, .required, .references(AuthSession.schema, "id", onDelete: .cascade))
            .field("family_id", .uuid, .required)
            .field("token_hash", .string, .required)
            .field("expires_at", .datetime, .required)
            .field("consumed_at", .datetime)
            .field("revoked_at", .datetime)
            .field("created_at", .datetime)
            .unique(on: "token_hash")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(RefreshTokenRecord.schema).delete()
    }
}
