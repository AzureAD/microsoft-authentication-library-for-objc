# AuthPlatform Server

AuthPlatform is a Swift/Vapor service. PostgreSQL is a required runtime dependency for the current server implementation; it is not an optional add-on.

## Why PostgreSQL is required

The server configures Fluent with the PostgreSQL driver and fails startup when `DATABASE_URL` is missing. The database stores durable, user-scoped security state, including:

- User identities, password hashes, and email-verification state.
- Passkey credential public keys, signature counters, and backup metadata.
- OAuth provider identity links.
- Access/refresh session hashes, token rotation history, expiry, and revocation state.
- One-time verification/reset tokens and WebAuthn/OIDC challenges.
- Audit events and persisted rate-limit buckets.
- Client-encrypted vault records, including ciphertext, nonce, authentication tag, format version, and deletion tombstones.

The server stores encrypted vault envelopes only; client-side master keys and plaintext vault contents must remain on the user's device.

Removing PostgreSQL without replacing these persistence capabilities would break startup and/or weaken account security, session revocation, passkey login, email flows, and cross-device vault sync. Do not remove the database dependency merely because the currently provisioned Railway database service is stopped or removed.

## Local development

1. Provision a PostgreSQL database (local Docker, local installation, or a managed PostgreSQL service).
2. Set `DATABASE_URL` to a PostgreSQL connection URL.
3. Set the required identity-provider, email, and WebAuthn environment variables for the features being tested.
4. Start the server. Fluent migrations are registered in `configure.swift` and must be run using the repository's migration/deployment procedure.

Example:

```sh
export DATABASE_URL='postgresql://auth_user:password@127.0.0.1:5432/auth_platform'
swift run
```

Do not commit real credentials. Keep production secrets in the hosting provider's secret manager.

## Railway deployment

For Railway, provide `DATABASE_URL` as a reference to an active PostgreSQL service in the same project/environment, or use a separately managed PostgreSQL endpoint. Confirm the service is active, backups/retention are configured, and the application can connect before deploying the API.

A stopped or removed Railway PostgreSQL service is not proof that the application no longer needs a database. It means the database must be restored/reprovisioned or replaced before the current backend can run.

## Can PostgreSQL be removed?

Only after an intentional architecture change replaces every database-backed capability with an equivalent durable and secure persistence layer, migrations and tests are rewritten, and the product scope explicitly removes features such as account/session persistence or encrypted vault sync. That is not the architecture currently implemented.
