// ------------------------------------------------------------------------------
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
// ------------------------------------------------------------------------------

import Foundation

/// A redacted MFA failure. No activation material or service response body is included.
public enum MSALNativeAuthMFAServiceError: Error, Equatable, Sendable {
    case invalidActivationInput
    case untrustedEndpoint
    case invalidResponse
    case transportFailure
    case httpFailure(statusCode: Int)
    /// A service rejection with a bounded numeric code or SDK-defined category, never a raw service description.
    case serviceFailure(operation: String, code: String)
    case storageFailure(status: Int32)
    case operationInProgress
    case validationTimedOut
    case unexpectedNotification
    case unknownAccount
    case invalidSession
    case unsupportedPolicy
    case invalidNumber
    case outcomeUnknown
    /// Construct the manager with registration deletion explicitly enabled.
    case registrationDeletionDisabled
    /// Graph deletion is not configured for this registration's cloud.
    case unsupportedDeletionCloud
    /// The provider returned an expired, empty, or unsuitable Graph token.
    case invalidDeletionToken
    /// The sign-in result does not belong to the registration's tenant and user.
    case deletionAccountMismatch
}
