# Security requirements and implementation notes

- Keep client secrets, signing keys, database credentials, and provider credentials in 1Password-managed server environments. Never put them in iOS bundles, web JavaScript, source control, or build artifacts.
- Passwords are hashed with Vapor's password hasher; production should use an explicitly reviewed Argon2id configuration and benchmark the work factor.
- Email verification and password reset use random, short-lived, single-use tokens. Only token digests are stored. Resend delivers the links.
- Refresh rotation locks the presented token row inside a PostgreSQL transaction. Reuse revokes every session in the token family. Concurrency tests remain required.
- Rate limiting uses PostgreSQL atomic upserts and applies across server instances. Tune limits and trusted-proxy/IP handling for the actual deployment.
- WebAuthn uses the Swift WebAuthn relying-party implementation. The server stores challenges and verifies challenge, origin, RP ID, attestation/assertion response, signature, and user-verification requirements. Private keys remain with the authenticator.
- OIDC uses authorization code + PKCE, random state, nonce, a secure browser-session cookie, discovery, JWKS signature verification, issuer/audience/nonce checks, and one-time state consumption.
- Microsoft email claims are not assumed verified. Sign in with ChatGPT accounts are accepted only when the ID token contains a verified email.
- Do not auto-link an OIDC identity to an existing local account solely because the email strings match. Account linking must require an authenticated account session.
- OpenAI API keys are server-to-server credentials; they are not end-user OIDC tokens. Sign in with ChatGPT requires an approved OAuth client and exact callback registration.
- Treat Face ID/Touch ID as local user-presence/unlock signals. Server authentication must rely on verified passkey assertions or protected sessions.
- Use TLS in every non-local environment. Restrict database network access and encrypt backups.

## Before production

The current branch still requires successful CI and database-backed integration tests for refresh concurrency/replay, password reset/verification, OIDC state/nonce/signature/audience failures, WebAuthn attestation/assertion failures, and rate-limit behavior. Add CSRF protection for cookie-authenticated browser routes, strict CORS, audit-event coverage, cleanup for expired transaction/token rows, monitoring, and abuse controls. Do not treat this scaffold as production-approved.
