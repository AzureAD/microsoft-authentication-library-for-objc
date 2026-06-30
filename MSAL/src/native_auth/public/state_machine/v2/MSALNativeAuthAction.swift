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

/// Actions the server can request during a Native Auth V2 (server-driven) flow.
///
/// In V2 the server drives the flow: each step the SDK reports an
/// ``MSALNativeAuthAction`` through ``MSALNativeAuthFlowDelegate/onActionRequired(action:flowState:)``
/// and the app continues by calling the corresponding method on the supplied
/// ``MSALNativeAuthFlowState``.
public enum MSALNativeAuthAction {

    /// The server requires the user to verify a one-time code.
    /// Continue with ``MSALNativeAuthFlowState/submitCode(_:delegate:)``.
    case codeRequired(sentTo: String, channel: MSALNativeAuthChannelType, codeLength: Int)

    /// The server requires the user to enter their password.
    /// Continue with ``MSALNativeAuthFlowState/submitPassword(_:delegate:)``.
    case passwordRequired

    /// The server requires the user to enter a new password (self-service password reset).
    /// Continue with ``MSALNativeAuthFlowState/submitNewPassword(_:delegate:)``.
    case newPasswordRequired

    /// The server requires additional user attributes.
    /// Continue with ``MSALNativeAuthFlowState/submitAttributes(_:delegate:)``.
    case attributesRequired(attributes: [MSALNativeAuthRequiredAttribute])

    /// The server reports that some attributes were invalid and must be corrected.
    case attributesInvalid(attributeNames: [String])

    /// The server requires multi-factor authentication; the user must select an auth method.
    /// Continue with ``MSALNativeAuthFlowState/selectAuthMethod(_:verificationContact:delegate:)``.
    case mfaRequired(authMethods: [MSALAuthMethod])

    /// The server sent an MFA challenge; the user must enter the verification code.
    /// Continue with ``MSALNativeAuthFlowState/submitChallenge(_:delegate:)``.
    case mfaVerificationRequired(sentTo: String, channel: MSALNativeAuthChannelType, codeLength: Int)

    /// The server requires strong authentication registration (JIT); the user must select an auth method.
    case strongAuthRegistrationRequired(authMethods: [MSALAuthMethod])

    /// The server sent a JIT challenge; the user must enter the verification code.
    case strongAuthVerificationRequired(sentTo: String, channel: MSALNativeAuthChannelType, codeLength: Int)
}
