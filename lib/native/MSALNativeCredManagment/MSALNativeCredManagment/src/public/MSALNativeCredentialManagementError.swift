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

import Foundation

/// Error domain for credential management operations.
public let MSALNativeCredentialManagementErrorDomain = "MSALNativeCredentialManagementErrorDomain"

/// Error types for credential management operations.
@objc public enum MSALNativeCredentialManagementErrorType: Int {
    /// A general, unclassified error occurred.
    case generalError = 0
    /// A network error occurred (timeout, connectivity, etc.).
    case networkError = 1
    /// The access token is invalid or expired.
    case unauthorized = 2
    /// The user lacks permission for this operation.
    case forbidden = 3
    /// The specified credential method was not found.
    case notFound = 4
    /// A conflict occurred (e.g., method already registered).
    case conflict = 5
    /// Challenge verification failed.
    case challengeFailed = 6
    /// The token provider reports no valid session.
    case sessionExpired = 7
    /// The client configuration is invalid.
    case invalidConfiguration = 8
}

/// Error class for credential management operations.
///
/// Contains a typed error code, human-readable message, and optional correlation ID
/// for diagnostics.
@objcMembers
public class MSALNativeCredentialManagementError: NSObject, Error {

    /// The type of error that occurred.
    public let type: MSALNativeCredentialManagementErrorType

    /// A human-readable error message describing what went wrong.
    public let message: String?

    /// The correlation ID associated with this error for diagnostic purposes.
    public let correlationId: UUID?

    /// The underlying error, if any.
    public let underlyingError: Error?

    internal init(
        type: MSALNativeCredentialManagementErrorType,
        message: String? = nil,
        correlationId: UUID? = nil,
        underlyingError: Error? = nil
    )
    {
        self.type = type
        self.message = message
        self.correlationId = correlationId
        self.underlyingError = underlyingError
        super.init()
    }

    public override var description: String
    {
        var desc = "MSALNativeCredentialManagementError(type: \(type)"
        if let message = message
        {
            desc += ", message: \(message)"
        }
        if let correlationId = correlationId
        {
            desc += ", correlationId: \(correlationId)"
        }
        desc += ")"
        return desc
    }
}
