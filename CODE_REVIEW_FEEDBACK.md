# Code Review Feedback: ameyapat/add-get-device-token-api vs dev

**Reviewer:** Automated Code Review Agent  
**Date:** 2026-04-24  
**Branch:** `ameyapat/add-get-device-token-api`  
**Files changed:** 12 (main repo) + 9 (IdentityCore submodule, relevant to feature)

---

## Critical Issues

### 1. [Critical] `getDeviceTokenForSharedDeviceWithResource` always fails — nil tenantId rejected by init

**File:** `MSAL/src/MSALPublicClientApplication.m` (lines ~1600-1604)  
**Issue:** `getDeviceTokenForSharedDeviceWithResource:scopes:completionBlock:` creates `MSALDeviceTokenParameters` with `forTenantId:nil`:
```objc
MSALDeviceTokenParameters *parameters = [[MSALDeviceTokenParameters alloc] initWithResource:resource
                                                                                     scopes:scopes
                                                                                forTenantId:nil];
```
But `MSALDeviceTokenParameters.initWithResource:scopes:forTenantId:` returns `nil` when tenantId is nil or blank:
```objc
if ([NSString msidIsStringNilOrBlank:tenantId] || [NSString msidIsStringNilOrBlank:resource])
{
    return nil;
}
```
This means `parameters` is always `nil`, so `getDeviceTokenWithParameters:` returns immediately with a generic error "Request parameters are required to get device token". The shared device flow is broken.

**Impact:** The public API `getDeviceTokenForSharedDeviceWithResource:` can never succeed. It is dead on arrival.

**Recommendation:** Either:
- (a) Remove the tenantId nil check from `MSALDeviceTokenParameters` init and handle nil tenantId downstream (resolve to primary registration), OR
- (b) Look up the primary registration's tenantId from `MSALDeviceInformation` and pass it to the init instead of nil.

---

### 2. [Critical] Original network error overwritten in completion block

**File:** `MSAL/src/MSALPublicClientApplication.m` (lines ~1664-1669)  
**Issue:**
```objc
[deviceInfoProvider deviceTokenWithRequestParameters:requestParams
                               deviceTokenParameters:parameters
                                     completionBlock:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error)
{
    MSALDeviceTokenResult *msalResult = [MSALDeviceTokenResult resultForDeviceTokenResult:result error:&error];
    block(msalResult, error, requestParams);
}];
```
When `result` is `nil` (network error), `error` contains the original network error. But `resultForDeviceTokenResult:error:` checks `!tokenResult` and calls `MSIDFillAndLogError(error, MSIDErrorInternal, @"Nil token result provided", nil)` — which **overwrites** the original, more informative network error with a generic "Nil token result provided".

**Impact:** Developers lose critical diagnostic information (HTTP status codes, server error descriptions) needed to debug token acquisition failures.

**Recommendation:** Guard the conversion call:
```objc
completionBlock:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error)
{
    if (!result)
    {
        block(nil, error, requestParams);
        return;
    }
    NSError *conversionError;
    MSALDeviceTokenResult *msalResult = [MSALDeviceTokenResult resultForDeviceTokenResult:result error:&conversionError];
    block(msalResult, conversionError ?: error, requestParams);
}];
```

---

### 3. [Critical] Missing imports in `MSALDeviceTokenResult.h`

**File:** `MSAL/src/MSALDeviceTokenResult.h`  
**Issue:** The header uses `NSObject`, `NSString`, `NSDate`, `NSArray` and references `MSALAuthority` and `MSIDTokenResult` without importing Foundation or forward-declaring these types.

**Impact:** Any file that imports this header without first importing Foundation or the MSAL umbrella header will get compile errors.

**Recommendation:** *(Applied)* Added `#import <Foundation/Foundation.h>` and forward declarations for `MSALAuthority` and `MSIDTokenResult`.

---

### 4. [Critical] Hardcoded `login.microsoftonline.com` URL breaks sovereign clouds

**File:** `MSAL/src/instance/MSALDeviceInfoProvider.m` (line ~170)  
**Issue:**
```objc
NSURL *endpoint = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"https://login.microsoftonline.com/%@/oauth2/token", tenantId]];
```
This hardcodes the public cloud authority. Sovereign cloud tenants (e.g., Azure Government `login.microsoftonline.us`, Azure China `login.partner.microsoftonline.cn`, Azure Germany) will always hit the wrong endpoint.

