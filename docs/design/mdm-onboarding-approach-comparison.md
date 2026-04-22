# Mobile Onboarding orchestration approach comparison

## Scope

This document summarizes existing IdentityCore patterns that are relevant for Mobile Onboarding:

- Switch-browser flow (`MSIDSwitchBrowserResponse`, `MSIDSwitchBrowserOperation`, `MSIDSwitchBrowserResumeOperation`)
- Embedded-webview PKeyAuth interception in AAD OAuth controller (`MSIDAADOAuthEmbeddedWebviewController`)

It then compares:

1. Delegate/navigation-time orchestration
2. Response-object/operation-based orchestration

for Mobile Onboarding requirements:

- Special redirect URLs (`msauth://enroll`, `msauth://compliance`, `msauth://enrollment_complete`)
- Header-driven handoff to `ASWebAuthenticationSession`

---

## Existing pattern: switch-browser response/operation flow

### Registration and dispatch model

1. `MSIDAADWebviewFactory -oAuthResponseWithURL:...` tries response types in order and can create:
   - `MSIDSwitchBrowserResponse` (`switch_browser`)
   - `MSIDSwitchBrowserResumeResponse` (`switch_browser_resume`)
2. Operation classes self-register in `+load`:
   - `MSIDSwitchBrowserOperation` registers for `MSIDSwitchBrowserResponse`
   - `MSIDSwitchBrowserResumeOperation` registers for `MSIDSwitchBrowserResumeResponse`
3. `MSIDInteractiveAuthorizationCodeRequest -handleWebReponseV2:` obtains an operation via `MSIDWebResponseOperationFactory` and invokes it.

### Switch step (`MSIDSwitchBrowserOperation`)

1. Reads `action_uri`, `code` (`switchBrowserSessionToken`), optional `state`, and browser mode from `MSIDSwitchBrowserResponse`.
2. Builds `startURL = action_uri + { code, redirect_uri, [state] }`.
3. Starts `MSIDCertAuthManager` with that URL.
4. `MSIDCertAuthManager` creates `MSIDSystemWebviewController`, which creates an auth-session handler (`MSIDASWebAuthenticationSessionHandler`) and launches `ASWebAuthenticationSession`.
5. On callback URL from auth session:
   - `MSIDSwitchBrowserOperation` calls `responseWithResultURL:factory:context:error:` on current web request configuration.
   - This converts callback URL back into a typed webview response.
   - `parentResponse` is set to the original `MSIDSwitchBrowserResponse`.

### Resume step (`MSIDSwitchBrowserResumeOperation`)

1. Requires `MSIDSwitchBrowserResumeResponse` plus `parentResponse` of type `MSIDSwitchBrowserResponse`.
2. Optional state validation is performed against parent response state.
3. Sets `webRequestConfiguration.startURL = action_uri` (resume target).
4. Injects `Authorization: Bearer <switchBrowserSessionToken>` into custom headers.
5. Creates embedded webview through `oauthFactory.webviewFactory` and starts a new webview authorization session.

**Responsibility split:**

- Response objects: parse and validate URL payload shape (`action_uri`, `code`, `state`)
- Operations: execute side effects (launch external auth session, then resume embedded webview with required headers)

---

## Existing pattern: PKeyAuth interception in embedded webview

### Navigation-time interception (WKNavigationDelegate)

In `MSIDAADOAuthEmbeddedWebviewController -decidePolicyAADForNavigationAction:decisionHandler:`:

1. Reads current navigation URL.
2. Detects PKeyAuth URN by prefix match against `kMSIDPKeyAuthUrn`.
3. Cancels current navigation (`WKNavigationActionPolicyCancel`).
4. Calls `MSIDPKeyAuthHandler handleChallenge:context:customHeaders:externalSSOContext:completionHandler:`.
5. In completion handler:
   - If no challenge response request is produced, ends web auth with error.
   - Otherwise calls `loadRequest:` with returned challenge response request.

**Responsibility split:**

- Navigation delegate: detect challenge URL and control navigation policy timing
- Challenge handler: build signed challenge response request
- Webview controller: continue flow by loading the handler-generated request

---

## Comparison for Mobile Onboarding

### Option A: delegate/navigation-time orchestration

Use webview navigation delegate hooks to:

- Intercept special redirect URLs (`enroll`, `compliance`, `enrollment_complete`)
- Read response headers at navigation-response time
- Trigger handoff to `ASWebAuthenticationSession` immediately when header contract says to do so
- Resume embedded flow with returned callback URL / generated follow-up request

### Option B: response-object/operation orchestration

Map special redirects into typed response objects and execute response operations to perform handoff/resume logic.

### Fit against requirements

| Requirement | Delegate/navigation-time | Response/operation |
|---|---|---|
| `msauth://enroll` + `msauth://compliance` are mid-flow instructions | Natural fit (same as PKeyAuth interception timing) | Possible but heavier (requires synthetic response modeling of navigation instructions) |
| Header-driven ASWebAuth handoff | Best fit (headers available at navigation-response point) | Requires header plumbing into response pipeline |
| Resume embedded webview with auth headers | Can do directly during navigation orchestration | Already proven by `MSIDSwitchBrowserResumeOperation` |
| Separation of parse vs side-effect execution | Weaker unless carefully structured | Strong by design (response parse + operation execution) |
| Overall complexity for onboarding | Lower for redirect/header routing | Higher if used for every redirect event |

---

## Recommendation

**Recommended primary approach for Mobile Onboarding:**

- Use **delegate/navigation-time orchestration** for redirect and header decisions.
- Reuse **response/operation orchestration** only where there is a clear semantic state transition that benefits from typed responses and operation chaining.

This aligns with current patterns:

- PKeyAuth is already navigation-time interception.
- Switch-browser resume logic demonstrates a strong operation-based mechanism for side effects that require explicit sequencing and resume headers.

---

## Boundary rules (to avoid mixed orchestration ambiguity)

1. **Navigation delegate owns routing decisions**
   - Special onboarding redirects (`enroll`, `compliance`, `enrollment_complete`) are detected/canceled/continued at navigation time.
   - Header-derived `ASWebAuthenticationSession` handoff decision is made where headers are available (navigation response stage).

2. **Response objects own payload parsing and semantic typing**
   - Use when URL payload should be represented as a typed response with explicit validation rules.

3. **Operations own side effects and resumptions**
   - Launching external browser/auth session and embedded-webview resume with explicit headers/token belongs in operation-like executors.

4. **Do not model every mid-navigation instruction as completion response**
   - Keep navigation-time redirects in delegate flow unless they need durable typed chaining.

5. **If operation chaining is used, preserve parent/child response linkage**
   - Follow switch-browser pattern (`parentResponse`) when resume validation depends on previous state.
