# AuthPlatform

A separate Swift/Vapor identity application alongside the upstream MSAL SDK. The application lives under AuthPlatform/ and does not alter MSAL SDK source files.

## Components

- Server/: Vapor API, PostgreSQL/Fluent persistence, password and session endpoints.
- iOS/: native iOS app and Credential Provider extension.
- Web/: shared portal integration contract.
- Documentation/SECURITY.md: security boundaries and deployment requirements.

## Local setup

1. Install Swift 6.2+ and PostgreSQL 15+.
2. Create a PostgreSQL database and set DATABASE_URL.
3. Configure the required email, WorkOS, and relying-party variables from Server/.env.example.
4. Set WORKOS_API_KEY only in your server secret store. Never commit it or include it in the iOS app.
5. Run migrations: cd Server && swift run App migrate --yes.
6. Start the API: swift run App.
7. Check GET /health.

## Implemented API

- POST /v1/auth/register: creates an unverified account and sends an email verification link.
- POST /v1/auth/verification/request: requests another verification email.
- POST /v1/auth/verify-email: consumes a one-time verification token.
- POST /v1/auth/login: password login; verified email required.
- POST /v1/auth/password/forgot and POST /v1/auth/password/reset: one-time password recovery.
- POST /v1/auth/refresh: transactional PostgreSQL row-lock refresh rotation and replay-family revocation.
- POST /v1/auth/logout: session revocation.
- POST /v1/auth/workos/exchange: verifies a WorkOS access JWT using WorkOS JWKS, retrieves the verified WorkOS profile using the server API key, resolves the external subject to a local identity, and issues a native AuthPlatform session.\n- POST /v1/auth/workos/link: links a separately authenticated WorkOS identity to the currently authenticated local account; matching email alone is never sufficient.
- GET /v1/users/me: bearer-protected profile.
- GET /v1/oidc/{microsoft|openai}/start and GET /v1/oidc/{microsoft|openai}/callback: OIDC authorization-code + PKCE.
- POST /v1/passkeys/registration/options, POST /v1/passkeys/registration/verify, POST /v1/passkeys/authentication/options, and POST /v1/passkeys/authentication/verify: WebAuthn ceremonies.
- PostgreSQL-backed fixed-window API rate limiting is enabled for application routes.

## WorkOS AuthKit (native iOS)

The iOS app includes WorkOS's official Swift package and a native AuthKit PKCE client in iOS/Authentication/WorkOSAuthKitService.swift. The public Client ID is configured in iOS/App/Info.plist; no WorkOS API key or client secret belongs in the app.

- Client ID: client_01KY8YVZNZ4XWZAT0401X9CR4W
- Native callback: authplatform://auth/callback
- Register that exact callback under the WorkOS application's Redirects settings before testing.
- The SDK requires Xcode 26+ and Swift 6.2+; the XcodeGen project now requests Swift 6.2.
- After native PKCE sign-in, the iOS app sends the WorkOS access token over TLS to the Vapor exchange endpoint. It stores only the resulting AuthPlatform refresh token in the shared Keychain. WorkOS refresh tokens are not sent to the AuthPlatform refresh endpoint.
- The Vapor bridge verifies the JWT signature and standard session claims, resolves the WorkOS user through the server-only API, requires a verified email, and maps accounts only by WorkOS issuer + subject. It deliberately does not silently link by matching email.
- Existing local users must sign in to their local account and use the explicit Link WorkOS to this account action. The route requires both the current AuthPlatform bearer session and a separately verified WorkOS access token.
- WorkOS logout/session revocation and refresh-token rotation at WorkOS are not yet integrated; sign out should be treated as local AuthPlatform session revocation until this is completed.

See Documentation/WORKOS_AUTHKIT.md for the trust boundary and remaining work.

## Provider setup

- WorkOS: enable AuthKit, register the exact native callback URI above, and keep the API key server-side.
- Microsoft: register the exact callback URI in Microsoft Entra ID and set the client ID, tenant, client secret, and redirect URI.
- Sign in with ChatGPT: obtain an approved oaiapp_... client registration and exact callback URI before enabling it.
- WebAuthn: configure the exact HTTPS origin and RP ID for the production host. Localhost is for development only.
- Email: configure a verified Resend sender and the public frontend base URL.

All provider secrets must remain in a 1Password-managed server environment. OpenAI API keys are server-to-server credentials and are separate from Sign in with ChatGPT OIDC credentials.

## Release status

This branch is not yet production-approved. Require passing iOS and server CI, database-backed security tests, production secret configuration, verified WorkOS callback registration, TLS and domain setup, monitored deployment, and an operational rollback plan. Do not deploy with placeholder URLs or secrets.
