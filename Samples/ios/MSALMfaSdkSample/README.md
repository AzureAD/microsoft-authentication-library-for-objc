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

For manual local validation, open `MSAL.xcworkspace` in Xcode, select
`MSALMfaSdkSample`, and run it on an iOS 17+ simulator or device:

1. **Accounts:** the initial list is empty. Select the floating QR button.
2. **Scan QR code:** the dark viewfinder is simulated, not a camera preview.
   Select **Simulate scan** to call MSAL's mock activation API and return to
   Accounts with one labeled mock registration.
3. To use the other path, open the scanner again and select **Enter code manually**.
   On **Add account**, enter a synthetic account name and secret key. **Finish**
   is disabled until both fields contain non-whitespace text.
4. Select **Finish** to return to Accounts with a second mock registration.
   Back navigation cancels input without adding a registration.
5. Pull down on **Accounts**, with or without registrations, to show
   **Are you trying to sign in?** The native alert uses the synthetic identity
   `Demo account` / `demo@example.com` and includes a mock-only notice.
   **Yes** starts disabled and accepts a nonnegative whole number using digits
   only (within the platform's integer range). It calls the mock approval API
   with the entered number; **No, it's not me** calls mock denial without a number.
   The inline outcome always identifies itself as mock.

The three screens use blue navigation bars, identity rows, a floating QR action,
a dark framed scanner illustration, and a grouped manual form. The sign-in alert
is presented over Accounts, not a fourth screen. Existing challenge SDK APIs and
their four mock contract tests are unchanged.

**The sign-in number is ignored by the SDK.** This is not number verification:
any valid numeric input, including a number other than the mock challenge's `42`,
produces a mock approval. No real sign-in is authorized. The number is not logged
or persisted and is cleared when the popup closes. Repeated refreshes or taps
cannot overlap an active challenge flow. Navigation away cancels presentation;
late results cannot reopen the popup or overwrite a newer operation. A later
pull-to-refresh can show another mock request because the SDK is stateless.
Accounts owns a native `UIRefreshControl` and explicitly hides the indicator and
ends refreshing before presenting the sign-in popup, without waiting for a
decision. The pulled-down list also returns to its normal top position before
the popup appears. A new refresh restores indicator visibility while loading.
Denial, approval, and navigation cancellation leave
the indicator stopped; the indicator does not depend on SwiftUI's refresh-task
cleanup while a UIKit alert is being presented.
The model also owns the request task separately from its caller,
so cancellation of the caller does not discard a loaded challenge.
Explicit navigation cancellation still cancels the owned task and invalidates
its result; overlapping refresh gestures share the same pending request.

Rows are sample-only in-memory display state and reset on app restart. Their
local unique IDs are distinct from the SDK's constant `mock-registration` receipt.
The SDK remains stateless: the list does not represent real enrolled accounts.

**The manual secret is ignored and discarded.** It is not a QR payload, is not
validated as an OTP/TOTP key, and is never sent to MSAL, logged, or persisted.
Both paths submit the same synthetic QR fixture to the existing QR-only mock
activation API. Manual entry adds no new public SDK API. Only the display name
and mock entry-source metadata are retained in the list. Use synthetic names
and keys, not actual account data. Input is cleared on finish or cancellation.

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

## Local validation handoff

**The user will validate this checkout locally in Xcode before publication.**
Agent verification is limited to static source, project, scheme, and diff
inspection; agents must not run builds, tests, compilers, linters, simulators,
apps, or dependency restores. Do not commit, push, change CI, or dispatch CI
as part of this handoff.

Four async XCTest cases in `MSAL/test/unit/mfa/MSALNativeAuthMfaSdkTests.swift` cover
deterministic registration, fixed challenge shape, ignored number input, and
repeatable approve/deny decisions. They import public `MSAL`, not test-only API,
and remain iOS-filtered members of `MSAL iOS Unit Tests`, using its existing MSAL
linkage and test host. The sample scheme selects this class for validation;
the normal iOS framework scheme also includes the existing unit-test target.

`MSALMfaSampleModelTests` additionally covers empty state, whitespace validation,
scan/manual additions, unique row identities, synthetic-only SDK input,
retained row fields, duplicate submission prevention, and cancellation of delayed
results. Challenge coverage includes integer validation, refresh on an empty list,
no-pending results, approval/denial routing, ignored-number semantics, duplicate
refresh/response prevention, dismissal, canceled tasks, stale completion isolation,
unexpected response handling, and cancellation of SwiftUI's refresh task without
losing the prompt. Explicit navigation still cancels the owned request. The sample
model is compiled into the existing iOS unit-test target; neither the model nor UI
is exported by the MSAL framework.
The sample scheme also selects these tests. A hosted SwiftUI regression test
mounts the actual Accounts screen and triggers its native refresh control,
checks numeric button enablement, denies and then approves successive prompts,
and checks that the indicator stops before presentation and stays stopped after
each decision. A delayed-request test also covers ending the indicator on
cancellation. The bridge observes challenge changes directly; navigation away
from Accounts cancels pending work.
The sample views are iOS-only members of the existing test
target so this test exercises the same presenter as the app. Alert dismissal uses
the existing action/model flow and UIKit completion callbacks, not a replacement
presentation-controller delegate (which UIKit prohibits for alerts).
No local tests are run.

In Xcode, manually build the sample in Debug and Release, run the selected tests,
and exercise the sequence above, including pull-to-refresh on empty and populated
lists, alert presentation/dismissal, disabled/enabled Yes, both decisions, back
navigation, keyboard handling, Dynamic Type, and VoiceOver. Previous framework/test
CI results do not establish that the sample UI compiles or runs. Static inspection
is not proof of compilation or runtime behavior.

The existing project-level xcconfigs reference the pinned IdentityCore submodule
(`1f0703a9cb4bfe26441fd3684d69cb6e8528304a`). It must be available in the checkout
for MSAL and the existing test host; agents must not restore it during this handoff.
No Authenticator checkout, private Authenticator dependency, or new distribution
package is required.
