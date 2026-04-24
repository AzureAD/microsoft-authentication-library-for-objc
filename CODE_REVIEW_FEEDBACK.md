# Code Review Feedback: ameyapat/add-get-device-token-api vs dev

**Reviewed:** 2026-04-24
**Branch:** `ameyapat/add-get-device-token-api`
**Reviewer:** Automated Code Review Agent

---

## Summary

This PR adds a new Device Token API to MSAL, allowing applications to request access tokens associated with a device (not a user). The feature includes:
- `MSALDeviceTokenParameters` — public parameters class
- `MSALDeviceTokenResult` — result class for device token responses
- `getDeviceTokenWithParameters:completionBlock:` — public API on `MSALPublicClientApplication`
- `getDeviceTokenForSharedDeviceWithResource:scopes:completionBlock:` — convenience API for shared devices
- Submodule changes: `MSIDDeviceTokenGrantRequest`, `MSIDDeviceTokenResponseHandler`

**Findings: 3 Warnings, 8 Suggestions**

---

## Warnings

### W1: `getDeviceTokenForSharedDeviceWithResource:` will always fail — nil tenantId rejected

**File:** `MSAL/src/MSALPublicClientApplication.m` (lines ~1597-1600, ~1647-1651)
**Issue:** `getDeviceTokenForSharedDeviceWithResource:` creates `MSALDeviceTokenParameters` with nil `tenantId` (comment says: "Initializing parameters with nil tenantId to get device token for primary registration"). However, `getDeviceTokenWithParameters:` explicitly rejects nil `tenantId`:
```objc
if (!parameters.tenantId)
{
    block(nil, MSIDCreateError(..., @"tenantId is required to get device token", ...), nil);
    return;
}
```
Additionally, even if the nil check were bypassed, `MSALDeviceInfoProvider.deviceTokenWithRequestParameters:` builds the endpoint URL as:
```objc
[NSString stringWithFormat:@"https://login.microsoftonline.com/%@/oauth2/token", tenantId]
```
With nil `tenantId`, this produces `https://login.microsoftonline.com/(null)/oauth2/token`.

**Impact:** The shared device convenience API is dead code — it will always fail with "tenantId is required" error. The entire `getDeviceTokenForSharedDeviceWithResource:` code path is untestable.

**Recommendation:** If the intent is to use the primary device registration when no tenantId is provided, `getDeviceTokenWithParameters:` should resolve the primary tenant ID from WPJ registration before the nil check, or the nil check should be removed and the device info provider should handle lookup of primary registration. Example:
```objc
// Instead of rejecting nil tenantId, resolve primary registration
NSString *effectiveTenantId = parameters.tenantId;
if (!effectiveTenantId)
{
    effectiveTenantId = [MSIDWorkPlaceJoinUtil getPrimaryTenantId];
}
```

---

### W2: Hardcoded endpoint URL won't work for sovereign clouds

**File:** `MSAL/src/instance/MSALDeviceInfoProvider.m` (line ~169)
**Issue:** The token endpoint URL is hardcoded:
```objc
NSURL *endpoint = [[NSURL alloc] initWithString:
    [NSString stringWithFormat:@"https://login.microsoftonline.com/%@/oauth2/token", tenantId]];
```

**Impact:** This will fail for sovereign cloud deployments (Azure China: `login.chinacloudapi.cn`, Azure Government: `login.microsoftonline.us`, etc.). The authority base URL should be derived from `requestParameters.authority` which already carries the correct cloud instance.

**Recommendation:** Derive the endpoint from the request parameters authority:
```objc
NSURL *authorityURL = requestParameters.authority.url;
NSURL *endpoint = [authorityURL URLByAppendingPathComponent:@"oauth2/token"];
```

---

### W3: `MSALDeviceTokenParameters.tenantId` nullability mismatch

**File:** `MSAL/src/public/MSALDeviceTokenParameters.h` (line 39)
**Issue:** Inside `NS_ASSUME_NONNULL_BEGIN`, the property is declared as:
```objc
@property (nonatomic, readonly) NSString *tenantId;
```
This makes `tenantId` implicitly `nonnull`. However, the initializer accepts `nullable NSString *` for `tenantId`, and the shared device flow intentionally passes `nil`. The nonnull contract is violated at runtime.

**Impact:** Callers relying on the nullability annotation may skip nil checks, leading to unexpected behavior. The compiler may also optimize based on assumed non-nil.

**Recommendation:** Add explicit `nullable` annotation:
```objc
@property (nonatomic, readonly, nullable) NSString *tenantId;
```

---

## Suggestions

### S1: Duplicate result conversion logic — `MSALResult.resultForDeviceTokenResult:authority:error:` is unused

**File:** `MSAL/src/MSALResult.m` (lines 170-228), `MSAL/src/MSALResult+Internal.h` (lines 45-47)
**Issue:** Two separate methods exist to convert `MSIDTokenResult` to `MSALDeviceTokenResult`:
1. `[MSALDeviceTokenResult resultForDeviceTokenResult:error:]` in `MSALDeviceTokenResult.m` (used by `MSALPublicClientApplication.m`)
2. `[MSALResult resultForDeviceTokenResult:authority:error:]` in `MSALResult.m` (declared in `MSALResult+Internal.h`, **never called**)

**Impact:** Dead code increases maintenance burden and creates confusion about which method is canonical. The `MSALResult` version also creates an unnecessary intermediate `MSALResult` object.

**Recommendation:** Remove the unused `MSALResult` category method and its declaration in `MSALResult+Internal.h`.

