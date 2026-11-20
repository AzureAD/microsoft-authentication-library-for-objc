import Fluent

struct AddAuthSecurityTables: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(OneTimeAuthToken.schema)
            .id()
            .field("user_id", .uuid, .required, .references(User.schema, "id", onDelete: .cascade))
            .field("purpose", .string, .required)
            .field("token_hash", .string, .required)
            .field("expires_at", .datetime, .required)
            .field("consumed_at", .datetime)
            .field("created_at", .datetime)
            .unique(on: "token_hash")
            .create()

        try await database.schema(AuthRateLimit.schema)
            .id()
            .field("bucket_key", .string, .required)
            .field("window_started_at", .datetime, .required)
            .field("request_count", .int, .required)
            .unique(on: "bucket_key")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(AuthRateLimit.schema).delete()
        try await database.schema(OneTimeAuthToken.schema).delete()
    }
}
