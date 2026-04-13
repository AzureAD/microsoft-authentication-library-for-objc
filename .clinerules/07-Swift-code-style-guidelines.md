# Swift Code Style Guidelines for AI Agents

## Overview

This document provides Swift code style guidelines that AI agents MUST follow when working with Swift code in this repository. These guidelines are adapted from the [Google Swift Style Guide](https://google.github.io/swift/) and [Apple's Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/), tailored to match the existing Swift code patterns in this repository (primarily `MSAL/src/native_auth/`).

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

```swift
// Correct
let backgroundColor = UIColor.white

// Incorrect
let backgroundColour = UIColor.white
```

### 1. Spacing and Indentation

**MUST** follow these spacing rules:

- Indentation: 4 spaces (never tabs)
- Opening braces on the **same line** as the declaration (K&R style)
- Closing braces on their own line
- One blank line between methods and between logical sections

```swift
// Correct
func acquireToken(scopes: [String], completion: @escaping (MSALResult?) -> Void) {
    guard !scopes.isEmpty else {
        completion(nil)
        return
    }

    performRequest(scopes: scopes) { result in
        completion(result)
    }
}

// Incorrect — opening brace on new line (this is the Obj-C convention, not Swift)
func acquireToken(scopes: [String], completion: @escaping (MSALResult?) -> Void)
{
    // ...
}
```

**Note:** This differs from the Objective-C convention in this repository, which places opening braces on a new line. Swift code follows K&R style per the Google Swift Style Guide.

### 1b. Line Width

**MUST** restrict line width to **150 characters** (matching the SwiftLint configuration in `MSAL/.swiftlint.yml`).

For long declarations that exceed 150 characters, wrap arguments with each on its own line, indented +4 from the original line:

```swift
// Correct — wrapped function declaration
func performTokenRequest(
    scopes: [String],
    account: MSALAccount,
    authority: MSALAuthority,
    completion: @escaping (MSALResult?, Error?) -> Void
) {
    // ...
}

// Correct — wrapped function call
let result = performTokenRequest(
    scopes: requestedScopes,
    account: currentAccount,
    authority: defaultAuthority,
    completion: handleResult
)
```

### 2. Braces

**MUST** follow K&R style (Kernighan and Ritchie) for non-empty blocks:

- No line break before the opening brace (`{`)
- Line break after the opening brace
- Line break before the closing brace (`}`)
- `else`, `catch`, etc. on the same line as the closing brace: `} else {`

```swift
// Correct
if account.isValid {
    processAccount(account)
} else {
    handleInvalidAccount()
}

// Incorrect
if account.isValid
{
    processAccount(account)
}
else
{
    handleInvalidAccount()
}
```

Empty blocks **MAY** be written as `{}`.

### 3. Semicolons

**MUST NOT** use semicolons to terminate or separate statements.

```swift
// Correct
let sum = a + b
print(sum)

// Incorrect
let sum = a + b;
print(sum);
```

### 4. Conditionals and Control Flow

**MUST NOT** use parentheses around the top-level condition in `if`, `guard`, `while`, or `switch` statements.

```swift
// Correct
if x == 0 {
    print("x is zero")
}

if (x == 0 || y == 1) && z == 2 {
    print("...")
}

// Incorrect
if (x == 0) {
    print("x is zero")
}
```

### 4b. Guard for Early Exits

**SHOULD** use `guard` for early exits to keep the "happy path" at the leftmost indent level.

```swift
// Correct
func processAccount(_ account: MSALAccount?) {
    guard let account = account else {
        return
    }
    guard account.isValid else {
        return
    }

    // Main logic here, not nested
    doSomething(with: account)
}

// Avoid
func processAccount(_ account: MSALAccount?) {
    if let account = account {
        if account.isValid {
            doSomething(with: account)
        }
    }
}
```

### 4c. Single-Statement Bodies

**MAY** place a single-statement body on the same line when the entire statement fits within the line limit and improves readability:

```swift
guard let value = value else { return 0 }

defer { file.close() }

var someProperty: Int { return otherObject.property }
```

### 5. Error Handling

**MUST** use Swift's `do`-`catch`-`try` mechanism for error handling.
**MUST NOT** use `try!` in production code (permitted in unit tests).
**MAY** use `try?` when the specific failure reason is unimportant.

```swift
// Correct
do {
    let result = try performOperation()
    handleSuccess(result)
} catch OperationError.notFound {
    handleNotFound()
} catch {
    handleGenericError(error)
}

// Correct — when you only care about success/failure
if let result = try? performOperation() {
    handleSuccess(result)
}

// Incorrect — force try in production code
let result = try! performOperation()
```

### 5b. Optional Handling

**SHOULD** prefer `Optional` types over sentinel values (e.g., `-1`, empty strings).
**MUST NOT** force-unwrap (`!`) without a comment explaining why it is safe. Force-unwraps are permitted in unit tests without additional documentation.

```swift
// Correct
func findAccount(identifier: String, in accounts: [MSALAccount]) -> MSALAccount? {
    return accounts.first { $0.identifier == identifier }
}

if let account = findAccount(identifier: id, in: accounts) {
    // Found it
} else {
    // Not found
}

// Avoid — sentinel values
func findAccountIndex(identifier: String, in accounts: [MSALAccount]) -> Int {
    // Returning -1 as "not found" is error-prone
    return accounts.firstIndex { $0.identifier == identifier } ?? -1
}
```

### 5c. Implicitly Unwrapped Optionals

**SHOULD NOT** use implicitly unwrapped optionals except for:

- `@IBOutlet` properties
- Properties initialized in `viewDidLoad` or similar lifecycle methods
- Test fixtures initialized in `setUp()`
- Interop with Objective-C APIs lacking nullability annotations

### 6. Naming Conventions

**MUST** follow [Apple's Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/).

#### Types and Protocols

**MUST** use `UpperCamelCase` for types, protocols, and enum names.
**MUST** use `MSAL` prefix for public-facing types (matching the Objective-C convention).

```swift
// Correct
public class MSALNativeAuthUserAccountResult { }
public protocol MSALNativeAuthTokenDelegate { }
public enum MSALNativeAuthError { }

// Incorrect — missing prefix for public types
public class UserAccountResult { }
```

#### Properties, Variables, and Functions

**MUST** use `lowerCamelCase` for properties, variables, functions, and enum cases.

```swift
// Correct
var accessToken: String
let currentAccount: MSALNativeAuthUserAccountResult
func acquireToken(scopes: [String]) { }

enum AuthState {
    case signedIn
    case signedOut
    case interactionRequired
}

// Incorrect
var AccessToken: String
let kCurrentAccount: MSALNativeAuthUserAccountResult
```

#### Constants

**MUST** use `lowerCamelCase` for constants — Hungarian notation (`k` prefix, `g` prefix) is **not** used.

```swift
// Correct
let defaultTokenRefreshInterval: TimeInterval = 300.0
let maximumRetryCount = 3

// Incorrect
let kDefaultTokenRefreshInterval: TimeInterval = 300.0
let MAXIMUM_RETRY_COUNT = 3
let DefaultTokenRefreshInterval: TimeInterval = 300.0
```

#### Delegate Methods

**SHOULD** name delegate methods following Cocoa conventions. The first parameter should be the source object (unlabeled):

```swift
// Correct
func signInCompleted(_ result: MSALNativeAuthUserAccountResult)
func signIn(_ signIn: MSALNativeAuthSignInController, didCompleteWith result: MSALResult)

// Incorrect — missing source object
func didCompleteSignIn(result: MSALResult)
```

### 7. Type Inference

**SHOULD** rely on type inference where the type is obvious from context. Use explicit types when they aid readability or when the type cannot be inferred.

```swift
// Correct — type is obvious
let message = "Authentication completed"
let scopes = ["user.read", "mail.read"]
var isAuthenticated = false

// Correct — explicit type improves clarity
let timeout: TimeInterval = 30.0
let statusCode: Int32 = 200

// Avoid — redundant explicit types
let message: String = "Authentication completed"
let isAuthenticated: Bool = false
```

### 7b. Shorthand Type Names

**MUST** use shorthand syntax for arrays, dictionaries, and optionals.

```swift
// Correct
var scopes: [String] = []
var claimsMap: [String: Any] = [:]
var account: MSALAccount?

// Incorrect
var scopes: Array<String> = Array<String>()
var claimsMap: Dictionary<String, Any> = Dictionary<String, Any>()
var account: Optional<MSALAccount>
```

### 8. Properties

**SHOULD** declare local variables close to where they are first used.
**MUST** declare only one variable per `let`/`var` statement (except tuple destructuring).

```swift
// Correct
var a = 5
var b = 10
let (quotient, remainder) = divide(100, 9)

// Incorrect
var a = 5, b = 10
```

#### Computed Properties

**SHOULD** omit the `get` block for read-only computed properties.

```swift
// Correct
var totalCost: Int {
    return items.reduce(0) { $0 + $1.cost }
}

// Avoid
var totalCost: Int {
    get {
        return items.reduce(0) { $0 + $1.cost }
    }
}
```

### 9. Access Control

**SHOULD** use the most restrictive access level possible.
**MUST NOT** use `public extension` — specify access on each member individually.

```swift
// Correct
extension MSALNativeAuthUserAccountResult {
    public var isValid: Bool {
        // ...
    }

    internal func refresh() {
        // ...
    }
}

// Incorrect
public extension MSALNativeAuthUserAccountResult {
    var isValid: Bool {
        // ...
    }

    func refresh() {
        // ...
    }
}
```

### 10. Switch Statements

**MUST** indent `case` labels at the **same** level as the `switch` keyword, with statements inside the case indented +4 spaces.

```swift
// Correct
switch authState {
case .signedIn:
    handleSignedIn()
case .signedOut:
    handleSignedOut()
case .interactionRequired:
    promptForInteraction()
}
```

**MUST NOT** use `fallthrough` where cases can be combined with commas or ranges.

```swift
// Correct
switch statusCode {
case 200: handleSuccess()
case 400...499: handleClientError()
case 500, 502, 503: handleServerError()
default: break
}

// Incorrect
switch statusCode {
case 400: fallthrough
case 401: fallthrough
case 402: handleClientError()
default: break
}
```

### 11. Enum Cases

**MUST** use one `case` per line when cases have associated values.
**MAY** use comma-delimited form when all cases are simple and fit on one line.

```swift
// Correct — associated values require separate lines
public enum AuthError {
    case invalidCredentials
    case networkFailure(Error)
    case tokenExpired(Date)
}

// Correct — simple cases may be combined
public enum TokenType {
    case access, refresh, id
}

// Incorrect — empty parentheses on a case
public enum AuthState {
    case signedIn
    case signedOut()  // Avoid
}
```

### 12. Closures and Trailing Closures

**MUST** use trailing closure syntax when a function takes a single closure as the final argument.
**MUST NOT** use trailing closure syntax when a function takes multiple closure arguments — label all closures.

```swift
// Correct — single trailing closure
let squares = numbers.map { $0 * $0 }

Timer.scheduledTimer(timeInterval: 30, repeats: false) { timer in
    print("Timer done!")
}

// Correct — multiple closures, all labeled
UIView.animate(
    withDuration: 0.5,
    animations: {
        view.alpha = 0
    },
    completion: { finished in
        view.removeFromSuperview()
    }
)

// Incorrect — trailing closure with multiple closure args
UIView.animate(
    withDuration: 0.5,
    animations: {
        view.alpha = 0
    }
) { finished in
    view.removeFromSuperview()
}
```

When no other arguments exist, empty parentheses **MUST NOT** be present:

```swift
// Correct
let squares = [1, 2, 3].map { $0 * $0 }

// Incorrect
let squares = [1, 2, 3].map() { $0 * $0 }
```

### 13. Trailing Commas

**MUST** include trailing commas in multi-line array and dictionary literals.

```swift
// Correct
let scopes = [
    "user.read",
    "mail.read",
    "profile",
]

// Incorrect
let scopes = [
    "user.read",
    "mail.read",
    "profile"
]
```

### 14. Imports

**MUST** import whole modules, not individual declarations (unless importing would pollute the global namespace).
**SHOULD** order imports lexicographically within each group, with groups separated by a blank line:

1. Non-test module imports
2. Individual declaration imports
3. `@testable` imports (test sources only)

```swift
import CoreLocation
import Foundation
import UIKit

@testable import MSAL
```

### 15. Comments

**SHOULD** explain **why**, not what.
**MUST** keep comments up-to-date or delete them.
**MUST** use `//` for non-documentation comments. **MUST NOT** use `/* ... */` block comments.

```swift
// Correct
// We retry here because the token endpoint may return a transient error.
let result = try await retryableRequest(maxRetries: 3)

// Incorrect — states the obvious
// Set retries to 3
let maxRetries = 3
```

### 16. Documentation Comments

**MUST** use `///` (triple-slash) format for documentation comments. **MUST NOT** use `/** ... */` Javadoc-style comments.

**MUST** document all `public` and `open` declarations.

```swift
/// Acquires a token silently for the provided account.
///
/// - Parameters:
///   - scopes: The scopes to request in the token.
///   - account: The account for which to acquire the token.
/// - Returns: The authentication result containing the access token.
/// - Throws: `MSALNativeAuthError.interactionRequired` if silent acquisition fails.
func acquireTokenSilent(
    scopes: [String],
    account: MSALAccount
) throws -> MSALResult {
    // ...
}
```

Summary lines **SHOULD** be verb phrases for methods and noun phrases for properties, **without** "This method …" or "This property is …" prefixes:

```swift
/// The displayable username for this account.
var username: String

/// Returns the cached account matching the given identifier.
func account(forIdentifier identifier: String) -> MSALAccount?
```

### 17. Code Organization with MARK

**SHOULD** use `// MARK: -` to categorize methods into logical sections:

```swift
class MSALNativeAuthSignInController {

    // MARK: - Properties

    private let clientId: String
    private let authority: MSALAuthority

    // MARK: - Initialization

    init(clientId: String, authority: MSALAuthority) {
        self.clientId = clientId
        self.authority = authority
    }

    // MARK: - Public Methods

    func signIn(username: String, completion: @escaping (Result<MSALResult, Error>) -> Void) {
        // ...
    }

    // MARK: - Private Methods

    private func validateCredentials(_ username: String) -> Bool {
        // ...
    }
}

// MARK: - MSALNativeAuthTokenDelegate

extension MSALNativeAuthSignInController: MSALNativeAuthTokenDelegate {
    func onAccessTokenRetrieveCompleted(_ result: MSALNativeAuthTokenResult) {
        // ...
    }
}
```

### 18. Nesting and Namespacing

**SHOULD** nest types within their parent type to express scoped relationships, rather than relying on naming conventions.

```swift
// Correct — nested types
class MSALNativeAuthRequestHandler {
    enum Error: Swift.Error {
        case invalidToken(String)
        case networkFailure
    }

    struct Configuration {
        let timeout: TimeInterval
        let retryCount: Int
    }
}

// Avoid — flat types with naming prefix
enum MSALNativeAuthRequestHandlerError: Error {
    case invalidToken(String)
    case networkFailure
}
```

**SHOULD** use caseless `enum` for namespaces grouping related constants:

```swift
// Correct
enum MSALNativeAuthConstants {
    static let defaultTimeout: TimeInterval = 30.0
    static let maxRetryCount = 3
}

// Avoid
struct MSALNativeAuthConstants {
    private init() {}
    static let defaultTimeout: TimeInterval = 30.0
    static let maxRetryCount = 3
}
```

### 19. Pattern Matching

**MUST** place `let`/`var` individually before each binding in a pattern match:

```swift
// Correct
switch dataPoint {
case .labeled(let label, let value):
    // ...
case .unlabeled(let value):
    // ...
}

// Incorrect — `let` distributed across entire pattern
switch dataPoint {
case let .labeled(label, value):
    // ...
case let .unlabeled(value):
    // ...
}
```

### 20. `for`-`where` Loops

**SHOULD** use `where` clauses on `for` loops instead of wrapping the body in an `if`:

```swift
// Correct
for account in accounts where account.isActive {
    processAccount(account)
}

// Avoid
for account in accounts {
    if account.isActive {
        processAccount(account)
    }
}
```

### 21. Attributes

Parameterized attributes (e.g., `@available(iOS 16.0, *)`, `@objc(methodName:)`) **MUST** be placed on their own line above the declaration.

```swift
// Correct
@available(iOS 16.0, *)
public func newFeature() {
    // ...
}

// Incorrect
@available(iOS 16.0, *) public func newFeature() {
    // ...
}
```

Simple attributes without parameters (`@objc`, `@discardableResult`) **MAY** appear on the same line if they do not cause the line to be wrapped:

```swift
@objc private var isConfigured: Bool
@discardableResult func performAction() -> Bool { /* ... */ }
```

### 22. Horizontal Whitespace

**MUST** place spaces:

- On both sides of binary and ternary operators (`=`, `+`, `->`, `?:`, `&` in protocol composition)
- After `,` in parameter lists, tuple/array/dictionary literals
- After `:` in type annotations, superclass/protocol conformance, dictionary literals
- Before and after `{` and `}` on the same line
- At least two spaces before `//` for end-of-line comments

**MUST NOT** place spaces:

- On either side of `.` for member access
- On either side of `..<` or `...` in range expressions
- Before `,` or `:`
- Inside brackets `[]` or parentheses `()`

```swift
// Correct
let result = a + b
let range = 1...10
let dict: [String: Int] = ["key": 42]
func sum(_ numbers: [Int]) -> Int { return numbers.reduce(0, +) }
let value = condition ? trueValue : falseValue  // inline comment

// Incorrect
let result = a+b
let range = 1 ... 10
let dict: [String : Int] = ["key" :42]
```

### 23. Horizontal Alignment

**MUST NOT** use horizontal alignment (aligning values across multiple lines):

```swift
// Correct
struct Configuration {
    var timeout: TimeInterval
    var retryCount: Int
    var displayName: String
}

// Incorrect — aligned colons
struct Configuration {
    var timeout:     TimeInterval
    var retryCount:  Int
    var displayName: String
}
```

### 24. Force Unwrapping and Force Casts

**SHOULD NOT** use force-unwrapping (`!`) or force-casting (`as!`) in production code. When force-unwrapping is genuinely safe, **MUST** include a comment explaining why.

**Exception:** Force-unwraps and force-casts are permitted in unit tests without additional documentation.

```swift
// Acceptable — with justification
// Force-unwrap is safe because the regex pattern is a compile-time constant.
let regex = try! NSRegularExpression(pattern: "^[a-z]+$")

// Preferred — use guard/if-let
guard let url = URL(string: urlString) else {
    throw AuthError.invalidURL
}
```

### 25. Arithmetic

**SHOULD** use standard (trapping) arithmetic operators (`+`, `-`, `*`) for normal operations.
**MAY** use overflow operators (`&+`, `&-`, `&*`) only in domains requiring modular arithmetic (e.g., hashing, cryptography).

---

## SwiftLint Configuration

This repository enforces SwiftLint for Swift code in `MSAL/src/native_auth/`. The active rules from `MSAL/.swiftlint.yml`:

- **Line length warning**: 150 characters
- **Type name max length**: 60 characters
- **Function parameter count warning**: 7 parameters
- **Disabled rules**: `todo`, `empty_enum_arguments`

**MUST** ensure all Swift code passes SwiftLint without warnings.

---

## AI Agent-Specific Guidelines

### When Adding New Swift Features:

1. **Match Existing Patterns**: Analyze similar existing code in `MSAL/src/native_auth/` before implementing
2. **Follow MSAL Conventions**: Use `MSAL` prefix for public classes, `MSALNativeAuth` prefix for native auth types
3. **Maintain Consistency**: Match indentation, spacing, and naming in surrounding code
4. **Swift-First API**: Use Swift idioms (`Result`, `async/await`, closures) rather than Objective-C patterns
5. **Error Handling**: Use `do`-`catch`-`try`, `guard`, and `Result` types
6. **Thread Safety**: Use `@MainActor`, actors, or dispatch queues for shared mutable state
7. **Memory Management**: Use `[weak self]` in closures that could cause retain cycles
8. **Documentation**: Add `///` documentation comments for all public APIs
9. **Test Coverage**: Add or update unit tests for every behavior change
10. **SwiftLint**: Ensure code passes the project's SwiftLint configuration

### When Modifying Existing Swift Code:

1. **Preserve Style**: Don't mix styles within a file
2. **Minimal Changes**: Change only what's necessary
3. **Update Comments**: Keep documentation synchronized with code changes
4. **Deprecation**: Use `@available(*, deprecated)` with a message when replacing APIs
5. **Backward Compatibility**: Consider impact on existing integrations and Objective-C interop

### Common MSAL Native Auth Patterns:

#### Delegate Pattern

```swift
public protocol MSALNativeAuthSignInDelegate: AnyObject {
    func onSignInCompleted(_ result: MSALNativeAuthUserAccountResult)
    func onSignInStarted()
    @objc optional func onSignInError(_ error: SignInStartError)
}
```

#### Result Handling Pattern

```swift
func handleResult(_ result: Result<MSALNativeAuthUserAccountResult, Error>) {
    switch result {
    case .success(let accountResult):
        processAccount(accountResult)
    case .failure(let error):
        handleError(error)
    }
}
```

#### Weak Self in Closures

```swift
performAsyncOperation { [weak self] result in
    guard let self = self else { return }
    self.updateState(with: result)
}
```

#### Logging Pattern

```swift
MSALNativeAuthLogMessage.logOperation(
    "Token acquisition",
    context: requestContext,
    result: .success
)
```

### Code Review Checklist:

- [ ] Uses 4-space indentation (no tabs)
- [ ] Opening braces on same line (K&R style)
- [ ] No semicolons
- [ ] No parentheses around top-level conditions
- [ ] Uses `guard` for early exits
- [ ] Error handling uses `do`-`catch`-`try`, not `try!`
- [ ] No force-unwraps without justification comments
- [ ] Types and protocols use `UpperCamelCase`
- [ ] Variables, functions, and enum cases use `lowerCamelCase`
- [ ] Constants use `lowerCamelCase` (no `k` prefix)
- [ ] Public types use `MSAL` prefix
- [ ] Uses shorthand types (`[String]`, `[String: Int]`, `String?`)
- [ ] Uses `///` for documentation comments (not `/** */`)
- [ ] All public declarations are documented
- [ ] Uses `// MARK: -` for code organization
- [ ] Uses trailing closure syntax for single-closure functions
- [ ] Trailing commas in multi-line collection literals
- [ ] Imports ordered lexicographically, not grouped
- [ ] Access control is as restrictive as possible
- [ ] `[weak self]` used in closures that may cause retain cycles
- [ ] Passes SwiftLint without warnings
- [ ] No warnings or errors in build
- [ ] Follows existing MSAL native auth patterns

---

## Repository-Specific Conventions

### Key Differences from Objective-C Guidelines:

1. **Braces on Same Line**: Swift uses K&R style (`{` on same line), unlike the Obj-C convention in this repo
2. **No Semicolons**: Swift does not use semicolons
3. **`guard` over `if`**: Prefer `guard` for preconditions and early exits
4. **Trailing Closures**: Use trailing closure syntax for cleaner async code
5. **`///` Documentation**: Use triple-slash, not Javadoc-style comments
6. **Type Inference**: Rely on Swift's type inference where types are obvious
7. **`enum` Namespacing**: Use caseless enums for constants, not structs with private init

### Objective-C Interop Considerations:

When writing Swift code that bridges to Objective-C:

- **MUST** use `@objc` attribute on methods/properties exposed to Objective-C
- **MUST** use `@objcMembers` on classes where all members need Objective-C visibility
- **SHOULD** annotate classes with `@objc(MSALSwiftClassName)` to control the Objective-C name
- **MUST** ensure delegate protocols inherit from `NSObjectProtocol` when used from Objective-C
- **SHOULD** use `NSObject` as the base class for types instantiated from Objective-C

### Copyright Header

All new Swift files **MUST** include the Microsoft copyright header when added to this repository:

```swift
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

```

---

## References

- [Google Swift Style Guide](https://google.github.io/swift/)
- [Apple: Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [Apple: The Swift Programming Language](https://docs.swift.org/swift-book/)
- [IETF RFC 2119: Key words for use in RFCs](http://tools.ietf.org/html/rfc2119)
- [SwiftLint](https://github.com/realm/SwiftLint)

---

## Notes

This style guide is adapted specifically for AI agents working on the Swift portions of the Microsoft Authentication Library (MSAL) for iOS and macOS. When in doubt, prioritize consistency with existing codebase patterns in `MSAL/src/native_auth/` over strict adherence to external style guides.