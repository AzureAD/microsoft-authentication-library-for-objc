# MSAL MFA sample

**Experimental and mock-only. Nothing is enrolled and no sign-in is authorized.**
This sample calls the headless public Swift MFA interface through `import MSAL`.
The interface is compiled into normal applicable MSAL native-auth builds, but
its presence does not mean real MFA is available or production-ready.

## Targets and workspace

The existing `MSAL/MSAL.xcodeproj` owns the framework and sample:

| Target / scheme | Product | Purpose |
| --- | --- | --- |
| `MSAL (iOS Framework)` | `MSAL.framework` | Existing MSAL framework, including the mock MFA API |
| `MSALMfaSdkSample` | `MSALMfaSdkSample.app` | SwiftUI demonstration |

Use `MSAL.xcworkspace`, not a separate sample project. The sample is the only
new target and shared scheme. It uses Swift 5 language mode and iOS 17+, and
depends on, links, and embeds the existing local MSAL iOS framework.
Its configuration is `MSAL/xcconfig/msal__mfa_sample__ios.xcconfig`.

Public source lives in
`MSAL/src/native_auth/public/mfa/MSALNativeAuthMfaSdk.swift`. It has the same
iOS/macOS framework target membership as existing native-auth public Swift
sources, without an opt-in compilation condition. The existing static-library
targets contain no native-auth Swift sources and remain unchanged.

The existing CocoaPods `native-auth` source glob includes this API. The default
`app-lib` subspec is not expanded. The generated binary SPM manifest is unchanged;
it still references the released binary, not this branch's new source. The Swift
API needs no Objective-C umbrella header or module-map addition.
No new dependency is introduced. Future real authentication behavior still
requires the repository's feature-gating and release process.

## Demonstration

On an **approved cloud-hosted** iOS simulator or device:

1. Use the default synthetic QR text and select **Activate mock registration**.
   The receipt is always `mock-registration`, not a real enrollment.
2. Select **Load mock challenge**. The SDK returns `mock-session`, with the
   simulated sign-in number `42`.
3. Enter a number and select **Approve mock challenge**, or select **Deny mock
   challenge** without entering a number. Every status explicitly says `MOCK`.
4. Load the challenge again to demonstrate the other decision.

The UI clears QR input after activation and clears the session after a decision.
These are sample presentation states only. The SDK has no state and allows
repeated or out-of-order calls. Number input is passed to the public API but
intentionally ignored: even an incorrect number returns a **mock** approval.
Empty/malformed QR input also returns a mock receipt through the SDK; the UI
only disables its activation button for an empty field.

No camera, APNs registration, account sign-in, token acquisition, SAS/network
request, crypto, Keychain, telemetry, or persistent storage is used. Use synthetic
input only. Do not use this code as authentication or authorization enforcement.
MSA versus AAD protocol support remains undecided.

## Source provenance and names

The implementation started from MSAL `dev` at
`ddc2e0501588da593fbd1d5fdfa9cf3894af72a2`. Authenticator `dev` at
`a95e65be496ac254985494d155aca179e3ec690a` was inspected read-only for semantic
names and interface context. Both revisions were verified against remote `dev`.
No production implementation was copied.

| Authenticator type | Phase 1 public Swift type |
| --- | --- |
| `MfaSdkManager` | `MSALNativeAuthMfaSdkManager` |
| `MfaSdkRegistrationParameters` | `MSALNativeAuthMfaSdkRegistrationParameters` |
| `MfaSdkRegistrationResult` | `MSALNativeAuthMfaSdkRegistrationResult` |
| `MfaSdkAuthSession` | `MSALNativeAuthMfaSdkAuthSession` |
| `MfaSdkPendingAuthSessionCompletionResult` | `MSALNativeAuthMfaSdkPendingAuthSessionCompletionResult` |

`MSALNativeAuth` prefixes the full existing MFA semantic names. These are
intentionally reduced mock interfaces, not source-compatible replacements. Registration
parameters carry QR text instead of the original account/device-token sign-in
registration fields. `activateMfaAccount` follows the QR activation operation's
name in Authenticator's `AddAccountFlow`; `approve`/`deny` are headless mock
operations, not migrated UI or protocol logic.

## Validation status and cloud handoff

**Build, test, and app-run acceptance requires cloud evidence for the current
revision. No local build, test, compiler, simulator, app, or dependency-restoration
command was run.**

Four async XCTest cases in `MSAL/test/unit/mfa/MSALNativeAuthMfaSdkTests.swift` cover
deterministic registration, fixed challenge shape, ignored number input, and
repeatable approve/deny decisions. They import public `MSAL`, not test-only API,
and remain iOS-filtered members of `MSAL iOS Unit Tests`, using its existing MSAL
linkage and test host. The sample scheme selects this class for cloud validation;
the normal iOS framework scheme also includes the existing unit-test target.

Existing automatic cloud CI covers the MSAL iOS/macOS frameworks, unit tests,
native-auth E2E, and SPM integration. Check results on the current PR head; an
earlier revision's success is not evidence for this one. Existing jobs do not
select the custom sample scheme or exercise its UI. An approved cloud macOS/Xcode
job must still build the sample in Debug and Release and launch it to exercise
the sequence above. Do not add infrastructure or run local validation as a
substitute. Static inspection is not proof of compilation or runtime behavior.

The existing project-level xcconfigs reference the pinned IdentityCore submodule
(`1f0703a9cb4bfe26441fd3684d69cb6e8528304a`), which is uninitialized in this
worktree. Cloud checkout must include it for MSAL and the existing test host.
No Authenticator checkout, private Authenticator dependency, or new distribution
package is required.
