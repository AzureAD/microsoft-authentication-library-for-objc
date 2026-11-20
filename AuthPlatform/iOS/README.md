# Native iOS client

Use SwiftUI with AuthenticationServices for passkeys and LocalAuthentication for local convenience unlock. Use Keychain for app-owned refresh/session credentials with appropriate accessibility and access-control attributes.

Microsoft sign-in should use MSAL for iOS/macOS and authorization-code/PKCE flows as supported by the SDK. Configure the app registration redirect URI and URL scheme from the actual Entra app registration; do not invent client IDs or tenant IDs.

The app must send verified passkey assertion payloads to the Vapor backend. A local Face ID/Touch ID success is not a replacement for a server-verifiable WebAuthn assertion.


## Apple Password AutoFill and credential provider

The iOS project is defined in `project.yml` (XcodeGen). Generate and open it with:

```sh
brew install xcodegen
xcodegen generate --spec AuthPlatform/iOS/project.yml --project AuthPlatform/iOS
open AuthPlatform/iOS/AuthPlatform.xcodeproj
```

The project includes a host app target and an embedded AutoFill Credential Provider Extension target. See [APPLE_PASSWORD_MANAGER_RESOURCES.md](APPLE_PASSWORD_MANAGER_RESOURCES.md) for resource bundling, Associated Domains/AASA, shared Keychain group, signing, and device validation steps.

The current host screen is an AutoFill integration starter. It demonstrates the correct username, password, new-password, and one-time-code content types; it is not yet wired to the Vapor API or a complete vault UI. Store a credential in `SharedCredentialVault` only after an explicit user-approved save flow. Replace all example bundle IDs, domains, and Keychain access groups before device testing.
