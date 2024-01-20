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

enum SignUpStartResult {
    case codeRequired(newState: SignUpCodeRequiredState, sentTo: String, channelTargetType: MSALNativeAuthChannelType, codeLength: Int)
    case attributesInvalid([String])
    case error(SignUpStartError)
}

enum SignUpVerifyCodeResult {
    case completed(SignInAfterSignUpState)
    case passwordRequired(SignUpPasswordRequiredState)
    case attributesRequired(attributes: [MSALNativeAuthRequiredAttribute], newState: SignUpAttributesRequiredState)
    case error(error: VerifyCodeError, newState: SignUpCodeRequiredState?)
}

typealias SignUpResendCodeResult = CodeRequiredGenericResult<SignUpCodeRequiredState, ResendCodeError>

enum SignUpPasswordRequiredResult {
    case completed(SignInAfterSignUpState)
    case attributesRequired(attributes: [MSALNativeAuthRequiredAttribute], newState: SignUpAttributesRequiredState)
    case error(error: PasswordRequiredError, newState: SignUpPasswordRequiredState?)
}

enum SignUpAttributesRequiredResult {
    case completed(SignInAfterSignUpState)
    case attributesRequired(attributes: [MSALNativeAuthRequiredAttribute], state: SignUpAttributesRequiredState)
    case attributesInvalid(attributes: [String], newState: SignUpAttributesRequiredState)
    case error(error: AttributesRequiredError)
}
