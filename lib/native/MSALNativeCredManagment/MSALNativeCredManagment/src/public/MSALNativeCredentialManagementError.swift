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
///
/// - Note: This enum currently contains only a general error case.
///   Additional error cases will be added once the error contract is finalized.
@objc public enum MSALNativeCredentialManagementErrorType: Int
{
    /// A general, unclassified error occurred.
    case generalError = 0
}

/// Error class for credential management operations.
///
/// Contains a typed error code, human-readable message, and optional correlation ID
/// for diagnostics.
///
/// - Important: The `message` property must never contain tokens, credentials, or PII.
///   Use only for diagnostic text safe for logging.
@objcMembers
public class MSALNativeCredentialManagementError: NSObject, Error
{
    /// The type of error that occurred.
    public let type: MSALNativeCredentialManagementErrorType

    /// A human-readable error message describing what went wrong.
    ///
    /// - Important: Must not contain tokens, PII, or sensitive data.
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
        if let correlationId = correlationId
        {
            desc += ", correlationId: \(correlationId)"
        }
        desc += ")"
        return desc
    }
}
