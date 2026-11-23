# AuthPlatform

A separate Swift/Vapor identity application alongside the upstream MSAL SDK. The application lives under `AuthPlatform/` and does not alter MSAL SDK source files.

## Components

- `Server/`: Vapor API, PostgreSQL/Fluent persistence, password and session endpoints.
- `iOS/`: AuthenticationServices passkey UI integration and Keychain boundary.
- `Web/`: shared portal integration contract.
- `Documentation/SECURITY.md`: security boundaries and deployment requirements.

## Local setup

1. Install Swift 6.0+ and PostgreSQL 15+.
2. Create a PostgreSQL database and set `DATABASE_URL`.
3. Configure the required email and relying-party variables from `Server/.env.example`.
4. Run migrations: `cd Server && swift run App migrate --yes`.
5. Start the API: `swift run App`.
6. Check `GET /health`.

## Implemented API

- `POST /v1/auth/register`: creates an unverified account and sends an email verification link.
- `POST /v1/auth/verification/request`: requests another verification email.
- `POST /v1/auth/verify-email`: consumes a one-time verification token.
- `POST /v1/auth/login`: password login; verified email required.
- `POST /v1/auth/password/forgot` and `POST /v1/auth/password/reset`: one-time password recovery.
- `POST /v1/auth/refresh`: transactional PostgreSQL row-lock refresh rotation and replay-family revocation.
- `POST /v1/auth/logout`: session revocation.
- `GET /v1/users/me`: bearer-protected profile.
- `GET /v1/oidc/{microsoft|openai}/start` and `GET /v1/oidc/{microsoft|openai}/callback`: OIDC authorization-code + PKCE.
- `POST /v1/passkeys/registration/options`, `POST /v1/passkeys/registration/verify`, `POST /v1/passkeys/authentication/options`, and `POST /v1/passkeys/authentication/verify`: WebAuthn ceremonies.
- PostgreSQL-backed fixed-window API rate limiting is enabled for application routes.

## WorkOS AuthKit (native iOS)

The iOS project includes the official WorkOS Swift package and a native AuthKit PKCE client in `iOS/Authentication/WorkOSAuthKitService.swift`. The public Client ID is configured in `iOS/App/Info.plist`; no WorkOS API key or client secret belongs in the app.

- Client ID: `client_01KY8YVZNZ4XWZAT0401X9CR4W`
- Native callback: `authplatform://auth/callback`
- Register that exact callback under the WorkOS application's Redirects settings before testing.
- The iOS SDK requires Xcode 26+ and Swift 6.2+. The project currently uses Swift 5 language mode; build it with the required modern toolchain and address any compiler compatibility issues before release.
- The iOS demo now exposes a **Continue with WorkOS** action and performs native PKCE sign-in. It intentionally discards the returned WorkOS tokens after the sign-in check; token persistence and the WorkOS-to-Vapor session bridge are not implemented yet.
- Do not treat a WorkOS access token as an AuthPlatform API session token. A server-side JWT/JWKS verifier and explicit identity/session bridge are required before WorkOS identities can access the existing Vapor-protected API.
- Configure `WORKOS_API_KEY` only in the trusted Vapor deployment environment (for example, a 1Password-managed secret). Never commit its value or add it to the iOS target.

See `Documentation/WORKOS_AUTHKIT.md` for the trust boundary and remaining server-side work.

## Provider setup

- WorkOS: enable AuthKit, register the exact native callback URI above, and keep the API key server-side.
- Microsoft: register the exact callback URI in Microsoft Entra ID and set the client ID, tenant, client secret, and redirect URI.
- Sign in with ChatGPT: obtain an approved `oaiapp_...` client registration and exact callback URI before enabling it. The website integration is currently a limited trial.
- WebAuthn: configure the exact HTTPS origin and RP ID for the production host. Localhost is for development only.
- Email: configure a verified Resend sender and the public frontend base URL.

All provider secrets must remain in a 1Password-managed server environment. OpenAI API keys are server-to-server credentials and are separate from Sign in with ChatGPT OIDC credentials.

## Security status

This is an actively implemented development branch, not a production-ready identity provider. CI must complete successfully and security/integration tests must pass before deployment. Refresh rotation, OIDC transactions, passkey challenges, one-time email tokens, and rate-limit buckets are persisted in PostgreSQL. Add concurrency, provider-token, WebAuthn negative-case, email-delivery, and full end-to-end tests before production. Do not deploy with placeholder secrets or an unverified email sender.
