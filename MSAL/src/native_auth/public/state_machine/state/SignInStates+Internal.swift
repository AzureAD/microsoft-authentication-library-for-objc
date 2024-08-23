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

extension SignInCodeRequiredState {

    func submitCodeInternal(code: String) async -> MSALNativeAuthSignInControlling.SignInSubmitCodeControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        MSALLogger.log(level: .info, context: context, format: "SignIn flow, code submitted")
        guard inputValidator.isInputValid(code) else {
            MSALLogger.log(level: .error, context: context, format: "SignIn flow, invalid code")
            return .init(.error(error: VerifyCodeError(
                type: .invalidCode,
                correlationId: correlationId
            ), newState: self), correlationId: context.correlationId())
        }

        return await controller.submitCode(code, continuationToken: continuationToken, context: context, scopes: scopes)
    }

    func resendCodeInternal() async -> MSALNativeAuthSignInControlling.SignInResendCodeControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        MSALLogger.log(level: .info, context: context, format: "SignIn flow, resend code requested")

        return await controller.resendCode(continuationToken: continuationToken, context: context, scopes: scopes)
    }
}

extension SignInPasswordRequiredState {

    func submitPasswordInternal(password: String) async -> MSALNativeAuthSignInControlling.SignInSubmitPasswordControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        MSALLogger.log(level: .info, context: context, format: "SignIn flow, password submitted")

        guard inputValidator.isInputValid(password) else {
            MSALLogger.log(level: .error, context: context, format: "SignIn flow, invalid password")
            return .init(
                .error(error: PasswordRequiredError(type: .invalidPassword, correlationId: correlationId), newState: self),
                correlationId: context.correlationId()
            )
        }

        return await controller.submitPassword(password, username: username, continuationToken: continuationToken, context: context, scopes: scopes)
    }
}
