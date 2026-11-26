# MSAL MFA sample - experimental phase three

**Source implementation only: builds, tests and real-service workflows are unverified.**
This phase replaces the phase-two SAS profile with the supplied EEID reference
(document contents v0.6, November 3, 2026) and the final public MFA API at
`sedemche/eeid_mfa_push` revision `4d5f9d1603040cc0432669c951fbc1bea509ba96`.
It is not a production authentication implementation or a claim of successful
enrollment, APNs delivery, decisions, rotation, or completed hosted sign-in.

## Workspace, app identity and prerequisites

Open this folder's `MSALMfaSdkSample.xcworkspace` for the sample; use the root
`MSAL.xcworkspace` for SDK development, never the framework project directly.
The sample targets iOS 17+ and uses supported hardware for VisionKit.

The bundle ID remains **`com.microsoft.azureauthenticator`** as selected for this
test setup. It is not proof of app identity and does not grant signing rights,
tenant approval or access to an APNs provider. Use authorized provisioning and a
dedicated test device. Installing this identity can replace Authenticator:
do not install over an app holding real credentials. No signing profile, APNs
certificate, private key, or first-party provider credential is included.

`MSAL_MFA_APNS_ENVIRONMENT` must agree with the signed `aps-environment`:
Debug defaults to `development`, Release to `production`. Raw token bytes and the
explicit environment go to the SDK; backend approval of the effective provider
and environment is independently required. The retained sample marketing version
`6.8.56` is compatibility metadata, not the SDK release version or an integrity claim.

The SDK obtains `BundleId` from the actual host, sends it exactly once in
ActivateNew, and omits `PackageName` and `authenticatorFlavor`. Tenant, user and
customer-app scope come from the service activation context, not an SDK override.
DeviceName remains the `MSIDDeviceId.deviceHardwareType()` hardware identifier.
ConfirmActivation sends the confirmation code, not a replacement app identity.
Rotation sends the registration's stored bundle ID as `appPackageName` and cannot
rebind the registration to another host app.

## Fresh registration and isolated storage

Phase three is **EEID-only**. The SDK uses Keychain service
`com.microsoft.msal.experimental.mfa.eeid.v3`, with device-only, after-first-unlock
accessibility. It never reads, changes or deletes phase-two service
`com.microsoft.msal.experimental.mfa.v2`. Old rows will not appear; register afresh
with new activation material. No Authenticator shared storage or migration is used.

Confirmed registrations, APNs state and replay protection remain durable.
Pending enrollment and provisional provisioning are held only in memory.
Validation handling is armed before ActivateNew because the validation push may
arrive while that call is waiting. ValidateDeviceToken must return a real nonempty
response; an empty/default/status-only response does not validate a token.
An empty validation username is accepted only when the required activation
username is present; a nonempty validation username must match it.

Only successful confirmation (true, error code zero, nonempty method ID) followed
by a successful local save returns a registration. Cancellation or response/save
loss may leave a server-side registration. There is no durable enrollment
resumption, automatic mutation retry or compensating deletion. Reusing activation
material is not a recovery guarantee; reconcile before requesting a fresh code.

The Accounts, Scan QR code and Add account screens retain their existing roles.
Manual entry is an activation URL/code, not a TOTP secret. QR input accepts the
`activate_account` container and the HTTPS
`login.microsoftonline.com/authenticatorApp/activateAccount?accountType=mfa`
container; their embedded destination must pass the EEID route policy.

## Routes and wire behavior

Use the actual activation context. These test-ring examples contain a placeholder,
not reusable activation material:

```text
https://mobileappcommunicator.auth.microsoft.com/eeid/mac/MobileAppCommunicator.svc?ts=true&su=SASPUBWUS3AZ1FD000Test2
https://mobileappcommunicator.auth.microsoft.com/eeid/mac/MobileAppCommunicator.svc/<activationEntropy>/SASPUBWUS3AZ1FD000Test2/PfPaWs.asmx?ts=true&su=SASPUBWUS3AZ1FD000Test2
```

SOAP activation and PFP MAC endpoints have separate path policies. Both preserve
validated, nonduplicate `ts`/`su` query parameters. HTTPS, trusted Microsoft host
suffixes, default/443 ports, no credentials/fragments, bounded bodies/URLs and
blocked HTTP redirects remain required. Graph has its own unchanged host/path
policy. Legacy `/pad`, `/mac`, bare-host fallback and GetEndpoints are not used.

HTTP status/media type, SOAP Fault or PFP status, operation outcome and required
success fields are checked independently. Duplicate, missing, unknown or malformed
results never mean success. SOAP true with a nonzero error code fails.

