import Fluent
import FluentPostgresDriver
import Vapor

func configure(_ app: Application, emailSender: AuthEmailSender? = nil) async throws {
    guard let databaseURL = Environment.get("DATABASE_URL"), !databaseURL.isEmpty else {
        throw Abort(.internalServerError, reason: "DATABASE_URL must be configured as a PostgreSQL URL.")
    }

    try app.databases.use(.postgres(url: databaseURL), as: .psql)

    app.http.server.configuration.hostname = Environment.get("HOST") ?? "127.0.0.1"
    app.http.server.configuration.port = Environment.get("PORT").flatMap(Int.init) ?? 8080

    app.migrations.add(CreateIdentitySchema())
    app.migrations.add(AddRefreshTokenHistory())
    app.migrations.add(AddAuthSecurityTables())
    app.migrations.add(CreateEncryptedVaultItems())
    app.middleware.use(AuthRateLimitMiddleware(maximumRequests: 120, windowSeconds: 60))
    try routes(app, emailSender: emailSender)
}
