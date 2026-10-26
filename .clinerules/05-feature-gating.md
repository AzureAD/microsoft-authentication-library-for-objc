# Feature Gating with MSIDFlightManager

## Overview

This document provides guidance for AI agents on implementing feature flags in the Microsoft Authentication Library (MSAL) for iOS and macOS using `MSIDFlightManager`. Feature flags enable controlled rollout of new features and A/B testing capabilities.

## Important Limitations

⚠️ **CRITICAL: Microsoft Internal Use Only**

The `MSIDFlightManager` feature flag system is **ONLY available in broker context** or when the broker returns flight configurations as part of its response. This is a Microsoft-internal mechanism and is **NOT accessible to third-party developers**.

### Broker Context Requirement

- Feature flags are **only available** when:
  1. The application is running inside the Microsoft Authenticator or Company Portal broker
  2. The broker explicitly returns flight configurations in its authentication response
  
- **Third-party developers must NOT rely on this system** for their applications
- Third-party developers should implement their own feature flag provider if needed

### Third-Party Developer Guidance

If you are a third-party developer:

- ✅ Implement your own feature flag system using:
  - Remote configuration services (for example: Azure App Configuration)
  - Custom backend configuration endpoints
  - Local configuration files with remote updates

## MSIDFlightManager Architecture

### Location

`MSIDFlightManager` is part of the **IdentityCore** common library:

```
MSAL/IdentityCore/IdentityCore/src/MSIDFlightManager.h
MSAL/IdentityCore/IdentityCore/src/MSIDFlightManager.m
```

### Key Characteristics

- **Singleton pattern**: Accessed via `[MSIDFlightManager sharedInstance]`
- **Thread-safe**: Uses `dispatch_once` for initialization
- **Broker-dependent**: Only populated with data from broker responses
- **Read-only for MSAL**: MSAL code reads flags, broker sets them

## When to Use Feature Flags

Feature flags should be used for:

1. **New Features**: Gradual rollout of new functionality
2. **Breaking Changes**: Safe migration paths with fallback behavior
3. **A/B Testing**: Testing different implementation approaches
4. **Risk Mitigation**: Ability to quickly disable problematic features
5. **Platform-Specific Behavior**: Different behavior for iOS vs macOS vs visionOS

Feature flags should **NOT** be used for:

- Permanent configuration options (use config classes instead)
- User-facing preferences (use proper settings)
- Build-time configurations (use compiler flags)
- Debug-only features (use `#if DEBUG`)

## Implementation Pattern

### Step 1: Define the Feature Flag Key

Feature flag keys should follow naming conventions:

```objc
// In MSIDFlightManager.h or appropriate header
static NSString * const MSIDFlightKeyNewAuthFlow = @"new_auth_flow";
static NSString * const MSIDFlightKeyEnhancedTokenCache = @"enhanced_token_cache";
static NSString * const MSIDFlightKeyNativeAuthV2 = @"native_auth_v2";
```

**Naming Convention:**

- Use snake_case for flag keys
- Prefix with feature area if applicable
- Keep names descriptive but concise
- Document in code comments

### Step 2: Check Feature Flag in Code

Always provide a default fallback behavior when feature flag is not available:

```objc
// Example: Checking if new feature is enabled
BOOL isNewAuthFlowEnabled = [[MSIDFlightManager sharedInstance] 
                             isFlightEnabled:MSIDFlightKeyNewAuthFlow];

if (isNewAuthFlowEnabled)
{
    // New implementation
    [self performNewAuthenticationFlow];
}
else
{
    // Existing/fallback implementation
    [self performLegacyAuthenticationFlow];
}
```

### Step 3: Handle Missing/Default State

**CRITICAL**: Always assume feature flags may be unavailable (nil or NO):

```objc
- (void)performOperationWithContext:(id<MSIDRequestContext>)context
{
    // Default to NO/false if flag is not set by broker
    BOOL useEnhancedCache = [[MSIDFlightManager sharedInstance] 
                             isFlightEnabled:MSIDFlightKeyEnhancedTokenCache];
    
    if (useEnhancedCache)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, 
                          @"Using enhanced token cache (feature flag enabled)");
        [self useEnhancedTokenCache];
    }
    else
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, 
                          @"Using standard token cache (feature flag disabled or unavailable)");
        [self useStandardTokenCache];
    }
}
```

### Step 4: Add Logging

Always log feature flag decisions for debugging:

```objc
BOOL isFeatureEnabled = [[MSIDFlightManager sharedInstance] 
                         isFlightEnabled:MSIDFlightKeyNewFeature];

MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, context, 
                      @"Feature 'new_feature' is %@", 
                      isFeatureEnabled ? @"ENABLED" : @"DISABLED");
```

## Common Patterns

### Pattern 1: Simple On/Off Toggle

```objc
- (void)processAuthenticationWithParameters:(MSALTokenParameters *)parameters
                                      error:(NSError **)error
{
    BOOL useNewFlow = [[MSIDFlightManager sharedInstance] 
                       isFlightEnabled:@"new_auth_flow"];
    
    if (useNewFlow)
    {
        return [self processAuthenticationNewFlow:parameters error:error];
    }
    else
    {
        return [self processAuthenticationLegacyFlow:parameters error:error];
    }
}
```

