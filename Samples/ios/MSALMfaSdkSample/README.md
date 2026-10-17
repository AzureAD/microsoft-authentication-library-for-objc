# MSAL MFA sample

The sample uses MSAL's account-registration and sign-in-request interfaces through
`import MSAL`. The app collects real input, calls the SDK, and displays returned
data. It contains no fabricated QR payloads, accounts, sessions, or decisions.

**Implementation status:** the SDK currently returns temporary local responses.
Network enrollment, secret validation, number verification, and account
persistence are not implemented yet. Production-shaped interfaces and UI do not
make this build suitable for authentication or authorization enforcement.
Use test accounts and keys while the service implementation is unfinished.
That implementation detail is not exposed as a public SDK flag or an app label.

## Workspace

Open [`MSALMfaSdkSample.xcworkspace`](MSALMfaSdkSample.xcworkspace) and select
the shared `MSALMfaSdkSample` scheme. It contains the dedicated sample project,
which references the existing `MSAL/MSAL.xcodeproj` for its framework dependency.
Do not use `Samples/ios/SampleApp.xcworkspace` for this sample.

The app targets iOS 17+ and uses Swift 5. Its build configuration is
[`MSALMfaSdkSample.xcconfig`](MSALMfaSdkSample.xcconfig). The repository-root
`MSAL.xcworkspace` remains the workspace for SDK development.

## Three-screen flow

1. **Accounts:** displays registration results in an in-memory list. The floating
   QR button opens the scanner. Rows reset when the app restarts; no persistent
   account store is implemented.
2. **Scan QR code:** uses VisionKit's `DataScannerViewController` with the camera
   to recognize QR codes. After obtaining notification permission and an APNs
   device token, the app awaits `updatePushRegistration` before passing only
   the decoded text to `registerAuthMethod(registrationParameters:)`.
   The app asks for camera access
   and declares `NSCameraUsageDescription`. Unsupported devices, denied access,
   and scanner failures show actionable messages and retain manual entry.
3. **Add account:** **Enter code manually** opens the account-name and secure
   secret-key form. **Finish** passes both exact entered strings in
   `MSALNativeAuthMfaSdkRegistrationParameters(accountName:secretKey:)` to
   `registerAuthMethod(registrationParameters:)`, the same method used for QR input.
   It does not fabricate a QR payload from the entered fields.
   Empty fields disable Finish. The secret field is cleared on submission or
   navigation away; secrets and QR payloads are not logged or retained in rows.

Camera scanning requires a supported physical device (VisionKit data scanning
requires supported hardware). The simulator cannot scan; manual entry remains
available there. Capture stops after one QR result, when leaving the scanner,
or when the app becomes inactive. **Scan again** starts a new attempt after a
failure. **Open Settings** lets users change camera permission.

## QR activation and push registration

QR activation uses the app's real APNs registration flow:

1. Request notification authorization through `UNUserNotificationCenter`.
2. Call `UIApplication.registerForRemoteNotifications()` on the main actor.
3. Receive `Data` in the app delegate's
   `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` callback.
4. Await `updatePushRegistration` with the exact token bytes and explicit
   `MSALNativeAuthMfaSdkAPNsEnvironment`.
5. Pass decoded QR text to `registerAuthMethod` on the same SDK manager.

`MSALMfaSamplePushRegistration` waits for Apple's success/failure callback and
successful SDK token handoff before allowing activation, including when reusing
a cached token. If a newer callback arrives while waiting, it waits for that
update instead. Failed handoffs block activation and can be retried.
Denied permission, empty tokens, registration errors, invalid
configuration, and a missing callback (30-second timeout) produce actionable
errors. **Open Settings** is available for denied notifications. Retrying starts
a new attempt. Concurrent token waiters share one APNs registration request;
canceling one does not cancel the others. Navigation cancellation prevents late
APNs completion from activating the dismissed QR request. Independent SDK token
updates still run. The system registration itself is not
unregistered when a screen is dismissed.

The latest callback token is cached only in memory for the current app launch.
Notification permission is checked even when reusing it. Later token callbacks
replace that cached value. Neither raw nor encoded tokens are logged, added to
account rows, or persisted by the sample.

### Token updates independent of account activation

On launch and each return to the foreground, the sample checks existing
notification authorization. If authorized, it registers with APNs again even
when a token is cached. This path never prompts for permission; first-time
permission remains part of QR setup.

Every successful Apple token callback, including unchanged tokens and callbacks
received after leaving the scanner, calls:

```swift
try await sdk.updatePushRegistration(
    deviceToken: deviceToken,
    apnsEnvironment: environment
)
```

The app delegate owns one SDK instance, shared with QR/manual registration and
challenge operations. The sample does not compare tokens, loop through accounts,
or recreate registrations. Token updates do not wait for an earlier SDK update
to finish. Errors appear on Accounts without raw token/error details; a newer
callback's result cannot be overwritten by an older completion. Returning to
the app requests a fresh Apple callback, which resubmits the token.

The internal `MSALNativeAuthMfaSdkDeviceTokenManager` actor retains the latest
token/environment in memory per SDK manager instance. Empty tokens are rejected
without replacing the previous value. QR activation requires this state and
throws `MSALNativeAuthMfaSdkPushRegistrationError.missingPushRegistration` if
`updatePushRegistration` has not completed on that instance.

**Service implementation remains stubbed:** SDK state is not persisted and is
not evidence of server synchronization. Registration reconciliation, network
calls, and automatic service retries remain unimplemented.

Both input screens use the same SDK registration operation. Manual name/key entry
continues without requesting push permission; QR activation reads the SDK's push
destination. The separate signed-in `RegisterPhoneAppRequest`
SAS flow is not implemented.

