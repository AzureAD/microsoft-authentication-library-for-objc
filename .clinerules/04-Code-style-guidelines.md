# Objective-C Code Style Guidelines for AI Agents

## Overview

This document provides code style guidelines that AI agents MUST follow when working with this Objective-C codebase. These guidelines are adapted from industry best practices and tailored to match the existing code patterns in this repository.

## Key Principles

### RFC 2119 Compliance

- **MUST**: Absolute requirement
- **MUST NOT**: Absolute prohibition
- **SHOULD**: Recommended but may have valid reasons to ignore
- **SHOULD NOT**: Not recommended but may have valid reasons to use
- **MAY**: Optional

---

## Code Style Rules

### 0. Language

**MUST** use US English spelling for all identifiers, comments, and documentation.

```objc
// Correct
UIColor *myColor = [UIColor whiteColor];

// Incorrect
UIColor *myColour = [UIColor whiteColor];
```

### 1. Dot Notation Syntax

**RECOMMENDED:** Use dot notation for getting and setting properties.

```objc
// Preferred
view.backgroundColor = UIColor.orangeColor;
NSString *username = account.username;

// Avoid
[view setBackgroundColor:[UIColor orangeColor]];
NSString *username = [account username];
```

### 2. Spacing and Indentation

**MUST** follow these spacing rules:

- Indentation: 4 spaces (never tabs)
- **Opening braces on NEW line** (repository convention)
- Closing braces on new line
- One blank line between methods

```objc
// Correct (as used in this repository)
- (instancetype)initWithUsername:(NSString *)username
                   homeAccountId:(MSALAccountId *)homeAccountId
                     environment:(NSString *)environment
{
    self = [super init];
    
    if (self)
    {
        _username = username;
        _environment = environment;
        _homeAccountId = homeAccountId;
    }
    
    return self;
}

// For if/else statements
if (user.isHappy)
{
    // Do something
}
else
{
    // Do something else
}
```

### 2b. Line Width

**SHOULD** restrict line width to 80 columns. Configure Xcode to display a Page Guide:

```
Xcode → Preferences → Text Editing → Page Guide at column: 80
```

For long method calls that exceed 80 columns, break after arguments aligned to the colon:

```objc
self.productsRequest = [[SKProductsRequest alloc]
    initWithProductIdentifiers:productIdentifiers];
```

**NOTE:** Blocks should NOT be colon-aligned because Xcode's indenting makes it illegible:

```objc
// Correct - blocks are readable
[UIView animateWithDuration:1.0 animations:^{
    // something
} completion:^(BOOL finished) {
    // something
}];

// Incorrect - colon-aligning makes block indentation hard to read
[UIView animateWithDuration:1.0
                 animations:^{
                     // something
                 }
                 completion:^(BOOL finished) {
                     // something
                 }];
```

### 3. Conditionals

**MUST** always use braces for conditional bodies, even for single-line statements.

```objc
// Correct
if (!error)
{
    return success;
}

// Incorrect - Never do this
if (!error)
    return success;

if (!error) return success;
```

### 3b. Conditional Expressions

**SHOULD** avoid method calls directly within conditional expressions. Assign to a local variable first to improve readability.

```objc
// Correct
BOOL continuousPlayEnabled = [[MediaAppPrefs sharedInstance] continuousPlay];
MSALAccount *nextAccount = [self nextAccountForParameters:parameters];
if (continuousPlayEnabled && nextAccount)
{
    // ...
}

// Avoid
if ([[MediaAppPrefs sharedInstance] continuousPlay] && [self nextAccountForParameters:parameters])
{
    // ...
}
```

### 4. Ternary Operator

**SHOULD** only evaluate a single condition per ternary expression.

```objc
// Acceptable
result = account.isValid ? account : nil;

// Avoid - too complex
result = account.isValid ? account.username = tenant.isValid ? tenant.id : nil : nil;
```

### 5. Error Handling

**MUST** check the return value, **MUST NOT** check the error variable directly.

```objc
// Correct
NSError *error;
if (![self trySomethingWithError:&error])
{
    // Handle Error
}

// Incorrect - Apple APIs may write garbage to error on success
NSError *error;
[self trySomethingWithError:&error];
if (error)
{
    // Handle Error
}
```

### 5b. Booleans

**MUST** use `YES` and `NO` in Objective-C (never `true`/`false`, except in C, C++, or Swift code).
**MUST NOT** compare directly to `YES` (it is defined as 1 and a `BOOL` can be up to 8 bits).
**SHOULD NOT** compare to `nil` — let the condition evaluate naturally.

