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
public class MSALNativeAuthFlowError: MSALNativeAuthError {

    /// High level classification of the V2 flow error.
    enum ErrorType: CaseIterable {
        /// The requested flow (or one of its steps) is not implemented yet.
        case notImplemented
        /// The provided username was not accepted by the server (e.g. AADSTS50034 user not found).
        case userNotFound
        /// The submitted one-time code was invalid or expired.
        case invalidCode
        /// The continuation token was rejected by the server (wrong endpoint, tampered or expired).
        case invalidContinuationToken
        /// The submitted password did not meet the server's requirements (e.g. too weak during sign up).
        case invalidPassword
        /// The username and/or password supplied at sign in were not accepted by the server.
        case invalidCredentials
        /// The username supplied to the SDK failed local validation.
        case invalidUsername
        /// The account does not have a password associated with it (sign in / reset must use a code flow).
        case userDoesNotHavePassword
        /// An account already exists for the supplied username during sign up.
        case userAlreadyExists
        /// The submitted authentication challenge (e.g. an MFA one-time value) was rejected by the server.
        case invalidChallenge
        /// The server blocked the requested strong authentication method.
        case authMethodBlocked
        /// The server blocked the verification contact (email/phone) provided for strong authentication.
        case verificationContactBlocked
        /// The input supplied for a strong authentication registration step was invalid.
        case invalidInput
        /// The flow must continue in a web browser.
        case browserRequired
        /// A generic / unexpected error occurred.
        case generalError
    }

    let type: ErrorType

    init(
        type: ErrorType,
        errorDescription: String? = nil,
        errorCodes: [Int] = [],
        correlationId: UUID,
        errorUri: String? = nil
    ) {
        self.type = type
        super.init(message: errorDescription, correlationId: correlationId, errorCodes: errorCodes, errorUri: errorUri, isBrowserRequired: type == .browserRequired)
    }

    /// Describes why an error occurred and provides more information about the error.
    public override var errorDescription: String? {
        if let description = super.errorDescription {
            return description
        }

        switch type {
        case .notImplemented:
            return MSALNativeAuthErrorMessage.notImplemented
        case .userNotFound:
            return MSALNativeAuthErrorMessage.userNotFound
        case .invalidCode:
            return MSALNativeAuthErrorMessage.invalidCode
        case .invalidContinuationToken:
            return MSALNativeAuthErrorMessage.invalidContinuationToken
        case .invalidPassword:
            return MSALNativeAuthErrorMessage.invalidPassword
        case .invalidCredentials:
            return MSALNativeAuthErrorMessage.invalidCredentials
        case .invalidUsername:
            return MSALNativeAuthErrorMessage.invalidUsername
        case .userDoesNotHavePassword:
            return MSALNativeAuthErrorMessage.userDoesNotHavePassword
        case .userAlreadyExists:
            return MSALNativeAuthErrorMessage.userAlreadyExists
        case .invalidChallenge:
            return MSALNativeAuthErrorMessage.invalidChallenge
        case .authMethodBlocked:
            return MSALNativeAuthErrorMessage.authMethodBlocked
        case .verificationContactBlocked:
            return MSALNativeAuthErrorMessage.verificationContactBlocked
        case .invalidInput:
            return MSALNativeAuthErrorMessage.invalidInput
        case .browserRequired:
            return MSALNativeAuthErrorMessage.browserRequired
        case .generalError:
            return MSALNativeAuthErrorMessage.generalError
        }
    }

    /// Whether the flow that produced this error is not implemented yet.
    public var isNotImplemented: Bool {
        return type == .notImplemented
    }

    /// Whether the username was not found in the directory.
    public var isUserNotFound: Bool {
        return type == .userNotFound
    }

    /// Whether the submitted one-time code was invalid.
    public var isInvalidCode: Bool {
        return type == .invalidCode
    }

    /// Whether the continuation token was rejected by the server.
    public var isInvalidContinuationToken: Bool {
        return type == .invalidContinuationToken
    }

    /// Whether the submitted password was rejected because it did not satisfy the server's
    /// policy during sign up (e.g. too weak, too short).
    public var isInvalidPassword: Bool {
        return type == .invalidPassword
    }

    /// Whether the username and/or password supplied at sign in were not accepted by the server.
    public var isInvalidCredentials: Bool {
        return type == .invalidCredentials
    }

    /// Whether the username supplied to the SDK failed local validation.
    public var isInvalidUsername: Bool {
        return type == .invalidUsername
    }

    /// Whether the account does not have a password associated with it (a code flow must be used).
    public var isUserDoesNotHavePassword: Bool {
        return type == .userDoesNotHavePassword
    }

    /// Whether an account already exists for the supplied username during sign up.
    public var isUserAlreadyExists: Bool {
        return type == .userAlreadyExists
    }

    /// Whether the submitted authentication challenge was rejected by the server.
    public var isInvalidChallenge: Bool {
        return type == .invalidChallenge
    }

    /// Whether the server blocked the requested strong authentication method.
    public var isAuthMethodBlocked: Bool {
        return type == .authMethodBlocked
    }

    /// Whether the server blocked the verification contact provided for strong authentication.
    public var isVerificationContactBlocked: Bool {
        return type == .verificationContactBlocked
    }

    /// Whether the input supplied for a strong authentication registration step was invalid.
    public var isInvalidInput: Bool {
        return type == .invalidInput
    }
}
