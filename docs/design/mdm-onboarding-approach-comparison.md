# MDM onboarding orchestration approach comparison

## Problem statement and requirements

MDM onboarding in embedded webview flows needs to support:

1. **Special redirect URL handling** (for example, MDM onboarding redirects such as enroll/compliance/complete and browser handoff-style redirects) during `WKWebView` navigation.
2. **Response-header-driven behavior** from `WKNavigationResponse` (telemetry capture plus ASWebAuthenticationSession handoff decisions).
3. Clear placement of orchestration logic so we avoid duplicate logic paths and keep behavior aligned with existing MSAL-for-objc patterns.

Two implementation patterns have been discussed in common library PRs:

- **PR #1689 (mob onb2)**: response-object oriented orchestration example  
  <https://github.com/AzureAD/microsoft-authentication-library-common-for-objc/pull/1689>
- **PR #1782 (mob on3)**: delegate + navigation-action orchestration example  
  <https://github.com/AzureAD/microsoft-authentication-library-common-for-objc/pull/1782>

## Approach 1: Delegate + navigation-action orchestration

```text
┌─────────────────────────────────────────────────────────────────────┐
│ Interactive request starts                                          │
└─────────────────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Embedded WKWebView controller                                       │
│ (navigation delegate callbacks)                                     │
└─────────────────────────────────────────────────────────────────────┘
          │                                  │
          │ Navigation action                │ Navigation response
          ▼                                  ▼
┌──────────────────────────────┐    ┌──────────────────────────────────┐
│ Intercept special redirects   │    │ Read response headers            │
│ (enroll/compliance/complete,  │    │ (telemetry + handoff detection)  │
│ browser://, msauth://, etc.)  │    │                                  │
└──────────────────────────────┘    └──────────────────────────────────┘
          │                                  │
          └──────────────┬───────────────────┘
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Delegate/helper returns explicit action                             │
│ (load request, complete auth, fail, handoff/resume)                 │
└─────────────────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Controller executes action and continues flow                        │
└─────────────────────────────────────────────────────────────────────┘
```

## Approach 2: Response-object orchestration (factory/operation driven)

```text
┌─────────────────────────────────────────────────────────────────────┐
│ Interactive request starts                                          │
└─────────────────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Webview returns callback/result URL                                 │
└─────────────────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Factory parses URL (and optional propagated headers)                │
│ into typed response objects                                         │
└─────────────────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Operation/controller handles response type                          │
│ (start system webview/ASWebAuth, resume embedded flow, complete)    │
└─────────────────────────────────────────────────────────────────────┘
```

## Comparison

| Dimension | Delegate + navigation-action | Response-object orchestration |
|---|---|---|
| Trigger point | During navigation callbacks | After result URL is produced |
| Best fit for special redirect URLs | Strong (cancel/replace immediately) | Possible, but often later than desired |
| Best fit for header-driven ASWebAuth handoff | Strong (headers available in `decidePolicyForNavigationResponse`) | Requires extra header propagation into responses |
| Separation of concerns | Keeps navigation policy near webview delegate | Keeps semantic response handling in factory/operations |
| Alignment with existing switch-browser flow | Complementary, could feed typed responses later | Directly aligned with current `Response -> Operation` model |
| Risk | Delegate logic can grow if not bounded | Factory/operation can become orchestration-heavy if used for mid-navigation rules |

## Mapping to current MSAL-for-objc patterns (dev)

The current dev implementation already demonstrates a mature **response-object + operation** pipeline for switch-browser/cert-auth handoff:

- `MSIDAADWebviewFactory` builds typed responses, including `MSIDSwitchBrowserResponse` and `MSIDSwitchBrowserResumeResponse`.
- `MSIDWebResponseOperationFactory` maps those responses to operations.
- `MSIDSwitchBrowserOperation` and `MSIDSwitchBrowserResumeOperation` perform orchestration.
- `MSIDSwitchBrowserOperation` calls `MSIDCertAuthManager`, which starts `MSIDSystemWebviewController`.
- `MSIDSystemWebViewControllerFactory` uses `MSIDASWebAuthenticationSessionHandler`, which wraps `ASWebAuthenticationSession`.

The current embedded-webview delegate path already contains **navigation-time policy hooks** that are relevant for an on3-style approach:

- `MSIDAADOAuthEmbeddedWebviewController` intercepts browser/msauth/PKeyAuth-related navigation actions and can route decisions via delegate block (`externalDecidePolicyForBrowserAction`).
- `MSIDOAuth2EmbeddedWebviewController` exposes `navigationResponseBlock`, which is the natural place for response-header telemetry and handoff signal capture.
- `didReceiveAuthenticationChallenge` routes through `MSIDChallengeHandler` and `MSIDPKeyAuthHandler`, showing existing delegate-style challenge handling patterns.
- WebAuthN extension-aware behavior is already represented via `MSIDWebAuthNUtil` checks in navigation decision logic.

## Recommendation

Use a **hybrid with strict boundaries**:

1. **Navigation-time concerns** (special redirect instructions + response-header telemetry/handoff detection) should stay in delegate/navigation layers.
2. **Semantic response handling and durable flow state** should stay in response/operation layers.

This keeps consistency with existing patterns while avoiding forcing all logic into a single abstraction that is either too early (factory only) or too coupled to UI navigation (delegate only).

## Avoiding dual-path complexity

To avoid two competing orchestration paths:

- Define one owner for each decision type:
  - **Delegate path** owns interception and translation of raw navigation/header events into normalized events/actions.
  - **Response/operation path** owns stateful flow progression after events are normalized.
- Keep parsing rules centralized (single parser/helper per signal type).
- Keep response classes semantic (what happened), not UI-imperative (how to execute UI steps).
- Keep UI transitions (embedded ↔ ASWebAuth) in controller/operation layers, not in response model objects.

With these boundaries, both patterns can coexist without overlap and remain maintainable.
