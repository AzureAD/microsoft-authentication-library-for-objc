# MDM onboarding approach comparison (current `dev` patterns)

This document captures current patterns in `AzureAD/microsoft-authentication-library-for-objc` (`dev`) and maps them to Mobile Onboarding requirements:

- special redirect URLs (`msauth://enroll`, `msauth://compliance`, `msauth://enrollment_complete`)
- response-header driven ASWebAuth handoff

## 1) Switch-browser pattern (`MSIDSwitchBrowserResponse` + `MSIDSwitchBrowserOperation`)

### Key files

- `MSAL/IdentityCore/IdentityCore/src/oauth2/aad_base/MSIDAADWebviewFactory.m`
- `MSAL/IdentityCore/IdentityCore/src/webview/response/MSIDSwitchBrowserResponse.{h,m}`
- `MSAL/IdentityCore/IdentityCore/src/webview/operations/MSIDSwitchBrowserOperation.{h,m}`
- `MSAL/IdentityCore/IdentityCore/src/webview/MSIDCertAuthManager.{h,m}`
- `MSAL/IdentityCore/IdentityCore/src/webview/systemWebview/session/MSIDSystemWebviewController.m`
- `MSAL/IdentityCore/IdentityCore/src/webview/systemWebview/session/MSIDASWebAuthenticationSessionHandler.m`
- `MSAL/IdentityCore/IdentityCore/src/requests/MSIDInteractiveAuthorizationCodeRequest.m`

### Call chain and responsibilities

1. **Embedded/system web auth finishes with callback URL**
   - `MSIDWebviewAuthorization` gets callback URL and calls `responseWithResultURL`.
2. **Factory classifies URL into typed response**
   - `MSIDAADWebviewFactory -oAuthResponseWithURL:...` tries multiple response types and creates `MSIDSwitchBrowserResponse` when URL matches `<redirect>/switch_browser` and required params (`action_uri`, `code`) are present.
3. **Interactive request maps response -> operation**
   - `MSIDInteractiveAuthorizationCodeRequest -handleWebReponseV2` asks `MSIDWebResponseOperationFactory` for operation and invokes it.
4. **Operation launches ASWebAuthenticationSession path**
   - `MSIDSwitchBrowserOperation -invokeWithRequestParameters`:
     - builds `startURL` from `action_uri` + query (`code`, `redirect_uri`, optional `state`)
     - calls `MSIDCertAuthManager startWithURL:...`
5. **ASWebAuthenticationSession is created and started**
   - `MSIDCertAuthManager` creates `MSIDSystemWebviewController` with `useAuthenticationSession` enabled.
   - `MSIDSystemWebViewControllerFactory` returns `MSIDASWebAuthenticationSessionHandler`.
   - `MSIDASWebAuthenticationSessionHandler` initializes and starts `ASWebAuthenticationSession`.
6. **Callback URL returns into web response pipeline**
   - completion callback from cert auth manager returns URL to `MSIDSwitchBrowserOperation`.
   - operation calls `responseWithResultURL` again, sets `response.parentResponse = switchBrowserResponse`, and re-enters `handleWebReponseV2` recursion.
   - flow typically continues via `MSIDSwitchBrowserResumeResponse`/`MSIDSwitchBrowserResumeOperation` then back to regular auth-code/token path.

## 2) PKeyAuth pattern (AAD embedded webview controller)

> Note: in current `dev`, the concrete class is `MSIDAADOAuthEmbeddedWebviewController` (not `MSIDAADOAuthController`).

### Key files

- `MSAL/IdentityCore/IdentityCore/src/webview/embeddedWebview/MSIDAADOAuthEmbeddedWebviewController.m`
- `MSAL/IdentityCore/IdentityCore/src/webview/embeddedWebview/MSIDOAuth2EmbeddedWebviewController.{h,m}`
- `MSAL/IdentityCore/IdentityCore/src/webview/embeddedWebview/challangeHandlers/MSIDPKeyAuthHandler.m`
- `MSAL/IdentityCore/IdentityCore/src/oauth2/aad_base/MSIDAADWebviewFactory.m`
- `MSAL/IdentityCore/IdentityCore/src/requests/MSIDInteractiveAuthorizationCodeRequest.m`

### Detection/interception points and hooks

1. **Navigation-time detection (primary interception)**
   - `MSIDAADOAuthEmbeddedWebviewController -decidePolicyAADForNavigationAction` checks URL and has explicit `// check for pkeyauth challenge.` branch.
   - If URL has `urn:http-auth:PKeyAuth` prefix, it cancels navigation and calls `MSIDPKeyAuthHandler handleChallenge`.
2. **PKeyAuth challenge response construction**
   - `MSIDPKeyAuthHandler` parses challenge params, creates auth header via `MSIDPkeyAuthHelper`, and returns `NSURLRequest` with `x-ms-PkeyAuth+`, `Authorization`, telemetry headers, and optional PRT header.
   - controller reloads WKWebView with this request.
3. **Delegate hooks around navigation**
   - `externalDecidePolicyForBrowserAction` hook exists on embedded controller and is wired from `MSIDInteractiveAuthorizationCodeRequest` through webview factory.
   - This hook is used for `browser://`/legacy browser policy decisions in `MSIDAADOAuthEmbeddedWebviewController`.
4. **Response-header hook (available in base embedded controller)**
   - `MSIDOAuth2EmbeddedWebviewController` exposes `navigationResponseBlock` and calls it in `webView:decidePolicyForNavigationResponse:` with `NSHTTPURLResponse`.
   - This is the existing place to inspect response headers at navigation-response time.

## 3) Pattern comparison for Mobile Onboarding requirements

### Delegate/navigation-time pattern

Best fit for:

- URL instructions that must be handled immediately (`msauth://enroll`, `msauth://compliance`)
- response-header driven decisions (telemetry capture + “launch ASWebAuth now”)

Why:

- decisions happen at the exact WebKit event where URL/headers are available
- no need to force intermediate redirects into terminal `responseWithResultURL` semantics
- aligns with existing PKeyAuth interception model (navigation delegate + immediate request rewrite)

### Response-object/operation pattern

Best fit for:

- typed semantic outcomes after callback parsing (`switch_browser`, `switch_browser_resume`, auth code, wpj/upgrade responses)
- multi-step flows where response chaining (`parentResponse`) is useful

Why:

- central parsing and operation dispatch via factory is strong for terminal/protocol-level responses
- operation objects encapsulate side effects (e.g., switch-browser ASWebAuth launch)

## 4) Recommendation

For Mobile Onboarding:

1. **Use delegate/navigation-time orchestration as primary for `enroll`/`compliance` redirects and header-driven ASWebAuth handoff.**
2. **Use response-object/operation pattern for terminal semantic responses, including `enrollment_complete` and existing switch-browser response types.**
3. Keep a strict boundary so onboarding redirects are not modeled as terminal auth completion events unless they truly terminate the current web auth stage.

This keeps parity with existing PKeyAuth interception behavior while preserving the strengths of the existing response-object pipeline for completion/resume semantics.
