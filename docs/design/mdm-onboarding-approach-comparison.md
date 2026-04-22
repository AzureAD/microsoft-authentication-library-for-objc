# Mobile Onboarding Approach Comparison

## Finalized Callback URL Contract

- The completion callback URL is exactly: `msauth://in_app_enrollement_complete`.
- `msauth://in_app_enrollement_complete` must be **allowed** in navigation handling so it propagates into response-object parsing/handling.
- `msauth://in_app_enrollement_complete` must **not** be intercepted at navigation-time as an enroll/compliance instruction.

## Diagrams (Updated)

### Legend

- **NavAction** = `WKNavigationDelegate decidePolicyForNavigationAction`
- **NavResponse** = `WKNavigationDelegate decidePolicyForNavigationResponse`
- **Cancel** = `decisionHandler(WKNavigationActionPolicyCancel)`
- **Allow** = `decisionHandler(WKNavigationActionPolicyAllow)`
- **Same WKWebView** = do not tear down the embedded webview; resume by `webView.load(...)`

---

### Approach A (Recommended): Delegate / Navigation-Time Orchestration

#### A1. Special Redirect URL Handling (`msauth://enroll`, `msauth://compliance`, `msauth://in_app_enrollement_complete`)

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ EmbeddedWebviewController (owns WKWebView instance)                           │
└──────────────────────────────────────────────────────────────────────────────┘
                │
                │ NavAction(request.URL)
                ▼
       ┌─────────────────────────────────────────────────────────┐
       │ Classify redirect URL                                   │
       │ - msauth://enroll                                       │
       │ - msauth://compliance                                   │
       │ - msauth://in_app_enrollement_complete                  │
       └─────────────────────────────────────────────────────────┘
          │                            │                         │
          │                            │                         │
          ▼                            ▼                         ▼
   msauth://enroll              msauth://compliance   msauth://in_app_enrollement_complete
          │                            │                         │
          │ Cancel                     │ Cancel                  │ Allow
          ▼                            ▼                         ▼
┌───────────────────────────┐  ┌───────────────────────────┐  ┌──────────────────────────────┐
│ OnboardingOrchestrator     │  │ OnboardingOrchestrator     │  │ Propagate to response-object │
│ (delegate/controller)      │  │ (delegate/controller)      │  │ parsing/handling pipeline    │
└───────────────────────────┘  └───────────────────────────┘  └──────────────────────────────┘
          │                            │
          └───────────────┬────────────┘
                          │
                          │ Extract instruction parameters from URL query
                          │ (e.g., target URL, required params, header keys)
                          ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ BRT Guard: "once per redirect instruction"                                   │
│ - if already acquired for this instruction: skip                             │
│ - else: acquire BRT (and cache for this instruction)                         │
└──────────────────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ Build nextRequest                                                           │
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

#### A2. NavResponse Header Telemetry + Header-Driven ASWebAuth Handoff (Resume Same WKWebView)

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ EmbeddedWebviewController (same WKWebView instance throughout)                │
└──────────────────────────────────────────────────────────────────────────────┘
                │
                │ NavResponse(response.headers)
                ▼
       ┌───────────────────────────┐
       │ Telemetry extraction       │
       │ (read/record headers)      │
       └───────────────────────────┘
                │
                ▼
       ┌───────────────────────────┐
       │ Detect ASWebAuth handoff?  │ (strictly header-driven)
       └───────────────────────────┘
          │                 │
          │ No              │ Yes
          ▼                 ▼
        Allow        ┌──────────────────────────────────────────┐
                     │ Suspend embedded flow (do NOT destroy     │
                     │ WKWebView; pause UI/navigation as needed) │
                     └──────────────────────────────────────────┘
                                     │
                                     ▼
                     ┌──────────────────────────────────────────┐
                     │ Launch ASWebAuthenticationSession         │
                     │ - startURL derived from headers           │
                     │ - callbackURL scheme can be anything      │
                     └──────────────────────────────────────────┘
                                     │
                                     ▼
                     ┌─────────────────────────────────────────────────────────┐
                     │ ASWebAuth completes → callbackURL                       │
                     └─────────────────────────────────────────────────────────┘
                                     │
                                     ▼
                     ┌─────────────────────────────────────────────────────────┐
                     │ Resume SAME embedded WKWebView session                  │
                     │ - webView.load(callbackURL request)                     │
                     │ - if callbackURL is msauth://in_app_enrollement_complete│
                     │   allow propagation to response-object parsing           │
                     │ - continue normal embedded navigation                    │
                     └─────────────────────────────────────────────────────────┘
                                     │
                                     ▼
                                    Allow
