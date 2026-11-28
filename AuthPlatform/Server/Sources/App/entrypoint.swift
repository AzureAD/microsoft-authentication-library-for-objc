import Vapor

@main
enum Entrypoint {
    static func main() async throws {
        var environment = try Environment.detect()
        try LoggingSystem.bootstrap(from: &environment)
        let app = try await Application.make(environment)
        do {
            try await configure(app)

            // Schema changes must be an explicit release operation, never an
            // implicit side effect of starting the web service.
            if Environment.get("MIGRATE_ONLY") == "true" {
                try await app.autoMigrate()
                try await app.asyncShutdown()
                return
            }

            try await app.execute()
            try await app.asyncShutdown()
        } catch {
            app.logger.report(error: error)
            try? await app.asyncShutdown()
            throw error
        }
    }
}
