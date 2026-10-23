# MSAL MFA sample - experimental phase two

**Unit-test results and real-service E2E remain unverified.**
It replaces local success stubs with network operations and SDK-owned Keychain
storage. Do not use it for production authentication until the unit tests,
signing configuration and real-device enrollment/approval flows are validated.

## Signing and workspace

Open `MSALMfaSdkSample.xcworkspace` here and select `MSALMfaSdkSample`.
Use the root `MSAL.xcworkspace` for SDK development, not the framework project
directly. The sample targets iOS 17+ and requires supported hardware for VisionKit.

The sample bundle ID is **`com.microsoft.azureauthenticator`**. This alone does
not authorize signing or enable push delivery. You need authorized provisioning
for that identity, Push Notifications enabled, a service-supported APNs
environment, and a dedicated test device. Installing this identity may replace
Authenticator. Do not install over an app holding real credentials.

No signing team, profile, certificate or credential is supplied by this change.
`MSAL_MFA_APNS_ENVIRONMENT` must agree with the final signed `aps-environment`:
Debug defaults to `development`, Release to `production`. Override the setting
when required by your actual provisioning. The SDK receives raw APNs bytes and
the explicit environment; it does not infer environment from a build macro.

## SDK and sample responsibilities

MFA SDK types now use the `MSALNativeAuthMFA` prefix, for example
`MSALNativeAuthMFAManager`. This is a source-breaking rename of the experimental
API: update app type references and rebuild. Method names and behavior are
unchanged; compatibility aliases are not provided.

For the SAS compatibility investigation, this sample's `MARKETING_VERSION` is
`6.8.56`, matching the Authenticator version in the supplied capture. The SDK
continues reading the hosting app's `CFBundleShortVersionString` for the service
version and HTTP `AppVersion`; no Authenticator version is hardcoded in MSAL.
This metadata match does not change signing, APNs delivery, or SDK release version.

The SDK derives enrollment's `DeviceName` using the existing
`MSIDDeviceId.deviceHardwareType()` helper. It sends a hardware identifier such as
`iPhone13,2`, not a friendly model label or the user's personalized device name.
The sample no longer supplies or overrides this value. If the helper returns no
usable value, enrollment fails with `invalidResponse` before activation is sent.

The app delegate owns one shared manager:

```swift
let sdk = MSALNativeAuthMFAManager()
```

No opt-in flag is required. Keep one shared instance for callbacks, enrollment
and session decisions. UIKit, notification authorization, camera capture and
presentation belong to the sample, not the SDK.

The SDK owns activation decoding, SOAP/XML requests, validation proofs,
session/account association, endpoint checks and Keychain persistence. It uses an
isolated Keychain service, not Authenticator's account-store format or shared
access groups. Requests use an ephemeral HTTP session with redirects and cookies
disabled, bounded response parsing and no request/response body logging. The
MFA transport is separate from the existing CIAM OAuth request configuration.

## Three screens

1. **Accounts** restores SDK registration metadata after relaunch. Pull to refresh
   retrieves pending sessions. Existing refresh-release/alert presentation
   behavior is preserved.
2. **Scan QR code** captures actual QR text, acquires APNs permission/token,
   awaits SDK token handoff, then calls the registration method.
3. **Add account** accepts the **activation URL and activation code** shown by the
   enrollment page. It also requires APNs registration. This is not a TOTP
   account-name/secret form. The code is cleared on submission or navigation.

Both input forms call the same operation:

QR decoding accepts the legacy `activate_account` form and the HTTPS
`https://login.microsoftonline.com/authenticatorApp/activateAccount` form with
`accountType=mfa`. Both extract the activation `code` and `url` query values;
the embedded service URL must still pass the SDK's endpoint checks.

```swift
try await sdk.updatePushRegistration(
    deviceToken: token,
    apnsEnvironment: environment
)

let input = MSALNativeAuthMFARegistrationParameters(qrCode: scannedText)
// Or:
let manual = MSALNativeAuthMFARegistrationParameters(
    activationCode: enteredCode,
    activationURL: enteredURL
)
let result = try await sdk.registerAuthMethod(registrationParameters: input)
let accounts = try await sdk.registeredAuthMethods()
```