### Pattern 2: Platform-Specific Feature Flags

```objc
- (void)configureWebView:(WKWebView *)webView
{
    #if TARGET_OS_IOS
    BOOL useEnhancedWebView = [[MSIDFlightManager sharedInstance] 
                               isFlightEnabled:@"enhanced_webview_ios"];
    #elif TARGET_OS_OSX
    BOOL useEnhancedWebView = [[MSIDFlightManager sharedInstance] 
                               isFlightEnabled:@"enhanced_webview_macos"];
    #else
    BOOL useEnhancedWebView = NO;
    #endif
    
    if (useEnhancedWebView)
    {
        [self configureEnhancedWebView:webView];
    }
    else
    {
        [self configureStandardWebView:webView];
    }
}
```

### Pattern 3: Multiple Flag Combinations

```objc
- (void)performAdvancedOperation
{
    BOOL featureA = [[MSIDFlightManager sharedInstance] isFlightEnabled:@"feature_a"];
    BOOL featureB = [[MSIDFlightManager sharedInstance] isFlightEnabled:@"feature_b"];
    
    if (featureA && featureB)
    {
        // Both features enabled
        [self performOperationWithBothFeatures];
    }
    else if (featureA)
    {
        // Only feature A enabled
        [self performOperationWithFeatureA];
    }
    else if (featureB)
    {
        // Only feature B enabled
        [self performOperationWithFeatureB];
    }
    else
    {
        // Neither feature enabled - use baseline
        [self performBaselineOperation];
    }
}
```

## Best Practices

### 1. Always Provide Fallback

```objc
// ✅ GOOD: Has clear fallback
BOOL useNewFeature = [[MSIDFlightManager sharedInstance] 
                      isFlightEnabled:@"new_feature"];
if (useNewFeature)
{
    [self useNewImplementation];
}
else
{
    [self useStableImplementation];  // Clear fallback
}

// ❌ BAD: Assumes flag will always be available
if ([[MSIDFlightManager sharedInstance] isFlightEnabled:@"new_feature"])
{
    [self useNewImplementation];
}
// What happens if flag is NO or unavailable?
```

### 2. Document Flag Dependencies

```objc
/**
 Performs token acquisition with optional enhanced caching.
 
 @param parameters Token acquisition parameters
 @param error Error if operation fails
 
 @return MSALResult on success, nil on failure
 
 @note This method uses the 'enhanced_token_cache' feature flag when
       available in broker context. Falls back to standard caching
       when flag is disabled or unavailable.
 */
- (MSALResult *)acquireTokenWithParameters:(MSALTokenParameters *)parameters
                                     error:(NSError **)error;
```

### 3. Log Feature Flag State

```objc
- (void)performOperation
{
    BOOL featureEnabled = [[MSIDFlightManager sharedInstance] 
                           isFlightEnabled:@"my_feature"];
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, 
                      @"Feature 'my_feature' state: %@", 
                      featureEnabled ? @"ENABLED" : @"DISABLED");
    
    // ... rest of implementation
}
```

### 4. Plan for Removal

Feature flags should be temporary. Document removal plan:

```objc
/**
 TODO: Remove feature flag check after Q2 2025 rollout
 
 Feature flag: 'new_auth_flow'
 Rollout started: 2024-Q4
 Expected completion: 2025-Q2
 Tracking: https://example.com/feature/new-auth-flow
 
 Once rollout is complete, remove the flag check and keep only
 the new implementation.
 */
BOOL useNewAuthFlow = [[MSIDFlightManager sharedInstance] 
                       isFlightEnabled:@"new_auth_flow"];
```

### 5. Avoid Deep Nesting

```objc
// ❌ BAD: Too many nested feature flags
if ([[MSIDFlightManager sharedInstance] isFlightEnabled:@"feature_a"])
{
    if ([[MSIDFlightManager sharedInstance] isFlightEnabled:@"feature_b"])
    {
        if ([[MSIDFlightManager sharedInstance] isFlightEnabled:@"feature_c"])
        {
            // Complex logic here
        }
    }
}

// ✅ GOOD: Extract to separate method with clear logic
BOOL featureA = [[MSIDFlightManager sharedInstance] isFlightEnabled:@"feature_a"];
BOOL featureB = [[MSIDFlightManager sharedInstance] isFlightEnabled:@"feature_b"];
BOOL featureC = [[MSIDFlightManager sharedInstance] isFlightEnabled:@"feature_c"];

[self performOperationWithFeatureA:featureA 
                          featureB:featureB 
                          featureC:featureC];
```

### 6. Consider Performance

