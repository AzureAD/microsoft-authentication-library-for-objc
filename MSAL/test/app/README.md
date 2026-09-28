# MSAL Test Apps

The iOS and macOS test apps use SwiftUI for their user-facing Acquire, configuration, cache, and diagnostics surfaces. The existing Objective-C controllers remain as execution adapters for MSAL, cache mutation, and platform presentation; the iOS custom `WKWebView` is the same instance passed to MSAL. The visionOS app and separate automation action infrastructure are unchanged.

Choose a built-in profile or **Custom**. Custom client ID (UUID) and redirect URI are held only in memory; switching to a built-in profile restores its unchanged values. Scope input accepts space- or comma-separated permission names and resource scopes. Invalid input is shown before authentication. Account and login hint remain independently selected.

Cache detail views are local diagnostics and can contain credentials. Do not share their contents or screenshots. The iOS log view excludes messages marked as PII; neither app writes token or account results to console logs.

**Configuration presets** fill inputs; they never start authentication, sign out, or clear data, and never replace the selected profile, account, login hint, custom client ID, or redirect URI. Their source references appear in the UI:

| Platform | Configuration | Source |
| --- | --- | --- |
| iOS | Graph `.default`, authority validation off, device claim | 3417083 steps 7/9/13; 3417086 steps 14/16/27–30 |
| iOS | Graph `.default`, authority validation off, no device claim | 3417083 step 8 |
| iOS | Microsoft Online Graph scope, validation on, instance awareness off, default prompt | 3417091 steps 3/10; choose the tenant authority manually |
| iOS | China Graph scope and China authority, validation on, instance awareness off, default prompt | 3417091 steps 6–7 |
| iOS | Validation on, ATS thread starvation enabled | 3447106 steps 5/10–13 |
| macOS | Graph `.default`, authority validation on | 3417082 steps 15–20 |

Case 3417087 covers Safari/SSO-extension and WPJ operations, not MSAL app inputs, so it has no preset. Installing apps, enrollment, cookie/keychain cleanup, browser navigation, selecting a real account, and the 3447106 source-level starvation-duration change remain manual.

Build using `MSAL.xcworkspace` through `build.py`. For unsigned simulator builds, set `CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO` and choose an installed simulator with `IOS_SIM_DEVICE` and `IOS_SIM_OS`.