Registration accepts only QR text or an activation code and URL. `otpauth://`
and third-party TOTP enrollment are not supported. Internal full-HMAC validation
proofs are part of the service protocol, not a user-facing TOTP feature.

## Push and token lifecycle

Apple callbacks always forward token updates, including unchanged tokens and
updates received outside enrollment. The SDK distinguishes the latest acquired
token from each account's successfully activated token. Updates reconcile stale
accounts; a repeated callback can retry an earlier failed synchronization.

Token updates use only the V2 start/validation/complete protocol. An already
activated token triggers no update in either Debug or Release. Accounts needing
an update must have their stored registration ID and secret; missing values fail
with `invalidResponse`, without a legacy fallback. `DeviceTokenChangeV1` pushes
are rejected. `PhoneAppValidateDeviceToken` remains in use for QR registration.

Application remote-notification, foreground notification and notification-tap
callbacks forward string-valued MFA payload fields to:

```swift
let sessions = try await sdk.handlePushNotification(payload: fields)
```

Forward the `url` field unchanged. Legacy bare hostnames become
`https://<host>/pad`. Scheme-less or HTTPS MAC service URLs retain their
`/mac/MobileAppCommunicator.svc` path (with optional trailing slash) and encoded
routing query. Only nonempty, nonduplicate `su` and `ignored` query fields are
accepted on that route. The same typed policy is enforced by the request builder
and transport. HTTPS, trusted hosts, port 443/default, no user information or
fragment, bounded URL size and redirect rejection remain enforced. Activation
URLs still reject query strings; arbitrary notification paths are not accepted.

Validation pushes are handled without displaying sign-in UI. Authentication
pushes return SDK-associated sessions and are queued for presentation on the
active Accounts screen. Pushes arriving during a pull-to-refresh are retained,
and the same session returned by both paths is presented only once.
The user opens the notification and approves/denies
inside the app; the sample does not add lock-screen approval actions.

Background delivery depends on iOS and is not guaranteed, particularly after
force-quit. Background callback work is bounded; opening the app and refreshing
is the recovery path when delivery is unavailable.

## Service operations

| Flow | Operations |
|---|---|
| Enrollment | `ActivateNew`, validation push, `PhoneAppValidateDeviceToken`, `ConfirmActivation` |
| Token rotation (V2 only) | `PhoneAppStartDeviceTokenChangeV2Request`, validation push, `PhoneAppCompleteDeviceTokenChangeV2Request` |
| Routing | `PhoneAppGetEndpoints` for known replication scopes |
| Pending authentication | `PhoneAppCheckForAuthentication`, `PhoneAppAuthentication` |
| Number matching | `PhoneAppPinValidation` |
| Ordinary approval / denial | `PhoneAppAuthenticationResult` |

For accounts with a known replication scope, discovery selects the matching
endpoint or the response's `defaultUrl` when no mapping matches. Only the
selected destination is URL-validated; unrelated cloud mappings cannot block
refresh. Every selected destination still requires a trusted HTTPS service URL.
Before a scope or cached map is available, the account's existing endpoint is used.
Polling result `101` is treated as no pending request for that account and polling
continues for other accounts. Other service failures remain errors, rather than
being displayed as an empty inbox.

QR enrollment uses the required `ActivateNew` username as the account identity.
A successful device-token validation may contain an empty `<username/>`; a
nonempty validation username must match the activation username case-insensitively.
A missing username element remains invalid. Confirmation still runs only after
activation and validation succeed; an empty validation username does not bypass
the remaining enrollment checks.

Approval sends the entered number to the service. No correct-answer hint or
local number comparison is used. The session's `requiresNumberMatching` flag controls whether
the sample asks for a number; ordinary approval submits an empty number.
Both push and refresh read account identity, routing, number-matching requirements
and policies from the authentication response's nested `phoneAppInfo` element.
The response-level GUID and delivery proof remain separate; the nested identity
must match a registered account before a session can be presented.
Unsupported PIN, app-lock, location or credential-policy
requirements fail closed instead of being bypassed.

