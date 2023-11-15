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

    func signUpUsingPasswordInternal(
        username: String,
        password: String,
        attributes: [String: Any]?,
        correlationId: UUID?
    ) async -> MSALNativeAuthSignUpControlling.SignUpStartPasswordControllerResponse {
        guard inputValidator.isInputValid(username) else {
            return .init(.error(SignUpPasswordStartError(type: .invalidUsername)))
        }
        guard inputValidator.isInputValid(password) else {
            return .init(.error(SignUpPasswordStartError(type: .invalidPassword)))
        }

        let controller = controllerFactory.makeSignUpController()
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)

        let parameters = MSALNativeAuthSignUpStartRequestProviderParameters(
            username: username,
            password: password,
            attributes: attributes ?? [:],
            context: context
        )

        return await controller.signUpStartPassword(parameters: parameters)
    }

    func signUpInternal(
        username: String,
        attributes: [String: Any]?,
        correlationId: UUID?
    ) async -> MSALNativeAuthSignUpControlling.SignUpStartCodeControllerResponse {
        guard inputValidator.isInputValid(username) else {
            return .init(.error(SignUpStartError(type: .invalidUsername)))
        }

        let controller = controllerFactory.makeSignUpController()
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)

        let parameters = MSALNativeAuthSignUpStartRequestProviderParameters(
            username: username,
            password: nil,
            attributes: attributes ?? [:],
            context: context
        )

        return await controller.signUpStartCode(parameters: parameters)
    }

    func signInUsingPasswordInternal(
        username: String,
        password: String,
        scopes: [String]?,
        correlationId: UUID?
    ) async -> MSALNativeAuthSignInControlling.SignInPasswordControllerResponse {
        guard inputValidator.isInputValid(username) else {
            return .init(.error(SignInPasswordStartError(type: .invalidUsername)))
        }

        guard inputValidator.isInputValid(password) else {
            return .init(.error(SignInPasswordStartError(type: .invalidPassword)))
        }

        let controller = controllerFactory.makeSignInController()

        let params = MSALNativeAuthSignInWithPasswordParameters(
            username: username,
            password: password,
            context: MSALNativeAuthRequestContext(correlationId: correlationId),
            scopes: scopes
        )

        return await controller.signIn(params: params)
    }

    func signInInternal(
        username: String,
        scopes: [String]?,
        correlationId: UUID?
    ) async -> MSALNativeAuthSignInControlling.SignInCodeControllerResponse {
        guard inputValidator.isInputValid(username) else {
            return .init(.error(SignInStartError(type: .invalidUsername)))
        }
        let controller = controllerFactory.makeSignInController()
        let params = MSALNativeAuthSignInWithCodeParameters(
            username: username,
            context: MSALNativeAuthRequestContext(correlationId: correlationId),
            scopes: scopes
        )
        return await controller.signIn(params: params)
    }

    func resetPasswordInternal(username: String, correlationId: UUID?) async -> MSALNativeAuthResetPasswordControlling.ResetPasswordStartControllerResponse {
        guard inputValidator.isInputValid(username) else {
            return .init(.error(ResetPasswordStartError(type: .invalidUsername)))
        }

        let controller = controllerFactory.makeResetPasswordController()
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)

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
