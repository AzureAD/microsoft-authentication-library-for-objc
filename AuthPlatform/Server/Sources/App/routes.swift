import Vapor

func routes(_ app: Application) throws {
    app.get("health") { _ async -> [String: String] in
        ["status": "ok", "service": "auth-platform"]
    }

    app.get("v1", "auth", "capabilities") { _ async -> [String: [String]] in
        [
            "protocols": ["openid-connect", "oauth2"],
            "methods": ["email-password", "webauthn-passkey", "microsoft-oidc"],
            "clients": ["ios", "web"]
        ]
    }
}