Nonempty `userCredentialPolicy` is decoded as a bounded Base64/protobuf subset,
not rejected solely for being present. Supported phone policies use PUSH or ANY
mode, an enabled policy state, and disabled app-lock/application-context/location-context
requirements. Number matching is required if either the challenge or a supported
phone/companion policy requires it; the policy never disables a challenge requirement.
Companion policies support only explicit number-matching and availability fields.
Platform approval-PIN enforcement remains unsupported.
Malformed/oversized payloads, duplicate or unknown fields, unsupported policy
sections (including metadata), unknown enum values and unresolved DEFAULT settings
for required behavior block approval with `unsupportedPolicy`. Denial remains
available. This is intentionally not a full Authenticator policy implementation;
no policy payloads are logged or copied into fixtures.

## Recovery and current limitations

- Successful registrations survive relaunch. A pending enrollment with a saved
  activation response can be resumed by submitting the same activation input.
  If sending activation or confirmation had an ambiguous outcome, the SDK
  reports `outcomeUnknown` rather than blindly replaying it. Reconcile enrollment
  on the server before requesting a fresh code.
  An explicit false SOAP result instead returns `serviceFailure` with the bounded
  numeric SAS error code, or `Rejected` if no safe numeric code is available.
  Descriptions and response bodies are not exposed. A rejected activation clears
  its pending attempt; a rejected confirmation retains the saved activation and
  validation so the same input can retry confirmation without activating again.
  Retrying is caller-initiated and does not guarantee the service will accept it.
- Token reconciliation retains account-level progress; retry via the next APNs
  callback/foreground refresh. There is no autonomous background retry scheduler.
  Enrollment and token reconciliation cannot overlap, including during endpoint
  discovery. A superseding token is retained for a later reconciliation attempt.
- Submitted session IDs are retained to prevent replay after restart. A network
  failure after submitting a decision is not treated as permission to send the
  opposite decision. Check the browser/service outcome and start a new request
  when needed.
  A Keychain failure before submission leaves the session retryable; no decision
  request is sent until replay protection has been persisted.
- Endpoint checks currently support the implemented Microsoft commercial,
  US and China host suffixes and legacy PhoneFactor `/pad` endpoints.
  Other cloud domains fail explicitly; do not weaken validation to make an
  unsupported environment work.
- Policy compatibility, endpoint-map freshness, platform compilation and
  real-service behavior still require validation. No claim of Authenticator
  feature parity is made.
- No signed-in registration, MSA, deregistration, device migration or
  Authenticator-store migration is implemented.

## Tests and local validation

SDK tests belong to `MSAL/test/unit/mfa/`. Sample tests belong to this project's
`Tests/` directory and inject synthetic service results/system callbacks. They
must not use real services or the developer's Keychain. Sample files remain out
of SDK target membership.

The user runs builds/tests in Xcode. Agent validation is limited to static source,
project, plist, XML and diff inspection; no local builds, test execution,
compilers, linters, simulators, app launches or dependency restores.

Before considering E2E complete:

1. Build the SDK and sample and run both test targets.
2. Verify signed app identity, APNs environment and notification permission on an
   authorized dedicated device.
3. Enroll with a fresh QR, then separately with fresh manual activation data.
   Verify server confirmation, not just an Accounts row.
4. Relaunch and verify accounts remain usable.
5. Trigger real sign-ins, receive pushes in foreground/background, approve with
   number matching and deny a separate request. Verify the browser outcome.
6. Exercise wrong number, expired request, offline failure, duplicate deliveries,
   pull-to-refresh, cancellation and token synchronization recovery.

CocoaPods' existing `native-auth` source glob includes these sources. The generated
SPM manifest still references the released binary, not this local implementation;
it is not edited here. No dependency installation or binary release is included.
