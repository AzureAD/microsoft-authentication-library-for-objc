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

extension ResetPasswordCodeRequiredState {

    func resendCodeInternal() async -> ResetPasswordResendCodeResult {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        return await controller.resendCode(passwordResetToken: flowToken, context: context)
    }

    func submitCodeInternal(code: String) async -> ResetPasswordVerifyCodeResult {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)

        guard inputValidator.isInputValid(code) else {
            MSALLogger.log(level: .error, context: context, format: "ResetPassword flow, invalid code")
            return .error(error: VerifyCodeError(type: .invalidCode), newState: self)
        }

        return await controller.submitCode(code: code, passwordResetToken: flowToken, context: context)
    }
}

extension ResetPasswordRequiredState {

    func submitPasswordInternal(password: String) async -> ResetPasswordRequiredResult {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)

        guard inputValidator.isInputValid(password) else {
            MSALLogger.log(level: .error, context: context, format: "ResetPassword flow, invalid password")
            return .error(error: PasswordRequiredError(type: .invalidPassword), newState: self)
        }

        return await controller.submitPassword(password: password, passwordSubmitToken: flowToken, context: context)
    }
}