```

---

### Approach B: Response-Object / Factory-Driven Orchestration (Completion-Time)

> Note: This approach is shown for comparison. The diagrams highlight where extra plumbing is required to
> preserve timing and “same WKWebView resume” semantics.

#### B1. Redirect URLs routed through completion/factory

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ EmbeddedWebviewController                                                     │
└──────────────────────────────────────────────────────────────────────────────┘
                │
                │ NavAction(request.URL)
                ▼
       ┌───────────────────────────┐
       │ Observe special redirect?  │
       └───────────────────────────┘
          │                 │
          │ No              │ Yes (`msauth://enroll` / `msauth://compliance`)
          ▼                 ▼
        Allow        ┌──────────────────────────────────────────┐
                     │ Forward to completion pipeline            │
                     │ - must carry URL + enough context         │
                     │ - (and often needs header/context too)    │
                     └──────────────────────────────────────────┘
                                     │
                                     ▼
                     ┌──────────────────────────────────────────┐
                     │ Factory creates Response object           │
                     │ - EnrollResponse / ComplianceResponse     │
                     └──────────────────────────────────────────┘
                                     │
                                     ▼
                     ┌──────────────────────────────────────────┐
                     │ LocalController handles response          │
                     └──────────────────────────────────────────┘
                                     │
                                     ▼
                     ┌──────────────────────────────────────────┐
                     │ BRT guard + acquisition                  │
                     │ (once per redirect instruction)          │
                     └──────────────────────────────────────────┘
                                     │
                                     ▼
                     ┌──────────────────────────────────────────┐
                     │ Build nextRequest                        │
                     └──────────────────────────────────────────┘
                                     │
                                     ▼
                     ┌──────────────────────────────────────────┐
                     │ Resume SAME embedded WKWebView           │
                     │ - webView.load(nextRequest)              │
                     └──────────────────────────────────────────┘
```

#### B2. Header-driven ASWebAuth (requires explicit header propagation)

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ EmbeddedWebviewController                                                     │
└──────────────────────────────────────────────────────────────────────────────┘
                │
                │ NavResponse(response.headers)
                ▼
       ┌───────────────────────────┐
       │ Telemetry + detect handoff │
       └───────────────────────────┘
                │
                │ (To be response-object-driven, must forward headers + context)
                ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ Factory creates ASWebAuthRequiredResponse                                     │
│ - requires headers + startURL extraction + correlation context                │
└──────────────────────────────────────────────────────────────────────────────┘
                │
                ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ Operation launches ASWebAuthenticationSession                                 │
└──────────────────────────────────────────────────────────────────────────────┘
                │
                ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ Operation returns callbackURL                                                 │
└──────────────────────────────────────────────────────────────────────────────┘
                │
                ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ Resume SAME embedded WKWebView session                                        │
│ - webView.load(callbackURL request)                                           │
│ - callback (`msauth://in_app_enrollement_complete`) propagates to response    │
│   parsing/handling                                                             │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

### Diagram Notes / Design Implications

- Approach A mirrors the existing **PKeyAuth** “cancel → handle → loadRequest” pattern, which is inherently
  navigation-time and preserves the same WKWebView session.
- For Mobile Onboarding, only `msauth://enroll` and `msauth://compliance` are interception URLs at NavAction.
- `msauth://in_app_enrollement_complete` is the completion callback and must be allowed to flow through to
  response-object handling/parsing instead of being intercepted at navigation-time.
- Header telemetry and ASWebAuth handoff detection happen in NavResponse; after ASWebAuth completion, resuming
  the same embedded WKWebView is done by loading the returned callback URL.
