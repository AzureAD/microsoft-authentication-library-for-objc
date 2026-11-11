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
import MSAL
@_implementationOnly import MSAL_Private

/// Convenience extension for logging in the credential management module.
///
/// Provides a simple `log(level:correlationId:message:)` API that delegates to
/// `MSIDLogger` from IdentityCore. MSAL is the base module — we use its
/// logging infrastructure directly, no wrappers.
///
/// **Privacy:** This extension NEVER logs tokens, phone numbers, email addresses,
/// credential IDs, continuation tokens, or full HAL payloads.
extension MSIDLogger
{
    /// Log a non-PII message using `MSALLogLevel` (public SDK enum).
    func log(
        level: MSALLogLevel,
        correlationId: UUID? = nil,
        message: String,
        filename: String = #fileID,
        lineNumber: Int = #line,
        function: String = #function
    )
    {
        self.log(
            with: msidLogLevel(from: level),
            context: nil,
            correlationId: correlationId,
            containsPII: false,
            filename: filename,
            lineNumber: UInt(lineNumber),
            function: function,
            format: "[CredMgmt] %@",
            formatArgs: getVaList([message])
        )
    }

    /// Log a PII message (only delivered when masking allows it).
    func logPII(
        level: MSALLogLevel,
        correlationId: UUID? = nil,
        message: String,
        filename: String = #fileID,
        lineNumber: Int = #line,
        function: String = #function
    )
    {
        self.log(
            with: msidLogLevel(from: level),
            context: nil,
            correlationId: correlationId,
            containsPII: true,
            filename: filename,
            lineNumber: UInt(lineNumber),
            function: function,
            format: "[CredMgmt] %@",
            formatArgs: getVaList([message])
        )
    }

    private func msidLogLevel(from msalLevel: MSALLogLevel) -> MSIDLogLevel
    {
        switch msalLevel
        {
        case .error:
            return .error
        case .warning:
            return .warning
        case .info:
            return .info
        case .verbose:
            return .verbose
        case .last:
            return .last
        case .nothing:
            return .nothing
        @unknown default:
            return .info
        }
    }
}
