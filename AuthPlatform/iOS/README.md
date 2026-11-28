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


## Host app authentication, save, and unlock flow

The starter host app now calls the Vapor backend's `POST /v1/auth/login` endpoint. Configure these keys in `App/Info.plist` before running:

- `AUTH_API_BASE_URL`: the public HTTPS origin of the deployed Vapor API (for local simulator-only testing, use a loopback URL; a physical iPhone needs a reachable HTTPS host).
- `AUTH_CREDENTIAL_SERVICE`: the exact website domain to which this saved credential belongs, without a URL scheme.
- `CredentialKeychainAccessGroup`: the same fully-qualified Keychain access group used by the extension's entitlements.

After a successful verified-account login, the app stores the refresh token in the shared Keychain group. The user must explicitly tap **Save this sign-in to this iPhone** to save the username/password in the device-only credential vault. The **Unlock with Face ID / device passcode** action gates retrieval with LocalAuthentication. The Credential Provider Extension independently requires device-owner authentication before returning a password.

The backend verifies the account password and email-verification state. The password itself is not sent to or stored by the local credential vault API; the vault is local Keychain storage shared with the extension. Do not use the example domain or API URL in a release build.

### Physical-device test checklist

1. Configure a real HTTPS API endpoint, website domain, Team ID, bundle IDs, Associated Domains entitlement, and AASA `webcredentials.apps` entry.
2. Use the same Team ID and Keychain access group in the host app and extension provisioning profiles.
3. Generate the Xcode project, select a physical iPhone destination, and build/sign the `AuthPlatform` scheme.
4. Install the containing app, sign in with an email-verified test account, and explicitly save the credential.
5. Enable AuthPlatform under Settings → General → AutoFill & Passwords → Passwords & Passkeys.
6. Open the configured website in Safari, choose the saved credential, and verify that device-owner authentication is required before the password is returned.
7. Test cancellation, wrong domain, no saved credential, locked device, revoked account, and extension relaunch.
8. Confirm no password or refresh token appears in logs, analytics, crash reports, or app-group files.

A simulator build cannot prove extension provisioning, Associated Domains, Keychain sharing, or real AutoFill behavior. Those require the signed physical-device test above.
