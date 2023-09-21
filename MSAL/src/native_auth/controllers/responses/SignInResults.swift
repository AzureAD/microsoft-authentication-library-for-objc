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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation

/// Represents the result of sign in using password.
enum SignInPasswordStartResult {
    /// Returned after the sign in operation completed successfully. An object representing the signed in user account is returned.
    case completed(MSALNativeAuthUserAccountResult)

    /// Returned if a user registered with email and code tries to sign in using password.
    /// In this case MSAL will discard the password and will continue the sign in flow with code.
    ///
    /// - newState: An object representing the new state of the flow with follow on methods.
    /// - sentTo: The email/phone number that the code was sent to.
    /// - channelTargetType: The channel (email/phone) the code was sent through.
    /// - codeLength: The length of the code required.
    case codeRequired(newState: SignInCodeRequiredState, sentTo: String, channelTargetType: MSALNativeAuthChannelType, codeLength: Int)

    /// An error object indicating why the operation failed.
    case error(SignInPasswordStartError)
}

/// Represents the result of sign in using code.
enum SignInStartResult {
    /// Returned if a user has received an email with code.
    ///
    /// - newState: An object representing the new state of the flow with follow on methods.
    /// - sentTo: The email/phone number that the code was sent to.
    /// - channelTargetType: The channel (email/phone) the code was sent through.
    /// - codeLength: The length of the code required.
    case codeRequired(newState: SignInCodeRequiredState, sentTo: String, channelTargetType: MSALNativeAuthChannelType, codeLength: Int)

    /// Returned if a user registered with email and password tries to sign in using code.
    case passwordRequired(newState: SignInPasswordRequiredState)

    /// An error object indicating why the operation failed.
    case error(SignInStartError)
}

/// Result type that contains information about the code sent, the next state of the reset password process and possible errors.
/// See ``CodeRequiredGenericResult`` for more information.
typealias SignInResendCodeResult = CodeRequiredGenericResult<SignInCodeRequiredState, ResendCodeError>

/// Result type that contains information about the state of the sign in process.
enum SignInPasswordRequiredResult {
    /// Returned after the sign in operation completed successfully. An object representing the signed in user account is returned.
    case completed(MSALNativeAuthUserAccountResult)

    /// An error object indicating why the operation failed. It may contain a ``SignInPasswordRequiredState`` to continue the flow.
    case error(error: PasswordRequiredError, newState: SignInPasswordRequiredState?)
}

/// Result type that contains information about the state of the sign in process.
enum SignInVerifyCodeResult {
    /// Returned after the sign in operation completed successfully. An object representing the signed in user account is returned.
    case completed(MSALNativeAuthUserAccountResult)

    /// An error object indicating why the operation failed. It may contain a ``SignInPasswordRequiredState`` to continue the flow.
    case error(error: VerifyCodeError, newState: SignInCodeRequiredState?)
}
