# Persistence model implementation plan

The next migration set should introduce:
- users: normalized email, verification timestamp, password hash, disabled timestamp, created/updated timestamps;
- passkey_credentials: user relation, credential ID, public key, signature counter, AAGUID, transports, backup eligibility/state, created/last-used timestamps;
- sessions: hashed opaque refresh token, family identifier, expiry, rotation/revocation timestamps, user-agent and risk metadata;
- oauth_accounts: issuer, subject, provider, linked user, created timestamp;
- audit_events: actor, event type, timestamp, coarse request metadata.

Never store passkey private keys or plaintext refresh tokens. Add unique constraints for normalized email, issuer+subject, and credential ID. Add indexes for user lookups and expiry cleanup. Migrations must be reviewed before production deployment.
