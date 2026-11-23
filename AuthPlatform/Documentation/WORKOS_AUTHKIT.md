# WorkOS AuthKit integration notes

## Native iOS flow

The app uses WorkOS's official `workos-ios` Swift package and `PublicClient` to perform AuthKit authorization-code + PKCE in `WorkOSAuthKitService`.

1. Register `authplatform://auth/callback` in the WorkOS application's Redirects settings.
2. Confirm the Client ID in `App/Info.plist` matches the intended WorkOS application.
3. Build with Xcode 26+ and Swift 6.2+ (the current SDK toolchain requirement).
4. Invoke `WorkOSAuthKitService().signIn()` from an explicit user action.
5. Keep the returned access and refresh tokens in memory until a reviewed session-storage and API-bridge implementation is added.

The service validates the OAuth `state` value and uses the original PKCE verifier for code exchange. It does not embed or accept a WorkOS API key.

## Vapor API trust boundary

The existing Vapor API issues its own opaque AuthPlatform access and refresh tokens. A WorkOS JWT is **not** interchangeable with those tokens. Before WorkOS users can call protected Vapor endpoints, implement and test a server-side WorkOS JWT verifier that:

- obtains signing keys from the configured WorkOS JWKS endpoint and refreshes/caches keys safely;
- verifies the JWT signature, allowed algorithm, issuer, audience/client ID, and expiration;
- rejects malformed tokens and unknown signing keys;
- maps the verified WorkOS subject to a local identity using an explicit, collision-safe linking policy;
- issues a normal AuthPlatform session only after the identity mapping succeeds.

Do not trust an unverified decoded JWT, and do not link accounts solely because email strings match. Do not pass WorkOS refresh tokens to the existing AuthPlatform refresh endpoint.

## Server secrets

Set `WORKOS_API_KEY` only in the trusted Vapor deployment secret store if/when server-side WorkOS API operations are introduced. Never put it in the iOS app, a public build setting, a checked-in `.env` file, or client logs. The native PKCE sign-in itself uses only the public Client ID.
