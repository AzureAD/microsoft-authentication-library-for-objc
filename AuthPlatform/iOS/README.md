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

The host app includes the AutoFill integration and an encrypted-vault workflow. It demonstrates username, password, new-password, and one-time-code content types. Store a credential in `SharedCredentialVault` only after an explicit user-approved save flow. The host app can create a vault key, export a recovery package, restore on a device without an existing vault key, synchronize encrypted envelopes, and propagate online deletions as server tombstones. Replace all example bundle IDs, domains, and Keychain access groups before device testing.


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

## Encrypted vault cryptography and recovery

`Authentication/VaultCryptography.swift` uses CryptoKit AES-256-GCM with a fresh 96-bit nonce per write and item-ID-bound authenticated additional data. The 256-bit master key is stored in the shared Keychain access group with `WhenUnlockedThisDeviceOnly` accessibility. The server receives only the encoded ciphertext, nonce, and authentication tag.

When creating a vault, call `VaultCryptography.createVaultKey()` once. Show the returned high-entropy recovery code to the user exactly once and require explicit acknowledgement that it has been stored offline. Persist the returned `RecoveryPackage` as a separately backed-up recovery artifact; it contains only the wrapped master key, salt, nonce, and authentication tag, never the master key itself. On a replacement device, restore with `restoreVaultKey(recoveryCode:package:)`. A wrong code or modified package fails AES-GCM authentication.

Do not log the recovery code, package, plaintext credential, or master key. Do not upload the recovery code to the API. The current implementation does not yet provide server-side recovery-package synchronization, recovery-code rotation, or multi-device key distribution; therefore it is not yet a complete multi-device recovery experience. The caller must export and safely retain the package and code until a separately reviewed sync design is implemented.


### Encrypted vault workflow

1. Sign in with an email-verified AuthPlatform account.
2. Choose **Create encrypted vault and recovery code**. The 256-bit master key is stored in the device-only Keychain; the recovery code is generated from 256 bits of secure randomness.
3. Export the JSON recovery package as a `.json` file using the iOS file exporter. Store the displayed recovery code separately and offline. Confirm the in-app acknowledgement before the first sync.
4. Save credentials only after the explicit **Save this sign-in to this iPhone** action. The AutoFill credential remains in the device-only shared Keychain; synchronization seals a Codable copy using AES-256-GCM with a fresh nonce and item-ID-bound AAD.
5. Choose **Synchronize encrypted vault**. The app rotates its AuthPlatform refresh token, fetches the authenticated user's encrypted records, applies server tombstones, authenticates/decrypts active records, updates local Keychain credentials, and uploads the resulting local set as encrypted envelopes.
6. To move to a replacement device, sign in, import the exported JSON package, enter the separately stored recovery code, and then synchronize. Restore is rejected if a vault key already exists on the device.
7. Delete a saved credential from **Manage saved credentials**. The app records the server tombstone first; if the server request fails, the local credential is retained.

The server never receives plaintext credentials, the recovery code, or the master key. The local AutoFill store remains protected by the existing device-only Keychain policy and device-owner authentication in the Credential Provider Extension. Shared Keychain enumeration filters entries against the credential schema and matching website service so session tokens and the vault key are not treated as credentials.

**Current boundary:** this client integration uses the existing list/upsert/tombstone API. The API does not yet provide pagination, item revisions, or conflict-resolution metadata. Concurrent edits on different devices therefore do not have a complete deterministic conflict policy; do not represent this as production-complete multi-device synchronization. Recovery-package synchronization and recovery-code rotation are also not implemented.