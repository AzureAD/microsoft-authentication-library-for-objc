# Native Auth V2 — Cross-Platform Public API Design Contract

> Audience: JavaScript and Android SDK teams implementing an equivalent **Native Auth V2
> (server-driven)** public API.
> Source of truth: the iOS/macOS implementation (`MSAL/src/native_auth/public/**`). Names below use
> the iOS type names as the canonical reference; adapt them to each platform's idioms (see
> [§9 Platform-mapping notes](#9-platform-mapping-notes)).

---

## 1. Overview & design principles

V2 is a **server-driven** authentication model: the SDK talks to the server, and at each step the
server decides what the app must do next. The app does not orchestrate the flow — it reacts to
callbacks and continues by acting on the object the SDK hands it.

Core design decisions (these are the contract — keep them across platforms):

1. **A base delegate plus one per-state delegate protocol.** The base `MSALNativeAuthFlowDelegate`
   carries only the two required terminal callbacks and is used for **all three flows** (`signIn`,
   `signUp`, `resetPassword`). Each intermediate state has its own protocol (e.g.
   `MSALNativeAuthCodeRequiredDelegate`) that **extends the base** and adds that state's single
   required callback. Conforming to a per-state protocol is opt-in (the app conforms only to the
   states it handles), but once it conforms the callback is compiler-required. (V1 had
   a different delegate per step.)
2. **One strongly-typed state per step.** Each callback delivers a concrete state object that
   carries the step's data **and exposes only the continuation method(s) valid for that step**. The
   app never downcasts a generic state and cannot call an invalid continuation.
3. **One unified error type** — `MSALNativeAuthFlowError` (inherits `MSALNativeAuthError`) — is the
   only error shape surfaced by the flow.
4. **The two terminal callbacks (`onFlowCompleted`, `onFlowError`) are required on the base
   `MSALNativeAuthFlowDelegate`; each of the 9 intermediate state callbacks is required within its own
   per-state delegate protocol, but conforming to that protocol is opt-in.** The app must assume the
   **server may invoke any callback in any flow** (see §3), so it should conform to every state its
   flows can reach. If the server drives the flow to a state whose delegate protocol the app does not
   conform to, the SDK calls `onFlowError` with error type `notImplemented`. There is no compile-time
   guarantee that, e.g., sign-up won't ask for MFA.
5. **All callbacks are delivered on the main thread** (iOS: main actor). Apps may update UI directly
   inside a callback.
6. **`account.getAccessToken` is unchanged from V1** (see §7).

---

## 2. Entry points

Exposed on the public client application. Each takes a flow-specific parameters object plus the
**base** delegate (`MSALNativeAuthFlowDelegate`); the app's delegate object additionally conforms to
the per-state delegate protocols it wants to handle:

| Method | Parameters type | Delegate |
|---|---|---|
| `signInV2(parameters:delegate:)` | `MSALNativeAuthSignInParameters` | `MSALNativeAuthFlowDelegate` |
| `signUpV2(parameters:delegate:)` | `MSALNativeAuthSignUpParameters` | `MSALNativeAuthFlowDelegate` |
| `resetPasswordV2(parameters:delegate:)` | `MSALNativeAuthResetPasswordParameters` | `MSALNativeAuthFlowDelegate` |

Parameter objects (constructed with `username`; the rest are optional/settable):

| Parameters type | Fields |
|---|---|
| Sign In | `username`, `password?`, `scopes?`, `claimsRequest?`, `correlationId?` |
| Sign Up | `username`, `password?`, `attributes?` (`[String: Any]`), `scopes?`, `correlationId?` |
| Reset Password | `username`, `scopes?`, `correlationId?` |

The call is fire-and-forget: results/errors come back through the delegate.

---

## 3. Delegates — base `MSALNativeAuthFlowDelegate` + per-state protocols

**The two terminal callbacks (`onFlowCompleted`, `onFlowError`) are required and declared on the base
`MSALNativeAuthFlowDelegate`; each of the 9 intermediate state callbacks is required within its own
per-state delegate protocol that extends the base — but conforming to that protocol is opt-in.** The
server may drive to any state in any of the three flows, so an app should conform to every state
protocol its flows can reach; if the server reaches a state whose protocol the app does not conform
to, the SDK calls `onFlowError` with type `notImplemented`. All are invoked on the main
thread. Each state callback hands back a concrete state (see §4).

| Callback | Declared on (protocol) | Meaning | Continue by calling (on the state) |
|---|---|---|---|
| `onCodeRequired(state:)` | `MSALNativeAuthCodeRequiredDelegate` (required) | Verify a one-time code (OTP) | `submitCode(_:delegate:)` / `resendCode(delegate:)` |
| `onPasswordRequired(state:)` | `MSALNativeAuthPasswordRequiredDelegate` (required) | Enter existing password | `submitPassword(_:delegate:)` |
| `onNewPasswordRequired(state:)` | `MSALNativeAuthNewPasswordRequiredDelegate` (required) | Set a new password (SSPR) | `submitNewPassword(_:delegate:)` |
| `onAttributesRequired(state:)` | `MSALNativeAuthAttributesRequiredDelegate` (required) | Provide required user attributes | `submitAttributes(_:delegate:)` |
| `onAttributesInvalid(state:)` | `MSALNativeAuthAttributesInvalidDelegate` (required) | Correct rejected attributes | `submitAttributes(_:delegate:)` |
| `onMFARequired(state:)` | `MSALNativeAuthMFARequiredDelegate` (required) | Choose an MFA method | `selectAuthMethod(_:verificationContact:delegate:)` |
| `onMFAVerificationRequired(state:)` | `MSALNativeAuthMFAVerificationRequiredDelegate` (required) | Enter MFA challenge code | `submitChallenge(_:delegate:)` |
| `onStrongAuthRegistrationRequired(state:)` | `MSALNativeAuthStrongAuthRegistrationRequiredDelegate` (required) | Choose method for strong-auth registration (JIT) | `selectAuthMethod(_:verificationContact:delegate:)` |
| `onStrongAuthVerificationRequired(state:)` | `MSALNativeAuthStrongAuthVerificationRequiredDelegate` (required) | Enter JIT challenge code | `submitChallenge(_:delegate:)` |
| `onFlowCompleted(result:)` | `MSALNativeAuthFlowDelegate` (**required**) | **Terminal success** — user is authenticated | — (returns `MSALNativeAuthUserAccountResult`, see §6) |
| `onFlowError(error:)` | `MSALNativeAuthFlowDelegate` (**required**) | **Terminal error** for the current attempt | — (returns `MSALNativeAuthFlowError`, see §5) |

Notes:
- The same delegate instance is passed to every continuation call, so the SDK can route the next
  server response back to the app.
- `onFlowCompleted` and `onFlowError` are the only terminal callbacks; the 9 state callbacks are
  intermediate and always expect the app to continue via the supplied state.
- **Diagnostics:** when the server reaches a state the app has not handled (its delegate does not
  conform to the per-state protocol), the SDK reports `onFlowError` with
  type `notImplemented` and an **actionable message naming the exact per-state protocol and method to
  implement**. iOS additionally logs the failure at `.error` (non-PII — only type/method/flow names)
  and, in `DEBUG` builds only, triggers an `assertionFailure` so integrators catch the missing handler
  during development (never in release/customer builds). Other platforms should mirror this
  actionable-diagnostic behavior.

---

## 4. States — `MSALNativeAuthState` subclasses

`MSALNativeAuthState` is the abstract base. The SDK always delivers a concrete subclass to the
matching delegate callback. Each subclass carries **read-only step data** and exposes **only the
valid continuation method(s)**. Continuation methods take the user input plus the delegate.

| State | Data (read-only) | Continuation method(s) |
|---|---|---|
| `MSALNativeAuthCodeRequiredState` | `sentTo`, `channel`, `codeLength` | `submitCode(_ code:, delegate:)`, `resendCode(delegate:)` |
| `MSALNativeAuthPasswordRequiredState` | — | `submitPassword(_ password:, delegate:)` |
| `MSALNativeAuthNewPasswordRequiredState` | — | `submitNewPassword(_ password:, delegate:)` |
| `MSALNativeAuthAttributesRequiredState` | `attributes: [MSALNativeAuthRequiredAttribute]` | `submitAttributes(_ attributes: [String: Any], delegate:)` |
| `MSALNativeAuthAttributesInvalidState` | `attributeNames: [String]` | `submitAttributes(_ attributes: [String: Any], delegate:)` |
| `MSALNativeAuthMFARequiredState` | `authMethods: [MSALAuthMethod]` | `selectAuthMethod(_ method:, verificationContact: String?, delegate:)` |
| `MSALNativeAuthMFAVerificationRequiredState` | `sentTo`, `channel`, `codeLength` | `submitChallenge(_ challenge:, delegate:)` |
| `MSALNativeAuthStrongAuthRegistrationRequiredState` | `authMethods: [MSALAuthMethod]` | `selectAuthMethod(_ method:, verificationContact: String?, delegate:)` |
| `MSALNativeAuthStrongAuthVerificationRequiredState` | `sentTo`, `channel`, `codeLength` | `submitChallenge(_ challenge:, delegate:)` |

Supporting value types:
- `channel`: `MSALNativeAuthChannelType` (e.g. email/SMS) — how the code was delivered.
- `sentTo`: a masked destination (e.g. partially obfuscated email).
- `codeLength`: expected OTP length.
- `MSALAuthMethod`: an available authentication method for MFA / strong-auth registration.
- `MSALNativeAuthRequiredAttribute`: a required sign-up attribute descriptor (has `name`).

Each continuation call resumes the flow; the next server response arrives on the same delegate as
another state callback, `onFlowCompleted`, or `onFlowError`.

---

## 5. Unified error — `MSALNativeAuthFlowError`

`MSALNativeAuthFlowError` **inherits `MSALNativeAuthError`** and is the only error type in the flow.

Inherited (base `MSALNativeAuthError`) surface — implement on every platform:
- `errorDescription` — human-readable description.
- `correlationId` — request correlation id (for support/debugging).
- `errorCodes` — server error codes (`[Int]`).
- `errorUri` — optional URL for more info.
- `isBrowserRequired` — `true` when the flow **must fall back to a browser-based interactive flow**.
  (Browser-required is surfaced as an error flag, **not** a separate state/callback.)

Classifications (exposed as boolean accessors on `MSALNativeAuthFlowError`):

| Accessor | Meaning |
|---|---|
| `isNotImplemented` | The flow/step is not implemented yet. |
| `isUserNotFound` | Username not found in the directory. |
| `isInvalidCode` | Submitted OTP was invalid/expired. |
| `isInvalidContinuationToken` | Continuation token rejected (wrong endpoint / tampered / expired). |
| `isInvalidPassword` | New/sign-up password rejected by policy (too weak, etc.). |
| `isInvalidCredentials` | Sign-in username/password not accepted. |
| `isInvalidUsername` | Username failed local (client-side) validation. |
| `isUserDoesNotHavePassword` | Account has no password — must use a code flow. |
| `isUserAlreadyExists` | Account already exists during sign up. |
| `isInvalidChallenge` | Submitted MFA/strong-auth challenge rejected. |
| `isAuthMethodBlocked` | Server blocked the requested strong-auth method. |
| `isVerificationContactBlocked` | Server blocked the provided verification contact. |
| `isInvalidInput` | Invalid input for a strong-auth registration step. |
| `isBrowserRequired` *(inherited)* | Must continue in a browser. |

**Recovery model:** `onFlowError` delivers only the error (no state object). The app decides whether
the failure is recoverable by inspecting the error (e.g. `isInvalidCode`, `isInvalidPassword`,
`isInvalidChallenge`, `isInvalidInput`) and, if so, **retries by calling the relevant method again on
the state it is currently handling**. Non-recoverable errors end the attempt.

---

## 6. Success result — `MSALNativeAuthUserAccountResult`

Delivered by `onFlowCompleted(result:)` when the flow finishes with tokens. Key surface:
- `account` — the account object (`MSALAccount`).
- `idToken` — the ID token (optional).
- `signOut()` — clears the account's cached tokens.
- `getAccessToken(parameters:delegate:)` — see §7.

---

## 7. Get access token — **UNCHANGED from V1**

> ⚠️ **No change.** The token-retrieval API is identical to V1. JS/Android teams should keep their
> existing equivalent and **not** fold it into the V2 flow delegate.

`result.getAccessToken(parameters: MSALNativeAuthGetAccessTokenParameters, delegate: CredentialsDelegate)`

`MSALNativeAuthGetAccessTokenParameters`:
- `forceRefresh` (default `false`)
- `returnRefreshToken` (default `false`)
- `scopes?`
- `claimsRequest?`
- `correlationId?`

`CredentialsDelegate` (its own delegate — **not** `MSALNativeAuthFlowDelegate`):
- `onAccessTokenRetrieveCompleted(result: MSALNativeAuthTokenResult)` — *optional*; if a flow needs it
  and it is not implemented, `onAccessTokenRetrieveError` is called instead.
- `onAccessTokenRetrieveError(error: RetrieveAccessTokenError)` — required.

`MSALNativeAuthTokenResult`: `accessToken`, `refreshToken?`, `scopes`, `expiresOn?`.

---

## 8. V1 → V2 delta (summary)

| Concern | V1 | V2 |
|---|---|---|
| Delegates | One protocol **per step** (per flow) | **Base** `MSALNativeAuthFlowDelegate` (terminal callbacks) + **one per-state delegate protocol** extending it, shared across signIn/signUp/resetPassword |
| Flow errors | One error type **per step/flow** | **One** `MSALNativeAuthFlowError` |
| Continuation | State objects + downcasting | Self-contained **states** exposing only valid method(s), no downcast |
| Browser required | Error flag | Error flag (`isBrowserRequired`) — **same approach** |
| Required-ness | Mixed optional/required methods | **Terminal callbacks (`onFlowCompleted`/`onFlowError`) required on the base delegate; each of the 9 state callbacks required within its own per-state protocol, conformance opt-in** (state not conformed → `onFlowError` with `notImplemented`) |
| Get access token | `getAccessToken` + `CredentialsDelegate` | **Identical — unchanged** |

---

## 9. Platform-mapping notes

- **Naming:** drop the `MSAL`/`MSALNativeAuth` prefixes and adapt to each platform's conventions
  (e.g. JS: `NativeAuthFlowDelegate` / a callbacks object or event emitter; Android/Kotlin: a
  `NativeAuthFlowCallback` interface, sealed classes for states/errors).
- **Threading:** all flow-delegate callbacks are invoked on the **main/UI thread**. Preserve this so
  apps can touch UI directly. (iOS marks them `@MainActor`.)
- **Strongly-typed states:** the "one state per callback, only valid continuations" rule is the key
  ergonomic win — model states as distinct types (classes / sealed hierarchy) rather than a single
  bag with optional methods.
- **Errors:** model `NativeAuthFlowError` as extending a shared `NativeAuthError` base carrying
  `errorDescription / correlationId / errorCodes / errorUri / isBrowserRequired`, with the boolean
  classifications from §5. On JS, expose these as readonly getters or a discriminant `type` field.
- **Obj-C interop (`@objc`, optionals, `NS_SWIFT_NAME`) is iOS-only** and can be ignored by JS/Android.
- **Required vs conditional handlers:** the two terminal callbacks (`onFlowCompleted`, `onFlowError`)
  are required on the base delegate; each of the 9 state callbacks is required within its own
  per-state delegate protocol that extends the base, but conforming to that protocol is opt-in per
  state. If the server reaches a state whose per-state protocol the app does not conform to, the SDK
  reports `onFlowError` with type `notImplemented`. To keep this discoverable, the error carries an
  **actionable message naming the exact protocol/method to implement**; iOS also logs at `.error`
  (non-PII) and asserts in `DEBUG`
  only. On platforms without a "required protocol method" concept (JS), document this contract and
  consider runtime validation with the same actionable message.

---

*Generated from the iOS Native Auth V2 source. If the iOS surface changes, update this contract.*