**Impact:** Device token acquisition fails for all non-public-cloud deployments.

**Recommendation:** Derive the endpoint from `requestParameters.authority` instead:
```objc
NSURL *authorityBaseURL = requestParameters.authority.url;
// Build endpoint from the authority's actual host
NSURL *endpoint = [authorityBaseURL URLByAppendingPathComponent:@"oauth2/token"];
```

---

## Warnings

### 5. [Warning] Duplicate import in `MSALDeviceInfoProvider.m`

**File:** `MSAL/src/instance/MSALDeviceInfoProvider.m` (lines 35-36)  
**Issue:** `#import "MSALDeviceTokenParameters.h"` appears twice.  
**Impact:** No functional impact (Obj-C import is idempotent) but indicates copy-paste error.  
**Recommendation:** *(Applied)* Removed the duplicate.

---

### 6. [Warning] Dead code — `MSALResult.resultForDeviceTokenResult:authority:error:` never called

**File:** `MSAL/src/MSALResult+Internal.h` (lines 45-47), `MSAL/src/MSALResult.m` (lines 170-227)  
**Issue:** A `resultForDeviceTokenResult:authority:error:` method is declared on `MSALResult+Internal.h` and implemented in `MSALResult.m`, but nothing calls it. The actual call site in `MSALPublicClientApplication.m` uses `[MSALDeviceTokenResult resultForDeviceTokenResult:error:]` instead.

Additionally, the `MSALResult+Internal.h` declaration returns `MSALResult *` but the implementation returns `MSALDeviceTokenResult *` — a type mismatch.

**Impact:** Dead code increases maintenance burden and confusion. The type mismatch between header and implementation is an Obj-C anti-pattern.

**Recommendation:** Remove the unused method from both `MSALResult+Internal.h` and `MSALResult.m`, and remove the `#import "MSALDeviceTokenResult.h"` added to `MSALResult.m`.

---

### 7. [Warning] New public header `MSALDeviceTokenParameters.h` not in umbrella header

**File:** `MSAL/src/public/MSALDeviceTokenParameters.h`  
**Issue:** Per project guidelines, all public headers in `MSAL/src/public/` must be imported in `MSAL/src/public/MSAL.h` (the umbrella header). `MSALDeviceTokenParameters.h` is missing from it.

**Impact:** Consumers using `#import <MSAL/MSAL.h>` or `@import MSAL;` won't have access to `MSALDeviceTokenParameters` without explicitly importing it.

**Recommendation:** Add `#import "MSALDeviceTokenParameters.h"` to `MSAL/src/public/MSAL.h`.

---

### 8. [Warning] `MSALDeviceTokenResult` exposed publicly via typedef but header not in public directory

**File:** `MSAL/src/MSALDeviceTokenResult.h`  
**Issue:** `MSALDeviceTokenResult` is forward-declared in the public `MSALDefinitions.h` and used as the result type of the public completion block `MSALDeviceTokenResultCompletionBlock`. However, the header is located in `MSAL/src/` (internal) rather than `MSAL/src/public/`.

**Impact:** Consumers receive `MSALDeviceTokenResult *` objects in completion blocks but cannot see the class's properties without an internal import.

**Recommendation:** Move `MSALDeviceTokenResult.h` to `MSAL/src/public/` and add it to the umbrella header.

---

### 9. [Warning] `MSALDeviceTokenResult.h` properties are `atomic` — inconsistent with codebase

**File:** `MSAL/src/MSALDeviceTokenResult.h`  
**Issue:** All properties are declared `atomic` (e.g., `@property (atomic, readonly, nonnull) NSString *accessToken`). Throughout the MSAL codebase, properties consistently use `nonatomic`.

**Impact:** `atomic` provides getter/setter atomicity but not thread safety for the object as a whole. It adds unnecessary overhead without meaningful safety benefit for a readonly result object.

**Recommendation:** Change to `nonatomic` to match codebase conventions.

---

### 10. [Warning] `MSALDeviceTokenParameters.h` tenantId nullability mismatch