```objc
// Correct
if (someObject)
{
    // ...
}

if (![anotherObject boolValue])
{
    // ...
}

// Incorrect
if (someObject == nil)
if ([anotherObject boolValue] == NO)
if (isAwesome == YES)     // Never do this
if (isAwesome == true)    // Never do this
```

For `BOOL` properties expressed as adjectives, omit the "is" prefix but specify a getter:

```objc
@property (nonatomic, readwrite, unsafe_unretained, getter=isEditable) BOOL editable;
```

### 5c. Return Statements

**SHOULD** avoid complex method calls directly in return expressions. Collect evaluation criteria into local variables first.

```objc
// Correct
- (BOOL)shouldPlayNext
{
    BOOL continuousPlayEnabled = [[MSALPrefs sharedInstance] continuousPlay];
    MSALAccount *nextAccount = [self.provider nextAccount];
    return (continuousPlayEnabled && nextAccount);
}

// Avoid
- (BOOL)shouldPlayNext
{
    return ([[MSALPrefs sharedInstance] continuousPlay] && [self.provider nextAccount]);
}
```

### 5d. Golden Path

**SHOULD** use early returns to keep the "happy path" at the leftmost indent level. Avoid deeply nested `if` statements.

```objc
// Correct
- (void)processAccount:(MSALAccount *)account
{
    if (!account) return;
    if (!account.isValid) return;

    // Main logic here, not nested
    [self doSomethingWithAccount:account];
}

// Avoid
- (void)processAccount:(MSALAccount *)account
{
    if (account)
    {
        if (account.isValid)
        {
            [self doSomethingWithAccount:account];
        }
    }
}
```

### 6. Method Signatures

**SHOULD** include space after scope symbol and between method segments.

```objc
// Correct
- (void)acquireTokenWithParameters:(MSALSilentTokenParameters *)parameters
                   completionBlock:(MSALCompletionBlock)completionBlock;

// For methods exceeding 80 characters, format like a form
- (MSALResult *)resultWithTokenResult:(MSIDTokenResult *)result
                           authScheme:(id<MSALAuthenticationSchemeProtocol>)authScheme
                           popManager:(MSIDDevicePopManager *)popManager
                                error:(NSError **)error;
```

**MUST NOT** use the word `and` to link multiple parameters — it is reserved for methods that perform two operations:

```objc
// Correct
- (instancetype)initWithWidth:(CGFloat)width height:(CGFloat)height;

// Incorrect
- (instancetype)initWithWidth:(CGFloat)width andHeight:(CGFloat)height;
- (instancetype)initWith:(int)width and:(int)height;  // Never do this
```

**MUST** use `instancetype` instead of `id` as the return type for `init` and class constructor methods:

```objc
// Correct
- (instancetype)initWithParameters:(MSALParameters *)parameters;
+ (instancetype)accountWithIdentifier:(NSString *)identifier;

// Incorrect
- (id)initWithParameters:(MSALParameters *)parameters;
+ (id)accountWithIdentifier:(NSString *)identifier;
```

### 7. Variables

#### Naming

**SHOULD** use descriptive variable names:

- `NSString *username` - clear and concise
- `NSString *accessToken` - describes the token type
- `MSALAccount *currentAccount` - not just `account`
- `MSIDRequestParameters *requestParams` - abbreviated but clear
- `MSALPublicClientApplicationConfig *config` - clear context

**NOT RECOMMENDED:** Single letter variable names (except loop counters)

#### Pointer Asterisks

**MUST** attach asterisks to variable name:

```objc
// Correct
NSString *clientId

// Incorrect
NSString* clientId
NSString * clientId
```

Exception: Constants (`NSString * const MSALErrorDomain`)

#### Property Attributes

**SHOULD** list all property attributes explicitly in this order: atomicity, accessibility, storage. This pushes differences between adjacent declarations to the right, making them easier to scan.

```objc
// Correct - explicit, ordered attributes
@property (nonatomic, readwrite, strong) MSALPublicClientApplicationConfig *config;
@property (nonatomic, readonly, weak) id<MSALWebviewControllerDelegate> delegate;

// Avoid - partial or unordered attributes
@property (weak, nonatomic) IBOutlet UIView *containerView;
@property (nonatomic) NSString *tutorialName;
```

Properties with mutable counterparts (e.g. `NSString`) **SHOULD** use `copy` instead of `strong` to guard against external mutation:

```objc
// Correct
@property (nonatomic, readwrite, copy) NSString *clientId;

// Avoid - caller could pass NSMutableString and modify it
@property (nonatomic, readwrite, strong) NSString *clientId;
```

#### Properties vs Instance Variables

