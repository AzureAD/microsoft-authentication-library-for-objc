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

@objc
public protocol SignUpPasswordStartDelegate {
    func onSignUpError(error: SignUpStartError)
    func onSignUpCodeRequired(newState: SignUpCodeRequiredState,
                              sentTo: String,
                              channelTargetType: MSALNativeAuthChannelType,
                              codeLength: Int)
}

@objc
public protocol SignUpCodeStartDelegate {
    func onSignUpCodeError(error: SignUpCodeStartError)
    func onSignUpCodeRequired(newState: SignUpCodeRequiredState,
                              sentTo: String,
                              channelTargetType: MSALNativeAuthChannelType,
                              codeLength: Int)
}

@objc
public protocol SignUpCodeVerifyCodeDelegate {
    func onSignUpCodeVerifyCodeError(error: VerifyCodeError, newState: SignUpCodeRequiredState?)
    @objc optional func onSignUpCodeAttributesRequired(newState: SignUpAttributesRequiredState)
    func onSignUpCodeCompleted()
}

@objc
public protocol SignUpVerifyCodeDelegate {
    func onSignUpVerifyCodeError(error: VerifyCodeError, newState: SignUpCodeRequiredState?)
    @objc optional func onSignUpAttributesRequired(newState: SignUpAttributesRequiredState)
    @objc optional func onSignUpPasswordRequired(newState: SignUpPasswordRequiredState)
    func onSignUpCompleted()
}

@objc
public protocol SignUpResendCodeDelegate {
    func onSignUpResendCodeError(error: MSALNativeAuthGenericError, newState: SignUpCodeRequiredState?)
    func onSignUpResendCodeRequired(newState: SignUpCodeRequiredState,
                                    sentTo: String,
                                    channelTargetType: MSALNativeAuthChannelType,
                                    codeLength: Int)
}

@objc
public protocol SignUpPasswordRequiredDelegate {
    func onSignUpPasswordRequiredError(error: PasswordRequiredError, newState: SignUpPasswordRequiredState?)
    @objc optional func onSignUpAttributesRequired(newState: SignUpAttributesRequiredState)
    func onSignUpCompleted()
}

@objc
public protocol SignUpAttributesRequiredDelegate {
    func onSignUpAttributesRequiredError(error: AttributesRequiredError, newState: SignUpAttributesRequiredState?)
    func onSignUpCompleted()
}
