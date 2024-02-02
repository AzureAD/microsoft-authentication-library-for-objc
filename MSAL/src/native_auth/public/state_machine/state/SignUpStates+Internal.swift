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

extension SignUpCodeRequiredState {

    func resendCodeInternal() async -> MSALNativeAuthSignUpControlling.SignUpResendCodeControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        return await controller.resendCode(username: username, context: context, continuationToken: continuationToken)
    }

    func submitCodeInternal(code: String) async -> MSALNativeAuthSignUpControlling.SignUpSubmitCodeControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)

        guard inputValidator.isInputValid(code) else {
            MSALLogger.log(level: .error, context: context, format: "SignUp flow, invalid code")
            return .init(
                .error(error: VerifyCodeError(type: .invalidCode, correlationId: correlationId), newState: self),
                correlationId: correlationId
            )
        }

        return await controller.submitCode(code, username: username, continuationToken: continuationToken, context: context)
    }
}

extension SignUpPasswordRequiredState {

    func submitPasswordInternal(password: String) async -> MSALNativeAuthSignUpControlling.SignUpSubmitPasswordControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)

        guard inputValidator.isInputValid(password) else {
            MSALLogger.log(level: .error, context: context, format: "SignUp flow, invalid password")
            return .init(
                .error(error: PasswordRequiredError(type: .invalidPassword, correlationId: correlationId), newState: self),
                correlationId: correlationId
            )
        }

        return await controller.submitPassword(password, username: username, continuationToken: continuationToken, context: context)
    }
}

extension SignUpAttributesRequiredState {

    func submitAttributesInternal(attributes: [String: Any]) async -> MSALNativeAuthSignUpControlling.SignUpSubmitAttributesControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        return await controller.submitAttributes(attributes, username: username, continuationToken: continuationToken, context: context)
    }
}
