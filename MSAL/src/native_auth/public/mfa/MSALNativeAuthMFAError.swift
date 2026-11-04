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

/// An MFA operation failure using the shared Native Auth diagnostic structure.
///
/// Inspect the Boolean classifications rather than parsing the description. Descriptions contain only
/// SDK-controlled diagnostics; raw provider errors, response bodies and credentials are not exposed.
/// `errorCodes` contains service-provided numeric codes, not HTTP statuses, Keychain statuses or local enum values.
/// The API-review stubs always report a general not-implemented error.
///
/// A failure does not imply that a submitted operation was rolled back or can safely be retried.
@objcMembers
public final class MSALNativeAuthMFAError: MSALNativeAuthError {
    enum ErrorType: CaseIterable {
        case generalError
        case invalidArgument
        case networkError
        case itemNotFound
        case userInteractionRequired
        case userCancelled
        case userSignedInWithMismatchedAccount
        case storageError
        case operationNotAllowed
        case invalidRegistration
        case authNotificationError
    }

    let type: ErrorType

    init(
        type: ErrorType,
        errorDescription: String,
        correlationId: UUID,
        errorCodes: [Int] = [],
        isBrowserRequired: Bool = false
    ) {
        self.type = type
        super.init(
            message: errorDescription, correlationId: correlationId, errorCodes: errorCodes,
            isBrowserRequired: isBrowserRequired, isGeneralError: type == .generalError
        )
    }

    /// The caller supplied invalid input. Correct it before starting another operation.
    public var isInvalidArgument: Bool { type == .invalidArgument }
    /// Communication failed or validation timed out. A write may already have reached the service.
    public var isNetworkError: Bool { type == .networkError }
    /// Required local account or registration state was not found.
    public var isItemNotFound: Bool { type == .itemNotFound }
    /// Token acquisition requires user interaction. This does not necessarily require a browser.
    public var isUserInteractionRequired: Bool { type == .userInteractionRequired }
    /// The user cancelled sign-in. This is distinct from Swift task cancellation.
    public var isUserCancelled: Bool { type == .userCancelled }
    /// The acquired token's identity or authority does not match the registration.
    public var isUserSignedInWithMismatchedAccount: Bool { type == .userSignedInWithMismatchedAccount }
    /// Registration storage or a required stored secret could not be accessed.
    public var isStorageError: Bool { type == .storageError }
    /// Current operation state or the supported environment prevents this operation.
    /// This includes conflicting work and retained uncertain enrollment outcomes; do not blindly retry.
    public var isOperationNotAllowed: Bool { type == .operationNotAllowed }
    /// The device token or registration is invalid.
    public var isInvalidRegistration: Bool { type == .invalidRegistration }
    /// The notification/session is invalid, already processed, or unsupported.
    public var isAuthNotificationError: Bool { type == .authNotificationError }
}
