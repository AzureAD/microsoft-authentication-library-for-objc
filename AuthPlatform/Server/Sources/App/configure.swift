import Fluent
import FluentPostgresDriver
import Vapor

func configure(_ app: Application) async throws {
    guard let databaseURL = Environment.get("DATABASE_URL"),
          let url = URL(string: databaseURL),
          let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          components.scheme == "postgres" || components.scheme == "postgresql",
          let host = components.host,
          let database = components.path.split(separator: "/").last.map(String.init),
          let username = components.user
    else {
        throw Abort(.internalServerError, reason: "DATABASE_URL must be configured as a PostgreSQL URL.")
    }

    let password = components.password ?? ""
    let port = components.port ?? 5432

    app.databases.use(
        .postgres(
            hostname: host,
            port: port,
            username: username,
            password: password,
            database: database,
            tls: .prefer(try .init(configuration: .clientDefault))
        ),
        as: .psql
    )

    app.http.server.configuration.hostname = Environment.get("HOST") ?? "127.0.0.1"
    app.http.server.configuration.port = Environment.get("PORT").flatMap(Int.init) ?? 8080

    app.migrations.add(CreateIdentitySchema())
    if Environment.get("RUN_MIGRATIONS") == "true" {
        try await app.autoMigrate()
    }
    try routes(app)
}
