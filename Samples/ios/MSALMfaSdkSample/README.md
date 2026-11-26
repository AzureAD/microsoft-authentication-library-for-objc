# MSAL MFA sample - experimental

This sample demonstrates the settled MFA and token-provider APIs using SwiftUI,
camera scanning, APNs callbacks and browser-based token acquisition.

**The MFA manager on `dev` is currently an API stub.** Its operations throw a
general not-implemented error. This change does not add SAS requests, enrollment,
token rotation, challenge validation, Graph deletion or MFA Keychain storage.
The app handles these errors rather than simulating successful authentication.
Do not use this sample for production authentication.

## Workspace and signing

Open `MSALMfaSdkSample.xcworkspace` in this directory and select the
`MSALMfaSdkSample` scheme. Use the root `MSAL.xcworkspace` for SDK development,
not the framework project directly.

Use Xcode 16 or later (Swift 6 compiler). Swift 5 language mode remains supported.
The sample targets iOS 17+; camera scanning requires supported VisionKit hardware.

The bundle ID is **`com.microsoft.azureauthenticator`**. This does not authorize
signing or enable push delivery. You need authorized provisioning for that
identity, Push Notifications enabled, a matching APNs environment and a dedicated
test device. Installing this identity may replace Authenticator. Do not install
over an app holding real credentials.

No signing team, provisioning profile, certificate or credential is supplied.
`MSAL_MFA_APNS_ENVIRONMENT` must agree with the signed `aps-environment`:
Debug defaults to `development`, Release to `production`. Override it when your
provisioning requires a different value.

The sample retains `MARKETING_VERSION = 6.8.56` from the POC's Authenticator
compatibility capture. This does not change SDK version, authorize the app, or
prove compatibility with a deployed service.

## Sample flow

1. **Accounts** displays SDK-returned account names and usernames. Pull to refresh
   requests pending challenges. Deletion requires confirmation and shows progress.
2. **Scan QR code** obtains camera input and APNs registration, then passes the
   decoded text unchanged to the SDK.
3. **Add account** accepts an activation URL and activation code, not a TOTP secret.
   Sensitive input is cleared on submission or navigation.

The app delegate owns one shared `MSALNativeAuthMFAManager` for enrollment, token
updates, notification handling and decisions. UI presentation, notification
permission, camera access and background completion handlers belong to the app.
Parsing activation data, interpreting policy and executing authentication belong
to the SDK and are not implemented by this sample.

```swift
try await sdk.updatePushRegistration(
    deviceToken: token,
    apnsEnvironment: environment
)

let input = MSALNativeAuthMFARegistrationParameters(qrCode: scannedText)
// Manual input uses the activation URL and code supplied by enrollment:
let manual = MSALNativeAuthMFARegistrationParameters(
    activationCode: enteredCode,
    activationURL: enteredURL
)

let result = try await sdk.registerAuthMethod(registrationParameters: input)
```

On the current API-stub SDK, the first operation fails explicitly; there is no
successful registration to display.

## Notifications and decisions

Forward raw Apple notification dictionaries without filtering, logging,
stringifying or wrapping them as unchecked Sendable values:

```swift
let sessions = try await sdk.handlePushNotification(payload: userInfo)
```

The defaulted `isolation` parameter inherits the caller's actor, allowing the
main-actor app delegate to pass `[AnyHashable: Any]` without transferring it to
another executor. Leave that parameter at its default. Do not send the raw
dictionary through a detached task.

The sample suppresses duplicate prompts, rejects stale operation results and
completes background callbacks once. Its timeout cancels the pending operation;
cancellation does not imply that a future SDK implementation can undo a request.
Notification delivery or tapping a notification never submits an approval.

For a manager-issued session, explicit user actions use the settled API:

```swift
let decision = try await sdk.respond(
    authSession: session,
    action: .approve(number: enteredNumber)
)
// Denial:
let denied = try await sdk.respond(authSession: session, action: .deny)
```

Retain the original session object. Do not reconstruct sessions from GUIDs.
The sample handles `isInvalidCode` as retryable only because that classifier
explicitly permits another attempt; general errors do not authorize replay.
An acknowledged decision is not proof that browser sign-in completed.

## Deletion token provider

The sample supplies an `MSALTokenProvider` implemented using MSAL browser-based
authentication. It forwards the requested scopes, claims, authority and
correlation ID, attempts silent acquisition first, and presents interactive
authentication only when needed and permitted.

The sample retains the Authenticator public-client ID
`4813382a-8fa7-425e-ab75-3b753aab3abb` for authorized compatibility testing, with
redirect URI `msauth.com.microsoft.azureauthenticator://auth`. Using those values
does not grant access or consent. The signed app identity, registered redirect,
tenant policy and delegated permissions must all be valid.

Broker integration is disabled in this sample; the provider uses a browser
presentation that allows MFA prompts in the sample to remain accessible.
Provider errors remain distinct from MFA SDK errors. The provider does not invent
claims or implement Graph DELETE. The current manager stub does not invoke it.

## Validation

The sample contains only the application target, with no sample test suite.
The user runs builds in Xcode. Agent validation is limited to static
source, project, plist, XML and diff inspection; no local builds, tests, compilers,
linters, simulators, app launches or dependency restores are run.

Build and manually validate the sample before relying on the integration. Live
enrollment and decisions additionally require an executing SDK implementation
and an authorized service/device environment.
