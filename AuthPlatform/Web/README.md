# Shared web portal

The web client is a separate deployable frontend that consumes the Swift Vapor API. It must not implement password verification, token signing, Microsoft client-secret exchange, or WebAuthn verification in browser code.

## Required browser behavior
- Use authorization-code flow with PKCE for OIDC sign-in.
- Prefer server-managed sessions in Secure, HttpOnly, SameSite cookies.
- Use CSRF tokens for state-changing cookie-authenticated requests.
- Use WebAuthn browser APIs only to create/get credential responses; send those responses to the server for verification.
- Do not persist access tokens, refresh tokens, passwords, or provider secrets in localStorage/sessionStorage.
- Restrict CORS to explicitly configured portal origins.
