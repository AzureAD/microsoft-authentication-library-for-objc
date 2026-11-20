# Native iOS client

Use SwiftUI with AuthenticationServices for passkeys and LocalAuthentication for local convenience unlock. Use Keychain for app-owned refresh/session credentials with appropriate accessibility and access-control attributes.

Microsoft sign-in should use MSAL for iOS/macOS and authorization-code/PKCE flows as supported by the SDK. Configure the app registration redirect URI and URL scheme from the actual Entra app registration; do not invent client IDs or tenant IDs.

The app must send verified passkey assertion payloads to the Vapor backend. A local Face ID/Touch ID success is not a replacement for a server-verifiable WebAuthn assertion.
