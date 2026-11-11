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
// furnished to do so, subject to the following conditions:
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

import Foundation

/// A standalone MFA operation failure shared by all MFA manager methods.
///
/// Exactly one classifier is true. Use its documented caller action, not diagnostic text or service codes.
/// This type does not inherit from Native Auth errors or expose browser/interaction-required properties.
/// Providers own authentication fallback; unhandled interaction requirements become general errors.
/// Raw provider errors, response bodies, claims, notification payloads and credentials are never exposed.
///
/// Recovery does not automatically authorize replay. Failure or cancellation does not imply rollback;
/// preserve replay protection and confirmed partial outcomes. Swift `CancellationError` propagates separately.
/// The API-review stubs always report a general not-implemented error.
@objcMembers
public final class MSALNativeAuthMFAError: NSObject, LocalizedError {
    enum ErrorType: CaseIterable, Sendable {
        case pushTokenMissing
        case registrationNotFound
        case invalidChallenge
        case invalidCode
        case userSignedInWithMismatchedAccount
        case userCancelled
        case generalError
    }

    private let type: ErrorType
    private let message: String?

    /// Optional bounded, sanitized SDK-controlled diagnostics, not necessarily a verbatim service message.
    /// Do not parse this description for control flow.
    public var errorDescription: String? { message }

    /// SDK-generated operation correlation ID, available even for local failures before a request is sent.
    /// Propagated through requests where supported; not a server-generated error field or session GUID.
    public let correlationId: UUID

    init(
        type: ErrorType,
        errorDescription: String?,
        correlationId: UUID
    ) {
        self.type = type
        self.message = errorDescription
        self.correlationId = correlationId
        super.init()
    }

    /// A required push token has not been supplied. Supply it through `updatePushRegistration`.
    /// Invalid token data, storage failures and unsuccessful rotation are not missing-token conditions.
    public var isPushTokenMissing: Bool { type == .pushTokenMissing }

    /// The explicitly requested registration does not exist locally. Reload the registered-auth-method list.
    /// An empty list is successful; storage failures and in-flight context mismatches are general errors.
    public var isRegistrationNotFound: Bool { type == .registrationNotFound }

    /// An authoritative outcome establishes that the session is unusable, including a known completed or
    /// replay-blocked manager-issued session. Discard it. Malformed or untrusted context is a general error.
    public var isInvalidChallenge: Bool { type == .invalidChallenge }

    /// The matching number is invalid and another attempt on the same session is permitted. Ask for the number again.
    /// Pre-submission format failures can qualify; service rejections require confirmed continuation semantics.
    /// An uncertain submission outcome is a general error, not permission to retry.
    public var isInvalidCode: Bool { type == .invalidCode }

    /// The acquired token-provider identity differs from the registration. Request sign-in with the expected account.
    /// Internal notification/registration association failures are general errors.
    public var isUserSignedInWithMismatchedAccount: Bool { type == .userSignedInWithMismatchedAccount }

    /// The user explicitly cancelled provider authentication. End the interaction without restarting authentication.
    /// Swift task cancellation propagates as `CancellationError`, not this classification.
    public var isUserCancelled: Bool { type == .userCancelled }

    /// No supported application recovery is established. End the operation and record only safe diagnostics.
    /// Includes unexpected data/protocol, storage, configuration, busy/partial-write and uncertain-outcome failures,
    /// plus unclassified service/provider failures. Do not automatically retry; this does not prove permanent failure.
    public var isGeneralError: Bool { type == .generalError }
}