**File:** `MSAL/src/public/MSALDeviceTokenParameters.h`  
**Issue:** The `tenantId` property is inside `NS_ASSUME_NONNULL_BEGIN`, making it implicitly `nonnull`:
```objc
@property (nonatomic, readonly) NSString *tenantId;  // implicitly nonnull
```
But the designated initializer accepts `nullable` tenantId:
```objc
- (instancetype)initWithResource:(NSString *)resource
                          scopes:(nullable NSArray<NSString *> *)scopes
                     forTenantId:(nullable NSString *)tenantId;
```

**Impact:** Callers see a nonnull property but can init with nil — the init returns nil in that case, making this a confusing API contract. This also directly causes Critical Issue #1.

**Recommendation:** Either mark the property `nullable` or document that the init returns nil when tenantId is nil. Given the shared device flow needs nil tenantId support, making it `nullable` is preferred.

---

### 11. [Warning] Unused import in `MSALDeviceTokenParameters.m`

**File:** `MSAL/src/MSALDeviceTokenParameters.m` (line 28)  
**Issue:** `#import "MSIDCacheAccessor.h"` is imported but nothing from that header is used.

**Impact:** Unnecessary compile-time dependency.

**Recommendation:** Remove the unused import.

---

### 12. [Warning] Parameter validation order suboptimal in `getDeviceTokenWithParameters:`

**File:** `MSAL/src/MSALPublicClientApplication.m`  
**Issue:** Expensive `MSIDRequestParameters` initialization happens before cheap nil checks for `tenantId` and `resource`. The nil checks should come first.

**Impact:** Unnecessary work when parameters are invalid.

**Recommendation:** Move the `tenantId` and `resource` nil checks to before the `MSIDRequestParameters` creation.

---

### 13. [Warning — Submodule] Missing braces in `MSIDDeviceTokenGrantRequest.m`

**File:** `IdentityCore/src/requests/MSIDDeviceTokenGrantRequest.m` (in `getTokenRedemptionJwtForResource:`)  
**Issue:**
```objc
if (error)
    *error = MSIDCreateError(MSIDErrorDomain, ...);
```
Per MSAL code style guidelines, braces are REQUIRED for all conditionals, even single-line bodies.

**Impact:** Code style violation; risk of dangling-else bugs in future modifications.

**Recommendation:**
```objc
if (error)
{
    *error = MSIDCreateError(MSIDErrorDomain, ...);
}
```

---

## Suggestions

### 14. [Suggestion] Missing unit tests

**Issue:** No unit test files were added or modified in `MSAL/test/unit/` for the new device token API.

**Impact:** New behavior is untested — regressions will not be caught by CI.

**Recommendation:** Add unit tests for:
- `MSALDeviceTokenParameters` init (valid inputs, nil tenantId, nil resource)
- `MSALDeviceTokenResult` init and `resultForDeviceTokenResult:` factory
- `getDeviceTokenWithParameters:` error paths
- `getDeviceTokenForSharedDeviceWithResource:` shared device mode check

---

### 15. [Suggestion] Log message parameter order inconsistency

**File:** `MSAL/src/instance/MSALDeviceInfoProvider.m`  
**Issue:** Error log on failure formats as `(error, tenantId)`:
```objc
@"Error acquiring device token for tenant Id: %@ %@", MSID_PII_LOG_MASKABLE(error), MSID_PII_LOG_MASKABLE(tenantId)
```
But success log formats as `(result, tenantId)`:
```objc
@"Successfully acquired device token for tenant Id: %@ %@", MSID_PII_LOG_MASKABLE(result), MSID_PII_LOG_MASKABLE(tenantId)
```
The error log's message text says "tenant Id:" but the first format arg is `error`, not `tenantId`.

**Impact:** Misleading log output during debugging.

**Recommendation:** Fix the log format string:
```objc
@"Error acquiring device token: %@, tenant Id: %@", MSID_PII_LOG_MASKABLE(error), MSID_PII_LOG_MASKABLE(tenantId)
```

---

## Summary

| Severity | Count |
|----------|-------|
| Critical | 4 |
| Warning  | 9 |
| Suggestion | 2 |
| **Total** | **15** |

### Fixes Applied in This PR
- Removed duplicate `#import "MSALDeviceTokenParameters.h"` in `MSALDeviceInfoProvider.m`
- Added missing `#import <Foundation/Foundation.h>` and forward declarations in `MSALDeviceTokenResult.h`
