import Crypto
import Foundation
import SQLKit
import Vapor

/// PostgreSQL-backed fixed-window limiter shared by all application instances.
struct AuthRateLimitMiddleware: AsyncMiddleware {
    let maximumRequests: Int
    let windowSeconds: Int

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        if request.url.path == "/health" || request.url.path == "/v1/auth/capabilities" {
            return try await next.respond(to: request)
        }

        guard let sql = request.db as? SQLDatabase else {
            throw Abort(.internalServerError, reason: "Rate limiting requires the PostgreSQL SQL driver.")
        }

        let client = request.remoteAddress?.description ?? "unknown"
        let bucket = SHA256.hash(data: Data(client.utf8))
            .map { String(format: "%02x", $0) }.joined()

        let rows = try await sql.raw("""
            INSERT INTO auth_rate_limits (id, bucket_key, window_started_at, request_count)
            VALUES (\(bind: UUID()), \(bind: bucket), NOW(), 1)
            ON CONFLICT (bucket_key) DO UPDATE SET
              request_count = CASE
                WHEN auth_rate_limits.window_started_at <= NOW() - (\(bind: windowSeconds) * INTERVAL '1 second') THEN 1
                ELSE auth_rate_limits.request_count + 1
              END,
              window_started_at = CASE
                WHEN auth_rate_limits.window_started_at <= NOW() - (\(bind: windowSeconds) * INTERVAL '1 second') THEN NOW()
                ELSE auth_rate_limits.window_started_at
              END
            RETURNING request_count
            """).all()

        guard let row = rows.first,
              let count = try? row.decode(column: "request_count", as: Int.self)
        else {
            throw Abort(.internalServerError, reason: "Unable to evaluate request rate limit.")
        }

        guard count <= maximumRequests else {
            var headers = HTTPHeaders()
            headers.add(name: "Retry-After", value: String(windowSeconds))
            return Response(status: .tooManyRequests, headers: headers)
        }

        return try await next.respond(to: request)
    }
}
