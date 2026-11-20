# Identity persistence models

The server now defines Fluent models and a PostgreSQL migration for:
- users with normalized email, password-hash slot, verification and disable timestamps;
- passkey credentials with credential ID, public key, counter, AAGUID, transport metadata and backup flags;
- refresh-token sessions storing only a token hash, family ID, expiry and rotation/revocation metadata;
- OAuth identities keyed by issuer and subject;
- audit events with coarse request metadata.

## Apply the migration

From `AuthPlatform/Server`, run `swift run App migrate` as a deliberate release step, then start the service with `swift run App`. Fluent records applied migrations and skips them on subsequent migration runs. Do not run schema changes implicitly on every production server startup.

`transports` and optional risk/request metadata are stored as strings in this initial schema; use a versioned structured representation before depending on them for policy decisions.

## Security requirements

- Never persist passkey private keys or plaintext refresh tokens.
- Hash refresh tokens with a server-side keyed hash before persistence.
- Hash passwords with Argon2id (or an equivalently reviewed password hashing scheme); never store plaintext or reversible passwords.
- Normalize and validate email addresses before uniqueness checks.
- Enforce WebAuthn challenge, origin, RP ID, signature, and counter verification in the service layer before updating a credential.
- Add retention, privacy, rate-limit, and audit-redaction policies before production.
