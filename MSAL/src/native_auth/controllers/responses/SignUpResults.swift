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

enum SignUpPasswordStartResult {
    /// Returned if a user has received an email with code.
    ///
    /// - newState: An object representing the new state of the flow with follow on methods.
    /// - sentTo: The email/phone number that the code was sent to.
    /// - channelTargetType: The channel (email/phone) the code was sent through.
    /// - codeLength: The length of the code required.
    case codeRequired(newState: SignUpCodeRequiredState, sentTo: String, channelTargetType: MSALNativeAuthChannelType, codeLength: Int)

    /// Returned when the attributes sent are invalid.
    case attributesInvalid([String])

    /// An error object indicating why the operation failed.
    case error(SignUpPasswordStartError)
}

enum SignUpStartResult {
    /// Returned if a user has received an email with code.
    ///
    /// - newState: An object representing the new state of the flow with follow on methods.
    /// - sentTo: The email/phone number that the code was sent to.
    /// - channelTargetType: The channel (email/phone) the code was sent through.
    /// - codeLength: The length of the code required.
    case codeRequired(newState: SignUpCodeRequiredState, sentTo: String, channelTargetType: MSALNativeAuthChannelType, codeLength: Int)

    /// Returned when the attributes sent are invalid.
    case attributesInvalid([String])

    /// An error object indicating why the operation failed.
    case error(SignUpStartError)
}

/// An object of this type is returned after a user submits the code sent to their email/phone.
/// It contains the next state of the flow with follow on methods, depending on the server's response.
enum SignUpVerifyCodeResult {
    /// Returned after the sign up operation completed successfully.
    case completed(SignInAfterSignUpState)

    /// Returned when a password is required.
    case passwordRequired(SignUpPasswordRequiredState)

    /// Returned when attributes are required.
    case attributesRequired(attributes: [MSALNativeAuthRequiredAttributes], newState: SignUpAttributesRequiredState)

    /// An error object indicating why the operation failed.
    case error(error: VerifyCodeError, newState: SignUpCodeRequiredState?)
}

/// Result type that contains information about the code sent, the next state of the reset password process and possible errors.
/// See ``CodeRequiredGenericResult`` for more information.
typealias SignUpResendCodeResult = CodeRequiredGenericResult<SignUpCodeRequiredState, ResendCodeError>

/// An object of this type is returned after a user submits their password.
/// It contains the next state of the flow with follow on methods, depending on the server's response.
enum SignUpPasswordRequiredResult {
    /// Returned after the sign up operation completed successfully.
    case completed(SignInAfterSignUpState)

    /// Returned when attributes are required.
    case attributesRequired(attributes: [MSALNativeAuthRequiredAttributes], newState: SignUpAttributesRequiredState)

    /// An error object indicating why the operation failed.
    case error(error: PasswordRequiredError, newState: SignUpPasswordRequiredState?)
}

enum SignUpAttributesRequiredResult {
    /// Returned after the sign up operation completed successfully.
    case completed(SignInAfterSignUpState)

    /// Returned when attributes are required.
    case attributesRequired(attributes: [MSALNativeAuthRequiredAttributes], state: SignUpAttributesRequiredState)

    /// Returned when the attributes sent are invalid.
    case attributesInvalid(attributes: [String], newState: SignUpAttributesRequiredState)

    /// An error object indicating why the operation failed.
    case error(error: AttributesRequiredError)
}
