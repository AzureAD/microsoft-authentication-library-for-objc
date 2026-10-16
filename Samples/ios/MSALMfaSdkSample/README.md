# MFA SDK Phase 1 sample

**Experimental and mock-only. Nothing is enrolled and no sign-in is authorized.**
This sample uses the public Swift interface of the headless `MSALMfaSdk` framework.
It is not part of the shipping MSAL authentication API.

## Targets and workspace

The existing `MSAL/MSAL.xcodeproj` owns exactly two new targets and shared schemes:

| Target / scheme | Product | Purpose |
| --- | --- | --- |
| `MSALMfaSdk` | `MSALMfaSdk.framework` | Headless Swift mock API |
| `MSALMfaSdkSample` | `MSALMfaSdkSample.app` | SwiftUI demonstration |

Use the existing `MSAL.xcworkspace`, not a separate sample project. Both targets
use Swift 5 language mode and iOS 17+, matching this checkout's iOS baseline.
The sample depends on, links, and embeds the local SDK product. No package or
Authenticator dependency is required by either new target.

`MSAL_MFA_POC` is a compile-time opt-in, enabled only by the two targets'
`msal__mfa_poc__*.xcconfig` files in Debug and Release. The source is absent from
the existing shipping MSAL targets and CocoaPods source patterns. The generated
SPM manifest, existing MSAL umbrella/module map, and existing sample projects are
unchanged. The API is exported by the Swift module `MSALMfaSdk`, not `MSAL.h`.
There is no broker flight manager or production rollout in this phase.

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
| `MfaSdkManager` | `MSALMfaSdkManager` |
| `MfaSdkRegistrationParameters` | `MSALMfaSdkRegistrationParameters` |
| `MfaSdkRegistrationResult` | `MSALMfaSdkRegistrationResult` |
| `MfaSdkAuthSession` | `MSALMfaSdkAuthSession` |
| `MfaSdkPendingAuthSessionCompletionResult` | `MSALMfaSdkPendingAuthSessionCompletionResult` |

`MSAL` prefixes the existing MFA semantic names. These are intentionally reduced
POC shapes, not source-compatible replacements. In particular, registration
parameters carry QR text instead of the original account/device-token sign-in
registration fields. `activateMfaAccount` follows the QR activation operation's
name in Authenticator's `AddAccountFlow`; `approve`/`deny` are headless POC
operations, not migrated UI or protocol logic.

## Validation status and cloud handoff

**Build, test, and app-run acceptance is pending. No local build, test, compiler,
simulator, app, or dependency-restoration command was run.**

Four async XCTest cases in `MSAL/test/unit/mfa/MSALMfaSdkTests.swift` cover
deterministic registration, fixed challenge shape, ignored number input, and
repeatable approve/deny decisions. They use public imports, not test-only API.
The SDK scheme selects this class in the existing `MSAL iOS Unit Tests` target,
avoiding a third new target. Test membership, linking, embedding, and dependency
are iOS-filtered so the existing visionOS graph does not gain an iOS-only SDK.

An authorized cloud macOS/Xcode environment still needs to build both schemes
from `MSAL.xcworkspace` in Debug and Release, run the selected tests, and launch
the sample to exercise the sequence above. Retain build logs, test results, and
app-run evidence; static project inspection is not proof of compilation or UI
behavior.

The existing project-level xcconfigs reference the pinned IdentityCore submodule
(`1f0703a9cb4bfe26441fd3684d69cb6e8528304a`), which is uninitialized in this
worktree. Cloud checkout must include it for the existing workspace configuration
and unit-test host; neither new target links it. Existing CI does not select the
new sample scheme. Source transfer and a focused cloud job require approval;
no push, PR, credentials, or infrastructure changes are included here.
