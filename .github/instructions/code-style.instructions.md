---
description: "Use when: writing, editing, or reviewing Objective-C code. Enforces MSAL repository brace style, indentation, error handling, naming, and import conventions."
applyTo: ["**/*.m", "**/*.h", "**/*.mm"]
---

# MSAL Objective-C Code Style

## Braces on New Line (MANDATORY)

Opening braces MUST go on a **new line** — this is the repository convention and differs from most Obj-C style guides.

```objc
// CORRECT
- (void)doSomething
{
    if (condition)
    {
        // ...
    }
    else
    {
        // ...
    }
}

// WRONG — never put opening brace on same line
- (void)doSomething {
    if (condition) {
```

## Indentation

- 4 spaces, never tabs.

## Conditionals

MUST always use braces, even for single-line bodies:

```objc
// CORRECT
if (!result)
{
    return NO;
}

// WRONG
if (!result) return NO;
if (!result)
    return NO;
```

## Error Handling

Check **return value**, NEVER the error variable:

```objc
// CORRECT
NSError *error;
if (![self trySomethingWithError:&error])
{
    // Handle error
}

// WRONG
[self trySomethingWithError:&error];
if (error) { ... }
```

## Imports

Do NOT group imports with comments or pragma marks. List them plainly:

```objc
#import "MSALPublicClientApplication+Internal.h"
#import "MSALPromptType_Internal.h"
#import "MSALTelemetryApiId.h"
```

## Naming

- `MSAL` prefix for public classes and constants.
- `MSID` prefix for IdentityCore/shared internals.
- camelCase for properties and local variables.
- Underscore prefix (`_`) for instance variables.
- Pointer asterisk attached to variable name: `NSString *clientId`.

## Properties Over Ivars

Use `@property` declarations. Direct ivar access only in `init`, `dealloc`, and custom accessors.

## Method Signatures

Wrap long signatures at each parameter, aligned at the colon:

```objc
- (MSALResult *)resultWithTokenResult:(MSIDTokenResult *)result
                           authScheme:(id<MSALAuthenticationSchemeProtocol>)authScheme
                           popManager:(MSIDDevicePopManager *)popManager
                                error:(NSError **)error;
```