```objc
// ✅ GOOD: Cache flag value if checked multiple times
- (void)performMultipleOperations
{
    // Check once and cache
    BOOL useOptimization = [[MSIDFlightManager sharedInstance] 
                            isFlightEnabled:@"optimization"];
    
    [self operation1WithOptimization:useOptimization];
    [self operation2WithOptimization:useOptimization];
    [self operation3WithOptimization:useOptimization];
}

// ❌ LESS EFFICIENT: Checking same flag multiple times
- (void)performMultipleOperations
{
    [self operation1WithOptimization:[[MSIDFlightManager sharedInstance] 
                                      isFlightEnabled:@"optimization"]];
    [self operation2WithOptimization:[[MSIDFlightManager sharedInstance] 
                                      isFlightEnabled:@"optimization"]];
    [self operation3WithOptimization:[[MSIDFlightManager sharedInstance] 
                                      isFlightEnabled:@"optimization"]];
}
```

## Error Handling with Feature Flags

```objc
- (BOOL)performOperationWithError:(NSError **)error
{
    BOOL useNewImplementation = [[MSIDFlightManager sharedInstance] 
                                 isFlightEnabled:@"new_implementation"];
    
    if (useNewImplementation)
    {
        NSError *internalError = nil;
        BOOL result = [self performNewImplementationWithError:&internalError];
        
        if (!result)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, 
                              @"New implementation failed, falling back: %@", 
                              internalError);
            
            // Optional: Fall back to old implementation on failure
            result = [self performLegacyImplementationWithError:&internalError];
        }
        
        if (!result && error)
        {
            *error = internalError;
        }
        
        return result;
    }
    else
    {
        return [self performLegacyImplementationWithError:error];
    }
}
```

## Example: Adding a New Feature with Flag

Here's a complete example of adding a new feature behind a feature flag:

```objc
// 1. Define the flag key constant
static NSString * const MSIDFlightKeyEnhancedErrorReporting = @"enhanced_error_reporting";

// 2. Implement the feature-flagged method
- (void)reportError:(NSError *)error 
        withContext:(id<MSIDRequestContext>)context
{
    // Check feature flag
    BOOL useEnhancedReporting = [[MSIDFlightManager sharedInstance] 
                                 isFlightEnabled:MSIDFlightKeyEnhancedErrorReporting];
    
    // Log the decision
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, 
                      @"Enhanced error reporting: %@", 
                      useEnhancedReporting ? @"ENABLED" : @"DISABLED");
    
    if (useEnhancedReporting)
    {
        // New enhanced reporting
        [self reportErrorEnhanced:error withContext:context];
    }
    else
    {
        // Existing stable reporting
        [self reportErrorLegacy:error withContext:context];
    }
}

// 3. Implement both code paths
- (void)reportErrorEnhanced:(NSError *)error 
                withContext:(id<MSIDRequestContext>)context
{
    // New implementation with additional telemetry, diagnostics, etc.
    MSID_LOG_WITH_CTX(MSIDLogLevelError, context, 
                      @"Enhanced error report: %@ (domain: %@, code: %ld)", 
                      error.localizedDescription, 
                      error.domain, 
                      (long)error.code);
    
    // Additional enhanced reporting logic
    [self collectDiagnostics:error];
    [self sendTelemetryForError:error];
}

- (void)reportErrorLegacy:(NSError *)error 
              withContext:(id<MSIDRequestContext>)context
{
    // Existing stable implementation
    MSID_LOG_WITH_CTX(MSIDLogLevelError, context, 
                      @"Error: %@", error.localizedDescription);
}
```

## Checklist for Adding Feature Flags

When implementing a new feature behind a feature flag:

- [ ] Define clear, descriptive flag key constant
- [ ] Implement both new and fallback code paths
- [ ] Add logging for feature flag state
- [ ] Handle nil/NO case gracefully (default to stable behavior)
- [ ] Write unit tests for both enabled and disabled states
- [ ] Document the feature flag in code comments
- [ ] Add telemetry/metrics if appropriate
- [ ] Plan for eventual flag removal (add TODO with timeline)
- [ ] Verify behavior when broker context is unavailable
- [ ] Test in real broker context (Microsoft Authenticator/Company Portal)

## Summary

**Key Takeaways for AI Agents:**

1. ✅ **Use feature flags for gradual rollout** of new features
2. ✅ **Always provide stable fallback** behavior
3. ✅ **Remember: Only works in broker context** - not for third-party apps
4. ✅ **Log feature flag decisions** for debugging
5. ✅ **Test both enabled and disabled states**
6. ✅ **Plan for eventual removal** of feature flags
7. ✅ **Document flag dependencies** in code comments
8. ❌ **Don't use for permanent configuration**
9. ❌ **Don't assume flags will always be available**
10. ❌ **Don't leave flags in code indefinitely**

## Related Documentation

- `.clinerules/04-Code-style-guidelines.md` - Code style requirements
- `MSAL/IdentityCore/IdentityCore/src/MSIDFlightManager.h` - Flight manager API
- Microsoft internal documentation for broker flight configuration

## Questions?

For questions about feature flag implementation:

- **Microsoft employees**: Contact MSAL iOS team or check internal documentation
- **Third-party developers**: Implement your own feature flag system 
