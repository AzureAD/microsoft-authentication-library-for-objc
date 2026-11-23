# WorkOS AuthKit integration

## Native iOS flow

The app uses the official WorkOS iOS Swift package and PublicClient for AuthKit authorization-code + PKCE in iOS/Authentication/WorkOSAuthKitService.swift.

1. In the WorkOS Dashboard, open Applications, select the application matching the configured Client ID, then open Redirects.
2. Register the exact native callback authplatform://auth/callback.
3. Confirm the Client ID in iOS/App/Info.plist matches the selected WorkOS application.
4. Build with Xcode 26+ and Swift 6.2+.
5. Invoke WorkOSAuthKitService().signIn() only from an explicit user action.

The service validates OAuth state and uses the original PKCE verifier for code exchange. It does not embed or accept a WorkOS API key. WorkOS's iOS SDK requires Xcode 26+ and Swift 6.2+.

## Vapor access-token verification and session exchange

POST /v1/auth/workos/exchange accepts a WorkOS access token in the Bearer Authorization header. The Vapor service:

- downloads the JWKS from the configured HTTPS WorkOS endpoint and verifies the JWT signature with JWTKit;
- checks the configured issuer, expiration, not-before and issued-at times, WorkOS user subject shape, and session ID;
- fetches the corresponding WorkOS user profile using the server-only WORKOS_API_KEY;
- requires the WorkOS profile email to be verified;
- maps an existing external identity only by the unique WorkOS issuer + subject pair;
- refuses automatic linking to an existing local account based only on an email match;\n- provides POST /v1/auth/workos/link, which requires the existing AuthPlatform bearer session plus a separately verified WorkOS bearer token and records an audit event;
- creates a new local identity for a previously unseen WorkOS user only if the verified email is not already in use;
- issues the existing AuthPlatform access and refresh tokens, so the mobile app stores only its own refresh token in Keychain.

The WorkOS access token is not an AuthPlatform bearer token. WorkOS refresh tokens are not accepted by the AuthPlatform refresh endpoint.

## Server environment

Required server-side values:

- WORKOS_CLIENT_ID: public WorkOS application Client ID.
- WORKOS_API_KEY: secret WorkOS API key; use 1Password or the deployment platform's secret manager.
- WORKOS_ISSUER: exact issuer shown by WorkOS; default https://api.workos.com/.
- WORKOS_JWKS_URL: WorkOS signing-key endpoint; default https://api.workos.com/sso/jwks/<client-id>.

Never put WORKOS_API_KEY in the iOS app, GitHub source, a checked-in .env file, build settings, or client logs. Do not send it in chat.

## Remaining production work

This bridge is a first implementation and is not a production security certification. Before production:

- add signed-JWT positive and negative test vectors (wrong signature, issuer, expiry, not-before, subject, key rotation, malformed token);
- add PostgreSQL integration tests for first login, repeated login, concurrent first login, duplicate-email conflict, disabled user, and refresh-token replay;
- implement authenticated account unlinking and re-authentication controls, and add tests for the explicit link flow;
- integrate WorkOS refresh-token rotation and WorkOS session revocation/sign-out semantics;
- add bounded JWKS caching with safe key-rotation refresh and resilience policies;
- verify app bundle identifiers, keychain groups, entitlements, App Store signing, and the actual callback scheme;
- complete threat modeling, rate-limit/IP proxy review, observability, incident response, backups, and deployment rollback drills.

Do not mark the service production-ready until the listed controls are implemented and CI plus staging end-to-end tests pass.
