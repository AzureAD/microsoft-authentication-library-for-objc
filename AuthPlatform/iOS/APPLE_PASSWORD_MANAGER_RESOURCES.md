# Apple Password Manager Resources integration

This folder vendors a read-only snapshot of selected data from [apple/password-manager-resources](https://github.com/apple/password-manager-resources). The upstream Apple repository is not modified, forked, or used as a write target.

## Integrated resources

- `password-rules.json`: maps website domains to Password Rules descriptors used by UIKit's `UITextInputPasswordRules`.
- `shared-credentials.json`: domain groups for contextual suggestions only.
- `shared-credentials-historical.json`: historical relationships for reuse-warning context only.
- `change-password-URLs.json`: known password-change destinations.
- `websites-that-append-2fa-to-password.json`: websites where a one-time code is appended to the password.
- `apple-appIDs-to-domains-shared-credentials.json`: app identifiers mapped to their related website domains.
- `websites-that-ask-for-credentials-for-other-services-when-embedded-as-third-party.json`: sites known to request unrelated credentials in third-party frames.

The snapshot is pinned by the repository commit that updates these files. Refresh it deliberately with `scripts/sync-apple-password-manager-resources.sh`, review the diff, and commit the update. Do not silently download mutable upstream data at app runtime.

## iOS Password AutoFill (option A)

1. Add `Authentication/ApplePasswordManagerResources.swift` and the JSON files in `Resources/ApplePasswordManager/` to the host iOS app target.
2. Add `AuthPlatform.entitlements` to the host app's Code Signing Entitlements build setting.
3. Replace `YOUR_AUTH_DOMAIN` with the exact production website domain. Publish a valid Apple App Site Association file at `https://YOUR_AUTH_DOMAIN/.well-known/apple-app-site-association` with a `webcredentials` section containing the actual app identifier.
4. Set username, current password, new password, and one-time-code fields using `AuthAutoFillConfiguration`. For SwiftUI, use `.textContentType(.username)`, `.textContentType(.password)`, `.textContentType(.newPassword)`, and `.textContentType(.oneTimeCode)` respectively.
5. On web forms, use `autocomplete="username"`, `autocomplete="current-password"`, `autocomplete="new-password"`, and `autocomplete="one-time-code"`. Where the Apple rules dataset has a matching rule, set the HTML `passwordrules` attribute to that descriptor.

## Credential Provider Extension (option B)

This repository currently has no Xcode project or host-app target to attach an extension target to. The extension source and target configuration are supplied as scaffolding; Xcode target creation and signing must be completed in the actual iOS app project.

1. In Xcode, add a new **AutoFill Credential Provider Extension** target.
2. Add `CredentialProviderExtension/CredentialProviderViewController.swift`, `Authentication/SharedCredentialVault.swift`, and `Authentication/ApplePasswordManagerResources.swift` to the extension target. Add the resource JSON files to both the host app and extension target because each target reads its own bundle.
3. Use `CredentialProviderExtension/Info.plist` and `CredentialProviderExtension/CredentialProvider.entitlements` for the extension target.
4. Add `AuthPlatform.entitlements` to the containing app target. Enable the AutoFill Credential Provider entitlement for both targets in the Apple Developer portal and Xcode signing settings.
5. Replace `com.example.authplatform.shared` with the same real Keychain access group in both entitlements. Set the Info.plist key `CredentialKeychainAccessGroup` to that exact fully-qualified group in both targets.
6. Use the same Apple Team, App Identifier Prefix, and provisioning profiles for both targets.
7. Save credentials into `SharedCredentialVault` only after the user explicitly chooses to save them. The vault uses device-only Keychain items protected until the device is unlocked. It indexes usernames/domains in `ASCredentialIdentityStore`; passwords stay in Keychain. Add the same `CredentialKeychainAccessGroup` Info.plist value to the host app and extension. Call `SharedCredentialVault.refreshSystemCredentialIdentities` after account/vault migrations and syncs.
8. Test enabling the provider under Settings → General → AutoFill & Passwords → Passwords & Passkeys (wording varies by iOS release).

## Security boundaries

- Shared-credential mappings never authorize cross-domain credential release. They only provide context for user-reviewed suggestions.
- Historical mappings are never treated as current credential affiliation.
- The extension deliberately refuses silent credential release and requires device-owner authentication before returning a password.
- Do not put raw passwords, access tokens, refresh tokens, or provider secrets in the identity store, app group files, UserDefaults, logs, or the server-side Apple resource snapshot.
- Keychain access group and AutoFill entitlements require Apple Developer provisioning. Placeholder identifiers in this repository are not deployable.
- The extension source is a starting integration, not a signed, built, or App Store-approved extension. Validate API availability and signing against the minimum iOS deployment target in the real Xcode project.

## Web form example

```html
<label for="email">Email</label>
<input id="email" name="email" type="email" autocomplete="username">

<label for="password">Password</label>
<input id="password" name="password" type="password" autocomplete="current-password">

<label for="new-password">New password</label>
<input id="new-password" name="newPassword" type="password"
       autocomplete="new-password" passwordrules="minlength: 12;">

<label for="otp">Verification code</label>
<input id="otp" name="otp" inputmode="numeric" autocomplete="one-time-code">
```

The example rule is illustrative only. For a real site, use the matching descriptor from Apple's resource snapshot or the site's published requirements.