**SHOULD** use properties instead of naked instance variables.

```objc
// Preferred
@interface MSALAccount : NSObject
@property (nonatomic) NSString *username;
@property (nonatomic) NSString *environment;
@end

// Avoid
@interface MSALAccount : NSObject
{
    NSString *username;
    NSString *environment;
}
@end
```

**SHOULD** avoid direct instance variable access except in:

- Initializer methods (`init`, `initWithCoder:`)
- `dealloc` methods
- Custom setters and getters

#### Variable Qualifiers

**SHOULD** place ARC qualifiers between asterisks and variable name:

```objc
NSString * __weak weakReference;
MSALAccount * __autoreleasing autoreleasedAccount;
```

### 8. Naming Conventions

#### Class Names and Constants

**MUST** use `MSAL` prefix for public classes and constants
**MAY** use `MSID` prefix for internal/shared classes

```objc
// Correct
static const NSTimeInterval MSALDefaultTokenRefreshInterval = 300.0;
static NSString * const MSALErrorDomain = @"MSALErrorDomain";

// Incorrect
static const NSTimeInterval refreshInterval = 300.0;
```

#### Properties and Local Variables

**MUST** be camelCase with lowercase leading word.

```objc
NSString *accessToken;
MSALAccount *currentAccount;
MSIDRequestParameters *requestParams;
```

#### Instance Variables

**MUST** be camelCase with lowercase leading word and underscore prefix:

```objc
@implementation MSALPublicClientApplication
{
    BOOL _validateAuthority;
    WKWebView *_customWebview;
    NSString *_defaultKeychainGroup;
}
```

### 9. Categories

**MUST** prefix category methods with `msal` or `msid` to avoid collisions:

```objc
// Correct
@interface NSArray (MSALAccessors)
- (id)msalObjectOrNilAtIndex:(NSUInteger)index;
@end

// Incorrect - may conflict with other libraries
@interface NSArray (MSALAccessors)
- (id)objectOrNilAtIndex:(NSUInteger)index;
@end
```

### 10. Comments

**SHOULD** explain **why**, not what.
**MUST** keep comments up-to-date or delete them.
**NOT RECOMMENDED:** Block comments (code should be self-documenting).

### 11. Literals

**SHOULD** use literals for `NSString`, `NSDictionary`, `NSArray`, `NSNumber`:

```objc
// Preferred
NSArray *scopes = @[@"user.read", @"mail.read", @"profile"];
NSDictionary *claims = @{@"id_token": @{@"auth_time": @{@"essential": @YES}}};
NSNumber *isEnabled = @YES;
NSNumber *timeout = @30;

// Avoid
NSArray *scopes = [NSArray arrayWithObjects:@"user.read", @"mail.read", @"profile", nil];
```

**Warning:** Never pass `nil` into array/dictionary literals - causes crash.

### 12. Constants

**MUST** declare as `static` constants:

```objc
static NSString * const MSALErrorDomain = @"MSALErrorDomain";
static const CGFloat MSALDefaultTimeout = 30.0;
static const NSTimeInterval MSALTokenExpirationBuffer = 300.0;
```

**MAY** use `#define` only when explicitly used as a macro.

### 12b. Switch Statements

Braces for `switch` begin on a new line (matching the repository brace style). Case labels with multiple lines **MUST** use braces. Fall-through cases **MUST** be commented. When switching on an `NS_ENUM`, `default` is not required.

```objc
switch (promptType)
{
    case MSALPromptTypeDefault:
        // ...
        break;

    case MSALPromptTypeLogin:
    {
        // Multi-line case body requires braces
        NSString *message = @"Forcing login";
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"%@", message);
        break;
    }

    case MSALPromptTypeConsent:
        // ** fall-through! **

    case MSALPromptTypeSelectAccount:
        // code executed for Consent and SelectAccount
        break;
}
```

### 13. Enumerated Types

**MUST** use `NS_ENUM()` for enumerations:

```objc
typedef NS_ENUM(NSInteger, MSALPromptType)
{
    MSALPromptTypeDefault,
    MSALPromptTypeLogin,
    MSALPromptTypeConsent,
    MSALPromptTypeSelectAccount
};
```

### 14. Private Properties

**SHALL** declare private properties in class extensions in implementation file:

```objc
// In MSALPublicClientApplication.m
@interface MSALPublicClientApplication()
{
    BOOL _validateAuthority;
    WKWebView *_customWebview;
}

@property (nonatomic) MSALPublicClientApplicationConfig *internalConfig;
@property (nonatomic) MSIDExternalAADCacheSeeder *externalCacheSeeder;
@property (nonatomic) MSIDCacheConfig *msidCacheConfig;

@end
```

