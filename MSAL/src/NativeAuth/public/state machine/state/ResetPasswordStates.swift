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
public class CodeSentResetPasswordState: MSALNativeAuthBaseState {
    public func resendCode(delegate: ResendCodeResetPasswordDelegate, correlationId: UUID? = nil) {
        if correlationId != nil {
            delegate.onResendCodeError(error: ResendCodeError(type: .accountTemporarilyLocked), state: self)
        } else {
            delegate.onCodeSent(state: self, displayName: "email@contoso.com", codeLength: 4)
        }
    }

    public func verifyCode(code: String, delegate: VerifyCodeResetPasswordDelegate, correlationId: UUID? = nil) {
        switch code {
        case "0000": delegate.onVerifyCodeError(error: VerifyCodeError(type: .invalidCode), state: self)
        case "2222": delegate.onVerifyCodeError(error: VerifyCodeError(type: .generalError), state: self)
        case "3333": delegate.onVerifyCodeError(error: VerifyCodeError(type: .redirect), state: nil)
        default: delegate.passwordRequired(state: PasswordRequiredResetPasswordState(flowToken: flowToken))
        }
    }
}

@objcMembers
public class PasswordRequiredResetPasswordState: MSALNativeAuthBaseState {
    public func submitPassword(
        password: String,
        delegate: PasswordRequiredResetPasswordDelegate,
        correlationId: UUID? = nil) {
            switch password {
            case "redirect": delegate.onPasswordRequiredError(error: PasswordRequiredError(type: .redirect), state: nil)
            case "generalerror": delegate.onPasswordRequiredError(error: PasswordRequiredError(type: .generalError), state: self)
            case "invalid": delegate.onPasswordRequiredError(error: PasswordRequiredError(type: .invalidPassword), state: self)
            default: delegate.completed()
            }
    }
}