| Flow | Mobile operations |
|---|---|
| Enrollment | ActivateNew, ValidateDeviceToken, ConfirmActivation |
| Discovery/context | CheckForAuthentication, PhoneAppAuthenticationRequest |
| Approval | PhoneAppPinValidation with `authenticate=no` |
| Denial | PhoneAppAuthenticationResult with `authenticationResult=2` |
| Rotation | StartDeviceTokenChangeV2, CompleteDeviceTokenChangeV2 |

All nine operations use the small existing SOAP/PFP transport and crypto helpers.
No ESTS, SAPAD, gRPC, NGC, MSA, broker/private framework or backend implementation
is added. SOAPAction and MAC dispatch headers retain the existing bindings;
their enforcement by the deployed workflow still needs confirmation.

## Final public call sequence

Keep one manager for enrollment, token callbacks, notifications and decisions:

```swift
let sdk = MSALNativeAuthMFAManager()
try await sdk.updatePushRegistration(deviceToken: token, apnsEnvironment: environment)
let input = MSALNativeAuthMFARegistrationParameters(qrCode: scannedText)
// Or MSALNativeAuthMFARegistrationParameters(activationCode: enteredCode, activationURL: enteredURL)
let registration = try await sdk.registerAuthMethod(registrationParameters: input)
let accounts = try await sdk.registeredAuthMethods()

let sessions = try await sdk.handlePushNotification(payload: notification.request.content.userInfo)
// Alternatively: try await sdk.pullPendingNotifications()
// Only after an explicit user action, using the original manager-issued session:
let decision = try await sdk.respond(authSession: session, action: .approve(number: enteredNumber))
// Or .deny, without a number.
switch decision {
case .approved: break // Service acknowledged approval; hosted sign-in is still separate.
case .denied: break   // Service acknowledged denial.
}
```

Replace the old `approve`/`deny` methods and `wasApproved` wrapper with
`respond(authSession:action:)` and `.approved`/`.denied`. `registrationId` on each
session links to a registered method; neither it nor `guid` reconstructs a session.
Always retain and pass the original object.

Forward Apple's `[AnyHashable: Any]` userInfo unchanged in launch, background,
foreground and tap callbacks. The SDK extracts recognized fields, supports the
existing nested `data` container, ignores unrelated `aps` content and never
stringifies arbitrary values. Taps or delivery alone never approve. The sample
owns main-actor presentation and exactly-once platform completion callbacks;
background work has a 25-second deadline. iOS delivery is not guaranteed.

Push and pull retrieve authoritative nested `phoneAppInfo`, bind method/tenant/user
to local state, and retain the server challenge counter. Context retrieval requests
`needDosPreventer=yes` and persists the required nonempty fresh polling value.
Pull failure returns no
partial list. The supported policy subset requires number matching and rejects
app-lock, location/context collection, PIN and unsupported integrity requirements.
The minimal policy `EgIoAg==` is supported; omitted legacy display fields are not
required. Unknown policy fields/enums fail during retrieval, never return a deny-only
session. Optional appState is omitted rather than copying illustrative evidence or
claiming root detection. No matching-number answer is exposed.

EEID has no ordinary approval path: nil, empty or malformed approval input fails
before transmission. The SDK accepts 1-10 ASCII digits; the sample trims surrounding
whitespace and preserves leading zeros. Denial never requires a number. Both use
the authoritative counter and explicit interactive user action, with no claim that
app lock was used.

Replay protection is saved before submission. A pre-submit invalid code can be
corrected on the same session; wrong-number result 7 does **not** establish safe
continuation and remains consumed. Result 5 establishes an unusable challenge.
Transport, policy or backend failure throws, never returns denial as fallback.
Neither decision acknowledgment is token issuance or ESTS EndAuthentication success.

## Errors, token rotation and deletion

`MSALNativeAuthMFAError` is standalone, not a Native Auth error subclass. Exactly one
of `isPushTokenMissing`, `isRegistrationNotFound`, `isInvalidChallenge`,
`isInvalidCode`, `isUserSignedInWithMismatchedAccount` and `isGeneralError` is true.
It carries sanitized diagnostics and an operation correlation UUID. Do not parse
text or rely on the removed Native Auth/browser flags or numeric error array.
Swift cancellation propagates separately. Provider errors propagate unchanged,
without MFA wrapping, classification or logging; hosts handle their own error types.