### 15. Singletons

**SHOULD** use thread-safe pattern with `dispatch_once`:

```objc
+ (instancetype)sharedInstance
{
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[[self class] alloc] init];
    });
    return sharedInstance;
}
```

### 16. Imports

**MUST NOT** group imports (repository convention).

```objc
// Correct (as used in this repository)
#import "MSALPublicClientApplication+Internal.h"
#import "MSALPromptType_Internal.h"
#import "MSALError.h"
#import "MSALTelemetryApiId.h"
#import "MSIDMacTokenCache.h"
#import "MSIDLegacyTokenCacheAccessor.h"
#import "MSIDDefaultTokenCacheAccessor.h"

// Do NOT group like this
// Frameworks
@import Foundation;

// MSAL Core
#import "MSALPublicClientApplication.h"
```

### 21. Protocols (Delegates)

**SHOULD** make first parameter the object sending the message:

```objc
// Correct
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;

// Incorrect
- (void)didSelectTableRowAtIndexPath:(NSIndexPath *)indexPath;
```

### 22. Block Declarations

**SHOULD** use clear formatting for complex blocks:

```objc
__auto_type block = ^(MSALResult *result, NSError *msidError, id<MSIDRequestContext> context)
{
    NSError *msalError = [MSALErrorConverter msalErrorFromMsidError:msidError 
                                                     classifyErrors:YES 
                                                 msalOauth2Provider:self.msalOauth2Provider];
    
    if (!completionBlock) return;
    
    if (parameters.completionBlockQueue)
    {
        dispatch_async(parameters.completionBlockQueue, ^{
            completionBlock(result, msalError);
        });
    }
    else
    {
        completionBlock(result, msalError);
    }
};
```

### 23. Xcode Project Organization

**SHOULD** keep physical files in sync with Xcode project structure.
**SHOULD** reflect Xcode groups as filesystem folders.
**SHOULD** group code by feature, not just by type.
**SHOULD** enable "Treat Warnings as Errors" build setting.

### 24. Code Organization with #pragma mark

**SHOULD** use `#pragma mark -` to categorize methods in functional groupings within implementation files. Follow this general section order:

```objc
#pragma mark - Class Methods

+ (instancetype)sharedInstance;

#pragma mark - Lifecycle

- (instancetype)init {}
- (void)dealloc {}

#pragma mark - Custom Accessors

- (void)setCustomProperty:(id)value {}
- (id)customProperty {}

#pragma mark - Public

- (void)publicMethod {}

#pragma mark - Private

- (void)privateMethod {}

#pragma mark - Protocol conformance
#pragma mark - MSALWebviewControllerDelegate
#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {}

#pragma mark - NSObject

- (NSString *)description {}
```

### 25. Documentation (Doxygen/JavaDoc)

Public header files **SHOULD** include Doxygen-compatible JavaDoc comments to support API documentation generation. Document all classes, constants, properties, and methods in header files. Private interface documentation belongs in the implementation file.

**Class Documentation:**

```objc
/**
 * Represents a Microsoft identity account used for authentication.
 *
 * Use this object to identify the account for silent token acquisition.
 */
@interface MSALAccount : NSObject
```

**Property Documentation:**

```objc
/**
 * The displayable username for this account (e.g. user@contoso.com).
 *
 * @see MSALAccountId
 */
@property (nonatomic, readonly, copy) NSString *username;
```

**Constant Documentation:**

```objc
/**
 * @memberof MSALErrorDomain
 * Domain for all MSAL errors returned through completion blocks.
 */
extern NSString * const MSALErrorDomain;
```

**Method Documentation:**

```objc
/**
 * Acquires a token silently for the provided account.
 *
 * @param parameters  Silent token request parameters including scopes and account.
 * @param completionBlock  Block invoked on completion with result or error.
 *
 * @throws MSALErrorDomain when the account is not found in cache.
 *
 * @remark This method will not show any UX. If interaction is required, the error
 *   will contain MSALErrorInteractionRequired.
 */
- (void)acquireTokenSilentWithParameters:(MSALSilentTokenParameters *)parameters
                         completionBlock:(MSALCompletionBlock)completionBlock;
```

---

## AI Agent-Specific Guidelines

### When Adding New Features:

