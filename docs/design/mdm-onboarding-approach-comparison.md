# Mobile Onboarding: Orchestration Approach Comparison (Delegate vs Response-Object)

## Status

Draft / Design exploration

## Summary (Recommendation)

For **Mobile Onboarding** in an embedded `WKWebView` flow that must:

- intercept **special redirect URLs** for **mid-flight instructions** (e.g., `msauth://enroll`, `msauth://compliance`),
- perform **BRT acquisition once per redirect instruction** before continuing,
- analyze **HTTP response headers** for telemetry and to trigger a **header-driven ASWebAuthenticationSession (ASWebAuth) handoff**, and
- **resume the same embedded WKWebView session** after the handoff,

the recommended orchestration is:

> **Approach A: Delegate + navigation-time orchestration** as the primary architecture.

At the same time, for **terminal/semantic outcomes** that should be handled uniformly by the normal response parsing pipeline, the recommended approach is:

> **Allow `msauth://in_app_enrollement_complete` to propagate to a response object** (do not intercept it for immediate termination or onboarding work; this callback uses the service-defined `enrollement` spelling).

---

### Callback URL naming note

`msauth://in_app_enrollement_complete` is the service-defined callback URL and must be used verbatim where this callback is referenced, even though `enrollement` is a non-standard English spelling.

## Problem Statement

Mobile Onboarding introduces **mid-flight** instructions during an interactive, web-based authentication session hosted in an embedded `WKWebView`. During this interactive session, the client must:

1. Detect and handle **mid-flight instruction redirect URLs**:
   - `msauth://enroll`
   - `msauth://compliance`

2. Handle **terminal completion callback URL** (uniform outcome handling):
   - `msauth://in_app_enrollement_complete` (actual callback URL, including service-defined `enrollement` spelling)

3. Perform **BRT (broker refresh token) acquisition** **once per redirect instruction** before continuing the web flow (applies to `enroll`/`compliance`).

4. Parse and record **telemetry** from **HTTP response headers**.

5. If response headers indicate an **ASWebAuth handoff**, launch `ASWebAuthenticationSession` and, upon completion, **resume the same embedded `WKWebView` session** by loading the returned callback URL (callback scheme may be anything: custom scheme, https, etc.).

The key design question is where to place orchestration:

- at the webview boundary (navigation-time delegates), or
- in completion-time “response object + operation” pipelines.

---

## Requirements & Constraints

### Functional Requirements

1. **Mid-flight instruction URL handling (navigation-time)**
   - Detect: `msauth://enroll`, `msauth://compliance`.
   - For `enroll` / `compliance`:
     - cancel/override default navigation,
     - perform **BRT acquisition once per redirect instruction**,
     - compute the next URL from query params and add required query params/headers,
     - load the resulting request into the **same embedded `WKWebView`**.

2. **Terminal completion URL handling (uniform outcome handling)**
   - Detect: `msauth://in_app_enrollement_complete`.
   - Behavior:
     - do **not** intercept this URL for onboarding work at navigation-time,
     - allow it to propagate to the normal result parsing path,
     - produce a **response object** (uniform handling with other terminal outcomes).

3. **Response header processing**
   - Collect telemetry from response headers at the time they are available.
   - Detect **header-driven** ASWebAuth handoff and initiate it when required.

4. **ASWebAuth handoff**
   - Trigger is **strictly header-driven**.
   - Start URL may be provided by headers.
   - Callback URL scheme can be anything.
   - On completion, callback must be **loaded back into the same embedded `WKWebView` session**.

### Non-Functional Requirements

- Deterministic behavior: mid-flight instructions must be handled at the correct moment (navigation-time).
- Clear ownership of state and decisions.
- Avoid “dual-path” logic (don’t implement the same decision in two places).
- Testable: URL classification, header parsing, one-time BRT acquisition gating.

---

## Existing Patterns in the Repo (Deep Analysis)

The repo already contains two highly relevant patterns that illustrate the tradeoff clearly.

### Pattern 1: PKeyAuth (Navigation-time interception in `MSIDAADOAuthController`)

PKeyAuth is handled by detecting a special URN/prefix in the navigation action:

- Determine `requestURLString` and check for the PKeyAuth URN prefix (e.g., `kMSIDPKeyAuthUrn`).
- **Cancel navigation** via `decisionHandler(WKNavigationActionPolicyCancel)`.
- Invoke the handler:
  - `MSIDPKeyAuthHandler handleChallenge:... completionHandler:^(NSURLRequest *challengeResponse, NSError *error) { ... }`
- On success, **resume the same embedded webview** by loading the returned request:
  - `[self loadRequest:challengeResponse]`

**Why it matters for Mobile Onboarding:** This is a canonical example of *mid-flight special instruction handling* implemented as **navigation-time orchestration**: detect → cancel → do work → load a new request → continue in the same `WKWebView`.

### Pattern 2: Switch-browser (Response-object + Operation)

Switch-browser is modeled as a typed response executed by an operation:

- Binding between response class and operation class is registered via:
  - `+[MSIDWebResponseOperationFactory registerOperationClass:forResponseClass:]` (in `+load`)

In `MSIDSwitchBrowserOperation`:

- A `startURL` is constructed from `actionUri` and query items including:
  - `code = switchBrowserSessionToken`
  - `redirect_uri = requestParameters.redirectUri`
  - optional `state`
- System web auth is launched via an auth manager (e.g., `MSIDCertAuthManager startWithURL:... completionBlock:`).
- On callback URL, it is translated into a standard response via:
  - `[webRequestConfiguration responseWithResultURL:callbackURL factory:... error:&localError]`
- The response is returned to the web auth pipeline via completion block.

In `MSIDSwitchBrowserResumeOperation`:

- The embedded flow is resumed by:
  - setting `webRequestConfiguration.startURL = actionUri`,
  - injecting `Authorization: Bearer <switchBrowserSessionToken>` header,
  - creating an embedded webview and continuing via `MSIDWebviewAuthorization startSessionWithWebView:...`.

**Why it matters for Mobile Onboarding:** This is a successful example of a **response-object/operation** pipeline when the event is a *semantic instruction* like “switch context to system browser and come back.” It is modular and testable, but it is not the best fit for *mid-flight embedded navigation instructions* that must be handled at navigation-time.

---

## Candidate Approaches

### Approach A — Delegate + Navigation-Time Orchestration (Recommended)

**Core idea:** The embedded webview boundary (navigation delegates) is the single decision point for:

- mid-flight instruction URLs (`msauth://enroll`, `msauth://compliance`),
- response header telemetry,
- header-driven ASWebAuth handoff,
- resumption into the same `WKWebView` session.

**Terminal outcomes** like `msauth://in_app_enrollement_complete` are intentionally left to propagate into response parsing (uniform outcome handling).

---

## Diagrams (Updated)

### Legend

- **NavAction** = `WKNavigationDelegate decidePolicyForNavigationAction`
- **NavResponse** = `WKNavigationDelegate decidePolicyForNavigationResponse`
- **Cancel** = `decisionHandler(WKNavigationActionPolicyCancel)`
- **Allow** = `decisionHandler(WKNavigationActionPolicyAllow)`
- **Same WKWebView** = do not tear down the embedded webview; resume by `webView.load(...)`

---

### A1. NavAction URL Handling (Enroll/Compliance intercepted; Completion propagates)

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ EmbeddedWebviewController (owns WKWebView instance)                         │
└──────────────────────────────────────────────────────────────────────────────┘
                │
                │ NavAction(request.URL)
                ▼
       ┌───────────────────────────┐
       │ Classify redirect URL     │
       └───────────────────────────┘
          │              │                          │
          │              │                          │
          ▼              ▼                          ▼
   msauth://enroll   msauth://compliance   msauth://in_app_enrollement_complete
          │              │                          │
          ├───────┬──────┘                          │
          │ Cancel │                                 │ Allow (propagate)
          ▼        ▼                                 ▼
┌───────────────────────────┐            ┌─────────────────────────────────────┐
│ OnboardingOrchestrator    │            │ Normal completion / response parsing│
│ (delegate/controller)     │            │ (uniform outcome handling)          │
└───────────────────────────┘            └─────────────────────────────────────┘
          │
          │ Extract instruction parameters from URL query
          ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ BRT Guard: "once per redirect instruction"                                  │
│ - if already acquired for this instruction: skip                             │
│ - else: acquire BRT (and cache for this instruction)                         │
└──────────────────────────────────────────────────────────────────────────────┘
          │
          ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ Build nextRequest                                                            │
│ - compute final URL from query params                                        │
│ - add required query params                                                  │
│ - add required headers (including anything derived from BRT)                 │
└──────────────────────────────────────────────────────────────────────────────┘
          │
          ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ Resume SAME embedded WKWebView session                                       │
│ - webView.load(nextRequest)                                                  │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

### A2. NavResponse Header Handling (Telemetry + header-driven ASWebAuth; resume same WKWebView)

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ EmbeddedWebviewController (same WKWebView instance throughout)               │
└──────────────────────────────────────────────────────────────────────────────┘
                │
                │ NavResponse(response.headers)
                ▼
       ┌───────────────────────────┐
       │ Telemetry extraction      │
       │ (read/record headers)     │
       └───────────────────────────┘
                │
                ▼
       ┌───────────────────────────┐
       │ Detect ASWebAuth handoff? │  (strictly header-driven)
       └───────────────────────────┘
          │                 │
          │ No              │ Yes
          ▼                 ▼
        Allow        ┌──────────────────────────────────────────┐
                     │ Suspend embedded flow (do NOT destroy    │
                     │ WKWebView; pause UI/navigation as needed)│
                     └──────────────────────────────────────────┘
                                     │
                                     ▼
                     ┌──────────────────────────────────────────┐
                     │ Launch ASWebAuthenticationSession        │
                     │ - startURL derived from headers          │
                     │ - callbackURL scheme can be anything     │
                     └──────────────────────────────────────────┘
                                     │
                                     ▼
                     ┌──────────────────────────────────────────┐
                     │ ASWebAuth completes → callbackURL        │
                     └──────────────────────────────────────────┘
                                     │
                                     ▼
                     ┌──────────────────────────────────────────┐
                     │ Resume SAME embedded WKWebView session   │
                     │ - webView.load(callbackURL request)      │
                     │ - continue normal embedded navigation    │
                     └──────────────────────────────────────────┘
                                     │
                                     ▼
                                    Allow
