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

/// Unified error type surfaced by the Native Auth V2 (server-driven) flows.
///
/// A single error type is used across all V2 flows so that an app's
/// ``MSALNativeAuthFlowDelegate`` has only one error shape to inspect, mirroring
/// the unified delegate contract described in the V2 interface.
@objcMembers
public class MSALNativeAuthFlowError: NSObject, LocalizedError {

    /// High level classification of the V2 flow error.
    public enum Kind: Int {
        /// The requested flow (or one of its steps) is not implemented yet.
        case notImplemented
        /// The provided username was not accepted by the server (e.g. AADSTS50034 user not found).
        case userNotFound
        /// The submitted one-time code was invalid or expired.
        case invalidCode
        /// The continuation token was rejected by the server (wrong endpoint, tampered or expired).
        case invalidContinuationToken
        /// The submitted password did not meet the server's requirements.
        case invalidPassword
        /// The username supplied to the SDK failed local validation.
        case invalidUsername
        /// The flow must continue in a web browser.
        case browserRequired
        /// A generic / unexpected error occurred.
        case generalError
    }

    /// The classification of this error.
    public let kind: Kind

    /// A developer-facing description of the error.
    public let errorDescription: String?

    /// Server error codes associated with this error, when available.
    public let errorCodes: [Int]

    /// UUID correlating this error with the server logs, when available.
    public let correlationId: UUID?

    init(
        kind: Kind,
        errorDescription: String? = nil,
        errorCodes: [Int] = [],
        correlationId: UUID? = nil
    ) {
        self.kind = kind
        self.errorDescription = errorDescription
        self.errorCodes = errorCodes
        self.correlationId = correlationId
    }

    /// Whether the flow that produced this error is not implemented yet.
    public var isNotImplemented: Bool {
        return kind == .notImplemented
    }

    /// Whether the submitted one-time code was invalid.
    public var isInvalidCode: Bool {
        return kind == .invalidCode
    }

    /// Whether the submitted password was rejected (wrong credentials at sign in, or a password
    /// that did not satisfy the server's policy during sign up).
    public var isInvalidPassword: Bool {
        return kind == .invalidPassword
    }

    /// Whether the username was not found in the directory.
    public var isUserNotFound: Bool {
        return kind == .userNotFound
    }

    /// Whether the continuation token was rejected by the server.
    public var isInvalidContinuationToken: Bool {
        return kind == .invalidContinuationToken
    }
}