1. **Match Existing Patterns**: Analyze similar existing code before implementing
2. **Follow MSAL Conventions**: Use `MSAL` prefix for public classes, `MSID` for internal code in CommonCore sub repository
3. **Maintain Consistency**: Match indentation, spacing, and naming in surrounding code
4. **Property-First**: Use `@property` declarations rather than instance variables
5. **Error Handling**: Always check return values, never the error variable
6. **Thread Safety**: Use `dispatch_once` for singletons, consider thread safety for shared resources
7. **Memory Management**: Follow ARC patterns, be mindful of retain cycles
8. **Nil Safety**: Never pass `nil` to array/dictionary literals
9. **Documentation**: Add header documentation for public APIs
10. **Test Coverage**: Consider how changes affect existing tests

### When Modifying Existing Code:

1. **Preserve Style**: Don't mix styles within a file
2. **Minimal Changes**: Change only what's necessary
3. **Update Comments**: Keep comments synchronized with code changes
4. **Deprecation**: Use proper deprecation warnings when replacing APIs
5. **Backward Compatibility**: Consider impact on existing integrations

### Common MSAL Patterns:

#### Error Handling Pattern

```objc
NSError *msidError = nil;
BOOL result = [self performOperationWithError:&msidError];

if (!result)
{
    if (error) *error = [MSALErrorConverter msalErrorFromMsidError:msidError];
    return NO;
}
```

#### Completion Block Pattern

```objc
__auto_type block = ^(MSALResult *result, NSError *error)
{
    // Process result
    
    if (!completionBlock) return;
    
    if (parameters.completionBlockQueue)
    {
        dispatch_async(parameters.completionBlockQueue, ^{
            completionBlock(result, error);
        });
    }
    else
    {
        completionBlock(result, error);
    }
};
```

#### Logging Pattern

```objc
MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, context, 
                      @"Operation completed with account %@", 
                      MSID_PII_LOG_EMAIL(account.username));
```

### Code Review Checklist:

- [ ] Uses 4-space indentation (no tabs)
- [ ] Opening braces on new line
- [ ] All conditionals have braces
- [ ] Error handling checks return value, not error variable
- [ ] Method signatures properly spaced
- [ ] `and` not used to link unrelated method parameters
- [ ] `instancetype` used for `init` and class constructor return types
- [ ] Variables descriptively named (US English spelling)
- [ ] Pointers attached to variable names
- [ ] Uses properties instead of instance variables
- [ ] Property attributes listed in order: atomicity, accessibility, storage
- [ ] `NSString` (and mutable-counterpart) properties use `copy`
- [ ] Category methods prefixed with `msal` or `msid`
- [ ] Uses `NS_ENUM` for enumerations
- [ ] Private properties in class extension
- [ ] Singletons use `dispatch_once`
- [ ] Imports not grouped (per repository style)
- [ ] Delegate methods include sender as first parameter
- [ ] `#pragma mark -` sections used to organize methods in implementation files
- [ ] Public headers include Doxygen-compatible documentation
- [ ] Booleans use `YES`/`NO`, never compared directly to `YES`
- [ ] Switch cases with multi-line bodies have braces; fall-throughs are commented
- [ ] No warnings or errors in build
- [ ] Follows existing MSAL/MSID patterns

---

## References

- [Apple: The Objective-C Programming Language](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/ProgrammingWithObjectiveC/Introduction/Introduction.html)
- [Apple: Coding Guidelines for Cocoa](https://developer.apple.com/library/mac/#documentation/Cocoa/Conceptual/CodingGuidelines/CodingGuidelines.html)
- [Apple: Memory Management Programming Guide](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/MemoryMgmt/Articles/mmPractical.html)
- [IETF RFC 2119: Key words for use in RFCs](http://tools.ietf.org/html/rfc2119)
- [Wonderful Objective-C Style Guide (markeissler)](https://github.com/markeissler/wonderful-objective-c-style-guide/blob/master/README.md)

---

## Repository-Specific Conventions

### Key Differences from Standard Guidelines:

1. **Braces on New Line**: Unlike many Objective-C style guides, this repository places opening braces on a new line
2. **No Import Grouping**: Imports are listed without grouping or comments
3. **MSAL/MSID Prefixes**: Public APIs use `MSAL`, internal/shared from CommonCore repository use `MSID`
4. **Extensive Logging**: PII-aware logging with `MSID_LOG_WITH_CTX` macros
5. **Block-based Async**: Completion handlers with queue dispatch patterns

### Copyright Header

All new files **MUST** include the Microsoft copyright header when added to this repository, but not when generating a new sample app:

```objc
//------------------------------------------------------------------------------
//
// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------
```

---

## Notes

This style guide is adapted specifically for AI agents working on the Microsoft Authentication Library (MSAL) for iOS and macOS. When in doubt, prioritize consistency with existing codebase patterns over strict adherence to external style guides.