```

---

## Approach B — Response-Object / Factory-Driven Orchestration (Comparison)

**Core idea:** Route events into a factory that creates typed response objects; the local controller and operations then perform BRT acquisition, URL construction, and ASWebAuth launching. This resembles switch-browser patterns.

> With the explicit decision that `msauth://in_app_enrollement_complete` is handled as a response outcome,
> Approach B remains appropriate for *terminal outcomes*, but not recommended as the primary mechanism
> for mid-flight instruction URLs (`msauth://enroll` / `msauth://compliance`) or header-driven triggers.

### B1. Redirect outcomes (completion as response object; enroll/compliance still a poor fit here)

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ EmbeddedWebviewController                                                    │
└──────────────────────────────────────────────────────────────────────────────┘
                │
                │ (If you force completion-time for everything, you must forward
                │  URLs + enough context, and often headers too)
                ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ Factory creates Response objects                                             │
│ - EnrollmentCompleteResponse for msauth://in_app_enrollement_complete        │
│   (response type names follow standard code naming conventions,              │
│    while callback URL strings preserve service-defined spelling)             │
│ - (Enroll/Compliance modeled as responses is possible but increases complexity)│
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Comparison Table

| Dimension | Approach A: Delegate / Navigation-Time | Approach B: Response-Object / Factory |
|---|---|---|
| Fit for `msauth://enroll` / `msauth://compliance` | **Excellent** (cancel/replace navigation) | Weaker (completion semantics for mid-flight events) |
| Handling `msauth://in_app_enrollement_complete` | **Allow to propagate to response** | **Natural fit** |
| Resume same `WKWebView` requirement | **Native** | Possible but requires more plumbing/state |
| Header-driven ASWebAuth trigger | **Excellent** | Requires explicit header propagation |
| Alignment with existing patterns | Matches **PKeyAuth** | Matches **Switch-browser** |
| Complexity | Lower (single decision boundary for mid-flight) | Higher if used for mid-flight + headers |
| Risk of incorrect timing | Low | Higher |
| Recommended use | **Primary for mid-flight + headers** | **Terminal outcomes** |

---

## Final Recommendation & Boundary Rules

### Canonical path (Approach A) MUST own:

- `msauth://enroll` (intercept at NavAction; Cancel → BRT guard → build nextRequest → load)
- `msauth://compliance` (intercept at NavAction; Cancel → BRT guard → build nextRequest → load)
- response header telemetry (NavResponse)
- header-driven ASWebAuth handoff trigger/orchestration (NavResponse + ASWebAuth launch)
- resuming the same embedded `WKWebView` session after ASWebAuth by loading the callback URL

### Response-object outcomes MUST include:

- `msauth://in_app_enrollement_complete` (terminal completion callback; allow to propagate and parse as a response object)

### Avoid dual-path complexity

1. **All mid-flight instruction redirects are handled at navigation-time.**
   Do not route `enroll`/`compliance` into completion-time response pipelines.

2. **Terminal completion callback propagates.**
   `msauth://in_app_enrollement_complete` is treated as a terminal outcome and handled uniformly via response parsing.

3. **ASWebAuth trigger stays at webview boundary.**
   Even if the ASWebAuth launching can be encapsulated, the decision (based on headers) belongs in NavResponse.

4. **Make BRT gating explicit.**
   Implement a straightforward “once per redirect instruction” guard.

---

## References

- Existing patterns in this repo:
  - PKeyAuth navigation-time interception pattern (cancel navigation → handler → `loadRequest:`).
  - Switch-browser response-object/operation pattern:
    - `MSIDSwitchBrowserOperation`
    - `MSIDSwitchBrowserResumeOperation`
    - operation registration via `MSIDWebResponseOperationFactory`.

- Common-for-objc PR references:
  - https://github.com/AzureAD/microsoft-authentication-library-common-for-objc/pull/1689
  - https://github.com/AzureAD/microsoft-authentication-library-common-for-objc/pull/1782

---

## Open Questions

1. Are the header names for ASWebAuth handoff stable and documented, so detection logic can be centralized and versioned?
2. Do we need correlation identifiers (if available) to enforce “BRT once per redirect instruction” across reload/back/forward scenarios?
3. For `msauth://in_app_enrollement_complete`, do we need additional validation (e.g., expected parameters/state) before producing the completion response?