V2 rotation is sequential per account. It arms validation before Start, uses the
fresh callback counter's full HMAC-SHA1 hex proof (not a truncated OTP), and requires
overall success plus exactly one matching per-account Success. Missing, duplicate,
foreign and unknown account results fail. Confirmed accounts keep their new tokens;
unconfirmed accounts retain their previous activated tokens. A matching completion
received after the initiating update was cancelled still saves its confirmed token,
provided the registration has not been replaced or deleted; the cancelled attempt
does not resume. Unresolved submitted
updates remain replay-blocked across restart. New APNs callbacks can update local
token state but do not authorize replay of an uncertain mutation.

Graph deletion remains separate:
`DELETE https://graph.microsoft.com/v1.0/users/{objectId}/authentication/microsoftAuthenticatorMethods/{registrationId}`.
The shared `MSALTokenProvider` receives account/authority, delegated
`UserAuthenticationMethod.ReadWrite` scope and essential `ngcmfa` claims.
It must honor all requirements and return actual authenticated metadata, never
copy expected identity or decode an access token to infer it.

The existing sample OAuth client setting and
`msauth.com.microsoft.azureauthenticator://auth` redirect remain unchanged.
They grant no signing rights or Graph consent. Independent apps require their own
registered client/redirect and consent. The sample disables broker dispatch,
uses its private OAuth Keychain group and presents in-app browser sign-in.
Number matching remains available over that browser, including the existing
Hide for 3 seconds action; it never fills the number automatically.

Token acquisition does not block retrieval or decisions. A submitting target
decision blocks DELETE, and submitting DELETE blocks that registration's decisions.
204/404 permits local removal; only the selected method is removed.
After confirmed remote success plus save failure, retry on the same manager
finishes local cleanup without another provider/Graph call. Uncertain remote
deletion requires reconciliation and keeps target decisions blocked. A definite
HTTP 401/403 rejection releases the new submission's block once that state is saved,
so MFA can obtain a stronger deletion token. It does not clear uncertainty from an
earlier attempt. Transport failures and other ambiguous outcomes remain blocked.
Neither this operation nor sample UI deletes the OAuth account cache.

## Exact unresolved integration gaps

The ring endpoints were reported deployed; **the executing ring revision and
behavior have not been verified**. Read-only comparison with SAS main
`fa397f5ced00ac51d32a1f721c96f57e2ba312b8` found:

- Its EEID controller validates contracts only and can return
  `eeidContractValidation` with `workflowExecuted=false`, optionally accompanied
  by `X-MS-EEID-Validation-Only:true`. The SDK rejects this, not enrollment/decision success.
- Its PFP boolean codec requires `async="no"` and `synthetic="no"`, unlike the
  document's illustrative `0`. This implementation uses the receiver-confirmed form.
- Its V2 validator requires `customerAppId`, but the documented activation response
  does not supply it. The implementation retains the documented V2 fields and does
  not invent a public override or infer customerAppId from bundle/OAuth client ID.
  This remains a concrete V2 interoperability gap if that validator is deployed.
- Discovery 101 is InvalidDevice and legacy code conflates no pending record with
  lookup failure. No confirmed no-work marker is available. It throws rather than
  returning an invented empty inbox. No local accounts still returns an empty list.
- The reference's discovery response has no GUID; the retained proof-based context
  lookup therefore sends a blank GUID, as supported by the legacy handler.
  The inspected EEID validator instead requires a nonempty GUID. Pull bootstrap
  needs an agreed GUID-bearing discovery response or approved proof-lookup profile;
  the SDK does not manufacture a challenge identifier.
- Installation/authentication headers, exact deployed proof enforcement, safe
  mutation recovery and approved bundle/provider/environment configuration need
  workflow-owner evidence. Routing headers and bundle ID are not credentials.

Resolve these with a sanitized executing-workflow response/schema and deployment
revision, not live enrollment/approval experiments without authorization.

## Validation status

Focused synthetic regressions are authored in `MSAL/test/unit/mfa/` and the sample
`Tests/` folder, replacing obsolete legacy routing, durable enrollment and error
expectations while retaining Graph coverage. They do not establish live success.
Local work is restricted to source/diff/API, XML/plist and project-membership
inspection: no builds, tests, compilers, linters, simulators, apps or dependency
restores were run.

Executable validation needs an authorized Apple-toolchain environment and explicit
permission to publish the currently uncommitted source. No cloud run or publication
is implied. Real-device enrollment, delivery, number matching, denial, rotation and
hosted completion are separate authorized validations.

CocoaPods' native-auth glob includes these sources. The generated SPM manifest
still points to the released binary; it is not changed. No new dependency or
binary distribution is included.
