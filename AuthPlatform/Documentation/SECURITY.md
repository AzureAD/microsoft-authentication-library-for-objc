# Security requirements

- Keep client secrets, signing keys, database credentials, and provider credentials in 1Password-managed server environments. Never put them in iOS bundles, web JavaScript, source control, or build artifacts.
- Store passwords only as salted, deliberately expensive password hashes (Argon2id preferred); never plaintext or reversible encryption.
- Store WebAuthn credential public keys, credential IDs, counters, and authenticator metadata server-side. Private keys remain with the authenticator/passkey provider.
- Generate unpredictable, single-use, short-lived WebAuthn challenges on the server; verify origin, RP ID, challenge, ceremony type, signature, and user-verification policy on the server.
- Treat Face ID/Touch ID as local user-presence/unlock signals. Server authentication must still rely on verified passkey assertions or an appropriately protected session.
- Use OIDC authorization code flow with PKCE for public clients. Validate issuer, audience, signature, nonce, state, redirect URI, and token lifetime. Do not accept arbitrary ID tokens or client-supplied claims.
- Use short-lived access tokens, rotating refresh tokens, reuse detection, revocation, CSRF protections, secure HttpOnly SameSite cookies for browser sessions, and strict CORS.
- Rate-limit login, registration, recovery, token, and passkey endpoints. Add email verification, account recovery, audit logging, monitoring, and abuse controls before production.
- Use TLS in every non-local environment. Restrict database network access and encrypt backups.
- OpenAI code exchange must be performed server-side against the actual configured provider flow. Never fabricate tokens or treat placeholder strings as credentials.