### Signing and APNs environment

Select a signing team and an App ID with **Push Notifications** enabled in Xcode.
The sample target declares that capability and uses
`MSALMfaSdkSample.entitlements`. Valid push-enabled provisioning is required;
adding the local entitlement does not provision an App ID or signing credentials.

`MSAL_MFA_APNS_ENVIRONMENT` supplies both the `aps-environment` entitlement and
the `MSALMfaAPNsEnvironment` value in the sample's `Info.plist`. Debug defaults to
`development` (SDK `.sandbox`); Release defaults to `production`.
Override this setting when the signing environment differs, such as a
development-signed Release build. Verify that it matches the **signed** entitlement
after Xcode/export provisioning; export can change entitlements. The app reads
the configured value rather than inferring the environment from `DEBUG`, and
rejects missing or unknown values.

The sample sends raw token bytes, not `apns2-` / `sb-apns2-` strings. Service-specific
encoding belongs to the SDK's future QR-activation implementation. The SDK still
returns a stub result: it does not yet format/send the token to the activation
service, process validation pushes, or update existing service registrations
when a token rotates.

Pulling down on Accounts calls `pullPendingNotifications()`. The sign-in
alert displays the returned session's account name and username. **Yes** requires
a whole-number entry and calls `approve(authSession:number:)`; **No, it's not me**
calls `deny(authSession:)`. Completion and error messages reflect SDK outcomes.
The app does not compare the entered number with a locally generated challenge.

Crossing the refresh threshold queues the request until the gesture is released.
The refresh indicator stops and the pulled-down list returns to the top before
the alert appears. Duplicate refreshes, scans, and response taps cannot overlap
an active operation. Navigation cancellation invalidates late results.

## SDK interface

Public classes each have their own file under `MSAL/src/native_auth/public/mfa/`.
Registration parameters contain real input fields; result and session objects
contain immutable data supplied by the SDK. There is no public scan-simulation
method or `isMock` property. Camera/UI handling belongs to the app.

`registerAuthMethod(registrationParameters:)` is the single registration entry
point. Construct `MSALNativeAuthMfaSdkRegistrationParameters` using either
`init(qrCode:)` or `init(accountName:secretKey:)`.
The immutable object contains either QR text or the exact entered name/key, never
both. Fields for the other input representation are nil. The SDK owns decoding
and validation; the current stub does not yet parse QR payloads or validate secrets.

All service operations are `async throws`, so replacing temporary responses with
network calls does not require changing the call pattern. The sample handles
registration, refresh, and response failures without displaying raw errors that
could contain account data. Temporary response values exist only in the manager's
implementation. They are not generated by public result/session initializers or
the sample.

**Migration from earlier branch revisions:** remove calls to `simulateQrCodeScan`
and reads of `isMock`. Replace `MSALNativeAuthMfaSdkManualRegistrationParameters`
with the name/key initializer on `MSALNativeAuthMfaSdkRegistrationParameters`,
and replace `addThirdPartyAccount` with `registerAuthMethod`.
Handle SDK calls with `try await`. Remove `deviceToken` and `apnsEnvironment`
from registration parameters. Supply them only to `updatePushRegistration`,
await completion, then activate using the same manager instance.
MFA parameter and APNs-environment source membership matches the iOS and macOS
framework targets. CocoaPods' existing `native-auth` source glob includes them. The generated
binary SPM manifest is unchanged and still references the released binary, not
these local source changes. No dependency or packaging configuration is added.

## Authenticator reference

Authenticator informed the camera and APNs lifecycle integration. This sample's
SDK deliberately exposes one registration method for both input representations;
it does not copy Authenticator's TOTP implementation, protocol code, or storage.

## Local validation

The user runs validation from this dedicated workspace. Agent checks are limited
to static source, project, scheme, and diff inspection: no local builds, tests,
compilers, linters, simulators, app launches, or dependency restores.

The scheme selects `MSALNativeAuthMfaSdkTests` in MSAL's existing iOS unit-test
target and `MSALMfaSdkSampleTests` in the dedicated sample project.
Sample tests live in `Tests/MSALMfaSampleModelTests.swift`; only the sample project
references and compiles the sample sources. Its test bundle reuses the generic
`unit-test-host` app for UIKit lifecycle tests without launching the sample's
APNs registration flow. The dependency remains sample-to-SDK, never SDK-to-sample.
Coverage includes direct QR/name/key forwarding,
SDK-returned metadata, failures and retries, duplicate and stale-operation
handling, camera-result deduplication and teardown, notification permission,
APNs callbacks/failure/timeout/cancellation/retry, token rotation, raw token and
environment forwarding, silent launch/foreground acquisition, repeated-token
submission, SDK update failure recovery, stale update completions, and the hosted
Accounts refresh/alert lifecycle.
Push tests inject system operations; they do not contact APNs or prompt for
permission. The sample model, views, app delegate, and camera/push adapters are
compiled into the sample app and its own test bundle, not any MSAL target.

In Xcode, build Debug and Release and run the selected tests. On a supported
physical device, check camera permission grant/denial, Settings return, QR
decoding, retry, repeated frames, navigation away, and background/foreground
capture cleanup. Also check manual entry, refresh release timing, both sign-in
decisions, keyboard handling, Dynamic Type, and VoiceOver. With push-enabled
signing, check notification permission grant/denial, the real APNs success/failure
callbacks, environment alignment, canceling QR activation while waiting, and
foreground token acquisition without another permission prompt.
Static inspection is
not evidence of successful compilation or camera behavior.

Future service activation must follow the repository's feature-gating and release
requirements. The sample now contacts Apple's notification services; the SDK
still performs no activation-service network call, TOTP, Keychain, or persistence.
