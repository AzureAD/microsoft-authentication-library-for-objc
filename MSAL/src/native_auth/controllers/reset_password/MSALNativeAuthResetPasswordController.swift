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

@_implementationOnly import MSAL_Private

final class MSALNativeAuthResetPasswordController: MSALNativeAuthBaseController, MSALNativeAuthResetPasswordControlling {
    // 1. Called from Public Interface. Entry Point
    func resetPassword(
        username: String,
        context: MSIDRequestContext,
        delegate: ResetPasswordStartDelegate
    ) {
        DispatchQueue.main.async {
            switch username {
            case "redirect@contoso.com":
                delegate.onResetPasswordError(error: ResetPasswordStartError(type: .browserRequired))
            case "nopassword@contoso.com":
                delegate.onResetPasswordError(error: ResetPasswordStartError(type: .userDoesNotHavePassword))
            case "notfound@contoso.com":
                delegate.onResetPasswordError(error: ResetPasswordStartError(type: .userNotFound))
            case "generalerror@contoso.com":
                delegate.onResetPasswordError(error: ResetPasswordStartError(type: .generalError))
            default:
                delegate.onResetPasswordCodeRequired(newState: .init(controller: self, flowToken: "password_reset_token"),
                                                     sentTo: username,
                                                     channelTargetType: .email,
                                                     codeLength: 4)
            }
        }
    }

    // 2. Called from ResetPasswordCodeRequiredState
    func resendCode(context: MSIDRequestContext, delegate: ResetPasswordResendCodeDelegate) {
        DispatchQueue.main.async {
            delegate.onResetPasswordResendCodeRequired(newState: .init(controller: self, flowToken: "password_reset_token"),
                                                       sentTo: "email@contoso.com",
                                                       channelTargetType: .email,
                                                       codeLength: 4)
        }
    }

    // 3. Called from ResetPasswordCodeRequiredState
    func submitCode(code: String, context: MSIDRequestContext, delegate: ResetPasswordVerifyCodeDelegate) {
        DispatchQueue.main.async {
            switch code {
            case "0000":
                delegate.onResetPasswordVerifyCodeError(error: VerifyCodeError(type: .invalidCode),
                                                        newState: .init(controller: self, flowToken: "password_reset_token"))
            case "2222":
                delegate.onResetPasswordVerifyCodeError(error: VerifyCodeError(type: .generalError),
                                                        newState: .init(controller: self, flowToken: "password_reset_token"))
            case "3333":
                delegate.onResetPasswordVerifyCodeError(error: VerifyCodeError(type: .browserRequired),
                                                        newState: .init(controller: self, flowToken: "password_reset_token"))
            default:
                delegate.onPasswordRequired(newState: ResetPasswordRequiredState(controller: self, flowToken: "password_reset_token"))
            }
        }
    }

    // 4. Called from ResetPasswordRequiredState
    func submitPassword(password: String, context: MSIDRequestContext, delegate: ResetPasswordRequiredDelegate) {
        DispatchQueue.main.async {
            switch password {
            case "redirect":
                delegate.onResetPasswordRequiredError(error: PasswordRequiredError(type: .browserRequired),
                                                      newState: .init(controller: self, flowToken: "password_reset_token"))
            case "generalerror":
                delegate.onResetPasswordRequiredError(error: PasswordRequiredError(type: .generalError),
                                                      newState: .init(controller: self, flowToken: "password_reset_token"))
            case "invalid":
                delegate.onResetPasswordRequiredError(error: PasswordRequiredError(type: .invalidPassword),
                                                      newState: .init(controller: self, flowToken: "password_reset_token"))
            default:
                delegate.onResetPasswordCompleted()
            }
        }
    }
}
