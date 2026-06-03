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
import os
import MSAL

/// Lightweight logger that reuses MSAL's log level configuration.
///
/// Uses Apple's unified logging (`os.Logger`) for output, while respecting
/// the MSAL log level set on `MSALGlobalConfig.loggerConfig.logLevel`.
///
/// **Privacy:** This logger NEVER logs tokens, phone numbers, email addresses,
/// credential IDs, continuation tokens, or full HAL payloads.
internal enum CredentialManagementLogger
{
    private static let logger = os.Logger(
        subsystem: "com.microsoft.identity.client",
        category: "CredentialManagement"
    )

    /// Log a non-PII message at the specified level.
    static func log(
        level: MSALLogLevel,
        correlationId: UUID? = nil,
        message: String
    )
    {
        let loggerConfig = MSALGlobalConfig.loggerConfig
        guard level.rawValue <= loggerConfig.logLevel.rawValue else { return }

        let formatted: String
        if let correlationId = correlationId
        {
            formatted = "[CredMgmt][\(correlationId.uuidString)] \(message)"
        }
        else
        {
            formatted = "[CredMgmt] \(message)"
        }

        switch level
        {
        case .error:
            logger.error("\(formatted, privacy: .public)")
        case .warning:
            logger.warning("\(formatted, privacy: .public)")
        case .verbose:
            logger.debug("\(formatted, privacy: .public)")
        default:
            logger.info("\(formatted, privacy: .public)")
        }
    }

    /// Log a message containing PII (only delivered when masking allows it).
    static func logPII(
        level: MSALLogLevel,
        correlationId: UUID? = nil,
        message: String
    )
    {
        let loggerConfig = MSALGlobalConfig.loggerConfig
        guard loggerConfig.logMaskingLevel == .settingsMaskSecretsOnly else { return }
        guard level.rawValue <= loggerConfig.logLevel.rawValue else { return }

        let formatted: String
        if let correlationId = correlationId
        {
            formatted = "[CredMgmt][\(correlationId.uuidString)][PII] \(message)"
        }
        else
        {
            formatted = "[CredMgmt][PII] \(message)"
        }

        logger.debug("\(formatted, privacy: .private)")
    }
}
