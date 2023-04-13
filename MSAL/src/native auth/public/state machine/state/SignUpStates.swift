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

@objcMembers
public class SignUpCodeSentState: MSALNativeAuthBaseState {
    public func resendCode(delegate: SignUpResendCodeDelegate, correlationId: UUID? = nil) {
//        guard isActive else {
//            delegate.onSignUpResendCodeError(error: ResendCodeError(type: .generalError), newState: nil)
//        }
        if correlationId != nil {
            delegate.onSignUpResendCodeError(error: ResendCodeError(type: .accountTemporarilyLocked), newState: self)
        } else {
            delegate.onSignUpResendCodeSent(newState: self, displayName: "email@contoso.com", codeLength: 4)
        }
    }

    public func submitCode(code: String, delegate: SignUpVerifyCodeDelegate, correlationId: UUID? = nil) {
        switch code {
        case "0000": delegate.onSignUpVerifyCodeError(error: VerifyCodeError(type: .invalidCode), newState: self)
        case "2222": delegate.onSignUpVerifyCodeError(error: VerifyCodeError(type: .generalError), newState: self)
        case "3333": delegate.onSignUpVerifyCodeError(error: VerifyCodeError(type: .redirect), newState: nil)
        case "5555": delegate.onPasswordRequired(newState: SignUpPasswordRequiredState(flowToken: flowToken))
        case "6666": delegate.onSignUpAttributesRequired(newState: SignUpAttributesRequiredState(flowToken: flowToken))
        default: delegate.onSignUpCompleted()
        }
    }
}

@objcMembers
public class SignUpPasswordRequiredState: MSALNativeAuthBaseState {
    public func submitPassword(password: String, delegate: SignUpPasswordRequiredDelegate, correlationId: UUID? = nil) {
        switch password {
        case "redirect": delegate.onSignUpPasswordRequiredError(
            error: PasswordRequiredError(type: .redirect), newState: nil)
        case "generalerror": delegate.onSignUpPasswordRequiredError(
            error: PasswordRequiredError(type: .generalError),
            newState: self)
        case "invalid": delegate.onSignUpPasswordRequiredError(
            error: PasswordRequiredError(type: .invalidPassword),
            newState: self)
        case "attributesRequired": delegate.onSignUpAttributesRequired(newState:
                                                                SignUpAttributesRequiredState(flowToken: flowToken)
        )
        default: delegate.onSignUpCompleted()
        }
    }
}

@objcMembers
public class SignUpAttributesRequiredState: MSALNativeAuthBaseState {
    public func submitAttributes(
        attributes: [String: Any],
        delegate: SignUpAttributesRequiredDelegate,
        correlationId: UUID? = nil) {
            guard let key = attributes.keys.first else {
                delegate.onSignUpAttributesRequiredError(
                    error: AttributesRequiredError(type: .invalidAttributes),
                    newState: self)
                return
            }
            switch key {
            case "general": delegate.onSignUpAttributesRequiredError(
                error: AttributesRequiredError(type: .generalError),
                newState: self)
            case "redirect": delegate.onSignUpAttributesRequiredError(
                error: AttributesRequiredError(type: .redirect),
                newState: nil)
            default: delegate.onSignUpCompleted()
            }
    }
}