---

### S2: Public headers not added to umbrella header `MSAL.h`

**File:** `MSAL/src/public/MSAL.h`
**Issue:** `MSALDeviceTokenParameters.h` is in `MSAL/src/public/` but is NOT imported in the umbrella header `MSAL.h`. The `MSALDeviceTokenResult.h` header is in `MSAL/src/` (not under `public/`) despite being referenced by the public `MSALDeviceTokenResultCompletionBlock` typedef in `MSALDefinitions.h`.

**Impact:** Framework consumers using `@import MSAL;` or `#import <MSAL/MSAL.h>` won't have access to `MSALDeviceTokenParameters`. The `MSALDeviceTokenResult` type in the public completion block typedef will be an incomplete type.

**Recommendation:**
1. Add `#import <MSAL/MSALDeviceTokenParameters.h>` to `MSAL.h`
2. Move `MSALDeviceTokenResult.h` to `MSAL/src/public/` and add it to `MSAL.h`

---

### S3: Missing error propagation when access token is absent

**File:** `MSAL/src/MSALDeviceTokenResult.m` (lines 82-86)
**Issue:** When the access token is missing/blank, the method returns nil without filling the `error` out-parameter:
```objc
else
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"[Device Token] Access token missing in token result");
    return nil;  // error is not filled
}
```

**Impact:** Callers get nil result AND nil error, making it impossible to diagnose the failure.

**Recommendation:** Fill the error parameter before returning:
```objc
else
{
    MSIDFillAndLogError(error, MSIDErrorServerInvalidResponse, @"Access token missing in device token result", nil);
    return nil;
}
```

---

### S4: Unnecessary `@protocol MSIDCacheAccessor` forward declaration in public header

**File:** `MSAL/src/public/MSALDeviceTokenParameters.h` (line 28)
**Issue:** `@protocol MSIDCacheAccessor;` is forward-declared but never used in the header.

**Impact:** Leaks an internal protocol name into the public API surface.

**Recommendation:** Remove the `@protocol MSIDCacheAccessor;` forward declaration.

---

### S5: Missing unit tests

**Files:** `MSAL/test/unit/`
**Issue:** No unit tests were added for the new device token API. No test files matching `*DeviceToken*` exist.

**Impact:** No automated verification of the new API's behavior, error handling, or edge cases.

**Recommendation:** Add unit tests covering:
- `MSALDeviceTokenParameters` initialization (valid, nil resource, nil tenantId)
- `MSALDeviceTokenResult` conversion (success, nil result, missing access token, unexpected refresh/id tokens)
- `getDeviceTokenWithParameters:` parameter validation
- `getDeviceTokenForSharedDeviceWithResource:` shared device mode check

---

### S6 (Submodule): Type mismatch between header and implementation in `MSIDDeviceTokenGrantRequest`

**File:** `IdentityCore/src/requests/MSIDDeviceTokenGrantRequest.h` vs `.m`
**Issue:** The header declares:
```objc
@property (nonatomic, readonly) MSIDWPJKeyPairWithCert *wpjInfo;
- (instancetype)initWithEndpoint:...registrationInformation:(nonnull MSIDWPJKeyPairWithCert *)registrationInformation...
```
But the `.m` class extension redeclares:
```objc
@property (nonatomic) MSIDRegistrationInformation *wpjInfo;
- (instancetype)initWithEndpoint:...registrationInformation:(MSIDRegistrationInformation *)registrationInformation...
```

**Impact:** Type mismatch between public declaration and private extension. If `MSIDWPJKeyPairWithCert` is not related to `MSIDRegistrationInformation`, this causes implicit unsafe casts. At line 226, `self.wpjInfo` returns `MSIDRegistrationInformation *` but is assigned to `MSIDWPJKeyPairWithCert *`.

**Recommendation:** The `.m` should use `MSIDWPJKeyPairWithCert *` consistently to match the header.

---

### S7 (Submodule): Missing braces on conditional in `MSIDDeviceTokenGrantRequest.m`

**File:** `IdentityCore/src/requests/MSIDDeviceTokenGrantRequest.m` (line ~269)
**Issue:** Code style violation — single-line conditional without braces:
```objc
if (error)
    *error = MSIDCreateError(...);
```

**Impact:** Violates the MSAL/IdentityCore code style guideline: "MUST always use braces for conditional bodies, even for single-line statements."

**Recommendation:**
```objc
if (error)
{
    *error = MSIDCreateError(...);
}
```

---

### S8 (Submodule): Unused `tokenResponseError` variable in `MSIDDeviceTokenGrantRequest.m`

**File:** `IdentityCore/src/requests/MSIDDeviceTokenGrantRequest.m` (line ~205)
**Issue:** `NSError *tokenResponseError;` is declared but never assigned. It's passed as nil to `handleTokenResponse:context:error:completionBlock:`.

**Impact:** Dead variable. Can be replaced with `nil` directly for clarity.

**Recommendation:**
```objc
[tokenResponseHandler handleTokenResponse:tokenJsonResponse
                                  context:self.requestParameters
                                    error:nil
                          completionBlock:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
    completionBlock(result, error);
}];
```

---

## Code Style (applied as fixes)

- Removed unnecessary `@protocol MSIDCacheAccessor` import from `MSALDeviceTokenParameters.m` (internal type in public-facing implementation)

---

## Credential & Sensitive Data Scan

**Result: PASS** — No credentials, tokens, PII, or sensitive data found in the diff.
