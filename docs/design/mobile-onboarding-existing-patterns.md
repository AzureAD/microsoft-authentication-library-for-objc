# Mobile Onboarding: Existing Pattern Analysis (dev)

This note summarizes current patterns in `dev` for:

1. PKeyAuth handling in embedded navigation.
2. `MSIDSwitchBrowserResponse` switch-browser orchestration that opens `ASWebAuthenticationSession`.

## 1) PKeyAuth pattern (navigation-time handling in embedded webview)

### Where interception happens

- `MSIDAADOAuthEmbeddedWebviewController` intercepts navigation in `decidePolicyAADForNavigationAction:`.
- For `urn:http-auth:PKeyAuth` (`kMSIDPKeyAuthUrn`), it cancels current navigation and invokes `MSIDPKeyAuthHandler`.

Key locations:

- `MSAL/IdentityCore/IdentityCore/src/webview/embeddedWebview/MSIDAADOAuthEmbeddedWebviewController.m`
  - `decidePolicyAADForNavigationAction:`
  - PKeyAuth branch: checks URL prefix, calls `MSIDPKeyAuthHandler handleChallenge:...`

### Hooks/delegates involved

- Webview delegate hook: `WKNavigationDelegate` decision (`decidePolicyForNavigationAction`).
- Internal callback hook: `MSIDPKeyAuthHandler` async completion block returns `NSURLRequest *challengeResponse`.

### Responsibilities and where decisions are made

- Embedded controller decides that URL is a PKeyAuth challenge and must be intercepted.
- `MSIDPKeyAuthHandler` parses challenge query, builds auth header, injects PKeyAuth + telemetry + optional PRT header, and returns a request to continue.

Key location:

- `MSAL/IdentityCore/IdentityCore/src/webview/embeddedWebview/challangeHandlers/MSIDPKeyAuthHandler.m`

### Where flow resumes

- Success: embedded controller calls `loadRequest:` with challenge response request.
- Failure: embedded controller ends auth (`endWebAuthWithURL:nil error:error`).

---

## 2) Switch-browser pattern (`MSIDSwitchBrowserResponse` + operation/factory orchestration)

### Where response objects are created

- `MSIDAADWebviewFactory` creates typed responses from callback URL.
- It attempts `MSIDSwitchBrowserResponse`, then `MSIDSwitchBrowserResumeResponse`.

Key location:

- `MSAL/IdentityCore/IdentityCore/src/oauth2/aad_base/MSIDAADWebviewFactory.m`
  - `oAuthResponseWithURL:requestState:ignoreInvalidState:endRedirectUri:context:error:`

### How operations are chosen and invoked

- `MSIDWebResponseOperationFactory` maps response type (`+[responseClass operation]`) to operation class.
- Interactive request v2 path (`MSIDInteractiveAuthorizationCodeRequest`) recursively executes operations until terminal auth code/error response.

Key locations:

- `MSAL/IdentityCore/IdentityCore/src/webview/operations/MSIDWebResponseOperationFactory.m`
- `MSAL/IdentityCore/IdentityCore/src/requests/MSIDInteractiveAuthorizationCodeRequest.m`

### How `ASWebAuthenticationSession` gets opened

- `MSIDSwitchBrowserOperation` receives `MSIDSwitchBrowserResponse`.
- It builds start URL (`action_uri` + query with switch token, redirect URI, optional state).
- It calls `MSIDCertAuthManager startWithURL:...`.
- `MSIDCertAuthManager` creates `MSIDSystemWebviewController` with `useAuthenticationSession` and starts it.
- `MSIDSystemWebviewController` creates auth session via `MSIDSystemWebViewControllerFactory`, which returns `MSIDASWebAuthenticationSessionHandler`.
- `MSIDASWebAuthenticationSessionHandler` constructs and starts `ASWebAuthenticationSession`.

Key locations:

- `MSAL/IdentityCore/IdentityCore/src/webview/operations/MSIDSwitchBrowserOperation.m`
- `MSAL/IdentityCore/IdentityCore/src/webview/MSIDCertAuthManager.m`
- `MSAL/IdentityCore/IdentityCore/src/webview/systemWebview/session/MSIDSystemWebviewController.m`
- `MSAL/IdentityCore/IdentityCore/src/webview/systemWebview/session/MSIDSystemWebViewControllerFactory.m`
- `MSAL/IdentityCore/IdentityCore/src/webview/systemWebview/session/MSIDASWebAuthenticationSessionHandler.m`

### How callback URLs are handled

- `ASWebAuthenticationSession` completion returns callback URL.
- `MSIDSwitchBrowserOperation` converts callback URL into next web response via `responseWithResultURL:factory:...` and sets `parentResponse`.
- `MSIDSwitchBrowserResumeOperation` validates state against parent response, prepares embedded webview request (`action_uri`) with bearer header from switch token, and restarts webview session.
- On app URL open, `MSALPublicClientApplication handleMSALResponse:sourceApplication:` routes callback URL to:
  - `MSIDWebviewAuthorization handleURLResponseForSystemWebviewController:`
  - `MSIDCertAuthManager completeWithCallbackURL:`

Key locations:

- `MSAL/IdentityCore/IdentityCore/src/webview/operations/MSIDSwitchBrowserResumeOperation.m`
- `MSAL/src/MSALPublicClientApplication.m`

---

## Comparison for Mobile Onboarding requirements

### Delegate/navigation-time orchestration

**Pros**
- Decisions happen at the exact navigation/response event where signal is available.
- Natural fit for redirect instructions (`msauth://enroll`, `msauth://compliance`) and response-header-driven branching.
- Immediate cancel/replace behavior in webview.

**Cons**
- Requires reliable installation of delegate hooks (if omitted, behavior is bypassed).
- More behavior can accumulate in controller delegate paths.

### Response-object/factory + operation orchestration

**Pros**
- Strong typed modeling of protocol steps.
- Reusable operation pipeline (`response -> operation -> next response`).
- Good fit for semantic/terminal transitions (`switch_browser`, `switch_browser_resume`, auth code/error).

**Cons**
- Requires crossing callback boundaries before acting (less immediate than raw navigation interception).
- More classes/state handoff for non-terminal navigation directives.

### Lessons for Mobile Onboarding

1. Keep **navigation-time delegate handling** for mid-flight redirect instructions and response-header decisions.
2. Keep **response-object/operation handling** for typed semantic transitions after callback materialization.
3. If mixing both, define clear ownership boundary:
   - delegate path: detect/intercept and reroute navigation-time onboarding actions
   - factory/operation path: execute typed response workflows (`switch_browser*`, final completion)
