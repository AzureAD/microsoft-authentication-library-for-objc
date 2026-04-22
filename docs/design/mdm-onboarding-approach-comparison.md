# Mobile Onboarding Approach Comparison

This document compares orchestration points for Mobile Onboarding and clarifies the required flow handling.

## Legend

- **NA** = `WKNavigationDelegate` navigation-action hook (`decidePolicyForNavigationAction`) before request execution
- **NR** = `WKNavigationDelegate` navigation-response hook (`decidePolicyForNavigationResponse`) after HTTP response receipt, before rendering
- **Guard** = per-session/per-instruction state check to prevent duplicate or invalid handling

## Hook Boundaries (NA vs NR)

```mermaid
flowchart TD
    Start[Embedded WKWebView session running]
    NA[NA hook: decidePolicyForNavigationAction]
    NR[NR hook: decidePolicyForNavigationResponse]

    Start --> NA
    Start --> NR

    NA --> NA1{URL is msauth://enroll or msauth://compliance?}
    NA1 -- Yes --> NA2[Cancel navigation]
    NA2 --> NA3{Guard: redirect instruction not handled yet?}
    NA3 -- Yes --> NA4[Acquire BRT once for this redirect instruction]
    NA3 -- No --> NA10[Skip duplicate handling; keep existing session state]
    NA4 --> NA5[Build final URL + required query params + headers]
    NA5 --> NA6[Load constructed request in SAME WKWebView]
    NA1 -- No --> NA7[Continue normal navigation]

    NA --> NA8{URL is msauth://enrollment_complete?}
    NA8 -- Yes --> NA9[Complete onboarding flow]
    NA8 -- No --> NA7

    NR --> NR1[Extract navigation-response header telemetry]
    NR1 --> NR2{Header requests ASWebAuthenticationSession handoff?}
    NR2 -- No --> NR3[Continue normal navigation]
    NR2 -- Yes --> NR4{Guard: handoff not already in progress?}
    NR4 -- Yes --> NR5[Cancel navigation]
    NR4 -- No --> NR9[Skip duplicate handoff; continue current session flow]
    NR5 --> NR6[Launch ASWebAuthenticationSession]
    NR6 --> NR7[Receive callback URL - any scheme]
    NR7 --> NR8[Load callback URL in SAME WKWebView to resume session]
```

## Redirect Interception and Resume (Navigation-Action)

```mermaid
sequenceDiagram
    participant Web as Embedded WKWebView
    participant NA as NA Hook
    participant Guard as Redirect Guard
    participant BRT as BRT Provider
    participant Builder as URL/Headers Builder

    Web->>NA: Request navigation
    NA->>NA: Match msauth://enroll or msauth://compliance
    NA-->>Web: Cancel current navigation
    NA->>Guard: Check instruction token/url not yet handled
    alt First time for this instruction
        Guard-->>NA: Allowed once per redirect instruction
        NA->>BRT: Acquire BRT
        BRT-->>NA: BRT token
        NA->>Builder: Add required query params + headers
        Builder-->>NA: Final URLRequest
        NA->>Web: loadRequest(final URLRequest) on SAME WKWebView
    else Duplicate instruction
        Guard-->>NA: Reject duplicate
        NA->>Web: Keep existing session flow (no duplicate BRT)
    end

    Web->>NA: Request navigation
    NA->>NA: Match msauth://enrollment_complete
    NA-->>Web: End onboarding path
```

## Header-Driven ASWebAuth Handoff and Resume (Navigation-Response)

```mermaid
sequenceDiagram
    participant Web as Embedded WKWebView
    participant NR as NR Hook
    participant Telemetry as Telemetry Extractor
    participant Guard as Handoff Guard
    participant ASWeb as ASWebAuthenticationSession

    Web->>NR: Receive HTTP response
    NR->>Telemetry: Extract navigation-response headers
    NR->>NR: Evaluate handoff header

    alt No handoff header
        NR-->>Web: Allow response/navigation
    else Handoff header present
        NR->>Guard: Ensure handoff is not already active
        alt Handoff not active
            Guard-->>NR: Allowed
            NR-->>Web: Cancel navigation
            NR->>ASWeb: Start with handoff URL
            ASWeb-->>NR: Callback URL (any scheme)
            NR->>Web: loadRequest(callback URL) on SAME WKWebView
        else Handoff already active
            Guard-->>NR: Reject duplicate
            NR-->>Web: Continue current session flow
        end
    end
```

## Conclusion and Recommendation

Keep the conclusion/recommendation unchanged: use **delegate/navigation-time orchestration (Approach A)** as the primary architecture for Mobile Onboarding.

- Use **navigation-action** interception for `msauth://enroll`, `msauth://compliance`, and `msauth://enrollment_complete` redirect handling.
- Use **navigation-response** handling for response-header telemetry extraction and header-driven `ASWebAuthenticationSession` handoff.
- Always resume by loading into the **same embedded `WKWebView` session** after BRT-based redirect handling or ASWebAuth callback.
