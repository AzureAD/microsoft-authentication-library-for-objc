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

extension MSALNativeAuthPublicClientApplication {

    func signUpInternal(
        username: String,
        password: String?,
        attributes: [String: Any]?,
        correlationId: UUID?
    ) async -> MSALNativeAuthSignUpControlling.SignUpStartControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        let correlationId = context.correlationId()

        guard inputValidator.isInputValid(username) else {
            return .init(.error(SignUpStartError(type: .invalidUsername, correlationId: correlationId)), correlationId: correlationId)
        }

        if let password = password, !inputValidator.isInputValid(password) {
            return .init(.error(SignUpStartError(type: .invalidPassword, correlationId: correlationId)), correlationId: correlationId)
        }

        let controller = controllerFactory.makeSignUpController(cacheAccessor: cacheAccessor)

        let parameters = MSALNativeAuthSignUpStartRequestProviderParameters(
            username: username,
            password: password,
            attributes: attributes,
            context: context
        )
        return await controller.signUpStart(parameters: parameters)
    }

    func signInInternal(
        username: String,
        password: String?,
        scopes: [String]?,
        correlationId: UUID?
    ) async -> MSALNativeAuthSignInControlling.SignInControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        let correlationId = context.correlationId()

        guard inputValidator.isInputValid(username) else {
            return .init(.error(SignInStartError(type: .invalidUsername, correlationId: correlationId)), correlationId: correlationId)
        }

        if let password = password, !inputValidator.isInputValid(password) {
            return .init(.error(SignInStartError(type: .invalidCredentials, correlationId: correlationId)), correlationId: correlationId)
        }

        let controller = controllerFactory.makeSignInController(cacheAccessor: cacheAccessor)

        let params = MSALNativeAuthSignInParameters(
            username: username,
            password: password,
            context: context,
            scopes: scopes
        )
        return await controller.signIn(params: params)
    }

    func resetPasswordInternal(
        username: String,
        correlationId: UUID?
    ) async -> MSALNativeAuthResetPasswordControlling.ResetPasswordStartControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        let correlationId = context.correlationId()
        
        guard inputValidator.isInputValid(username) else {
            return .init(.error(ResetPasswordStartError(type: .invalidUsername, correlationId: correlationId)), correlationId: correlationId)
        }

        let controller = controllerFactory.makeResetPasswordController(cacheAccessor: cacheAccessor)

        return await controller.resetPassword(
            parameters: .init(
                username: username,
                context: context
            )
        )
    }

    static func getInternalChallengeTypes(
        _ challengeTypes: MSALNativeAuthChallengeTypes
    ) -> [MSALNativeAuthInternalChallengeType] {
        var internalChallengeTypes = [MSALNativeAuthInternalChallengeType]()

        if challengeTypes.contains(.OOB) {
            internalChallengeTypes.append(.oob)
        }

        if challengeTypes.contains(.password) {
            internalChallengeTypes.append(.password)
        }

        internalChallengeTypes.append(.redirect)
        return internalChallengeTypes
    }
}
