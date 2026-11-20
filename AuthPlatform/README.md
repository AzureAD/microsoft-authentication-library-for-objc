# AuthPlatform

A separate authentication application alongside the upstream MSAL SDK. This directory does not modify MSAL sources.

## Components
- `Server/`: Swift Vapor API and PostgreSQL persistence.
- `iOS/`: SwiftUI client integration points for Apple AuthenticationServices and Keychain.
- `Web/`: shared portal integration contract.
- `Documentation/SECURITY.md`: security boundaries and deployment requirements.

## Local server setup
1. Install Swift 5.10+ and PostgreSQL 15+.
2. Set `DATABASE_URL` in your local environment (never commit credentials).
3. Run `cd Server && swift run`.
4. The health endpoint is `GET /health`.

## Security status
This is an initial implementation scaffold, not a production identity provider. Email verification, password login, WebAuthn ceremony verification, OAuth/OIDC callbacks, token issuance, rate limiting, and operational hardening must be completed and tested before production use. Do not accept client-supplied claims or treat a successful local biometric prompt as server authentication.
