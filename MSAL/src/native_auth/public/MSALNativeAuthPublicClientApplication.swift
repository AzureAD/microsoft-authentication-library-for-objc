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
public final class MSALNativeAuthPublicClientApplication: MSALPublicClientApplication {

    private let controllerFactory: MSALNativeAuthControllerBuildable
    // TODO: Remove kMockAccessToken when mock functionality is no longer required in SDK
    // swiftlint:disable:next line_length
    private let kMockAccessToken = "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsIng1dCI6Imk2bEdrM0ZaenhSY1ViMkMzbkVRN3N5SEpsWSIsImtpZCI6Imk2bEdrM0ZaenhSY1ViMkMzbkVRN3N5SEpsWSJ9"
    private let inputValidator: MSALNativeAuthInputValidating
    private let internalChallengeTypes: [MSALNativeAuthInternalChallengeType]

    public init(
        configuration config: MSALPublicClientApplicationConfig,
        challengeTypes: MSALNativeAuthChallengeTypes) throws {
        guard let aadAuthority = config.authority as? MSALAADAuthority else {
            throw MSALNativeAuthError.invalidAuthority
        }

        self.internalChallengeTypes =
            MSALNativeAuthPublicClientApplication.getInternalChallengeTypes(challengeTypes)

        let nativeConfiguration = try MSALNativeAuthConfiguration(
            clientId: config.clientId,
            authority: aadAuthority,
            challengeTypes: internalChallengeTypes
        )

        self.controllerFactory = MSALNativeAuthControllerFactory(config: nativeConfiguration)
        self.inputValidator = MSALNativeAuthInputValidator()

        try super.init(configuration: config)
    }

    public init(
        clientId: String,
        challengeTypes: MSALNativeAuthChallengeTypes,
        rawTenant: String? = nil,
        redirectUri: String? = nil) throws {
        let aadAuthority = try MSALNativeAuthAuthorityProvider()
            .authority(rawTenant: rawTenant)

        self.internalChallengeTypes =
                MSALNativeAuthPublicClientApplication.getInternalChallengeTypes(challengeTypes)
        let nativeConfiguration = try MSALNativeAuthConfiguration(
            clientId: clientId,
            authority: aadAuthority,
            rawTenant: rawTenant,
            challengeTypes: internalChallengeTypes
        )

        self.controllerFactory = MSALNativeAuthControllerFactory(config: nativeConfiguration)
        self.inputValidator = MSALNativeAuthInputValidator()

        let configuration = MSALPublicClientApplicationConfig(
            clientId: clientId,
            redirectUri: redirectUri,
            authority: aadAuthority
        )

        try super.init(configuration: configuration)
    }

    init(
        controllerFactory: MSALNativeAuthControllerBuildable,
        inputValidator: MSALNativeAuthInputValidating,
        internalChallengeTypes: [MSALNativeAuthInternalChallengeType]
    ) {
        self.controllerFactory = controllerFactory
        self.inputValidator = inputValidator
        self.internalChallengeTypes = internalChallengeTypes

        super.init()
    }

    // MARK: delegate methods

    public func signUpUsingPassword(
        username: String,
        password: String,
        attributes: [String: Any]? = nil,
        correlationId: UUID? = nil,
        delegate: SignUpPasswordStartDelegate
    ) {
        guard inputValidator.isInputValid(username) else {
            DispatchQueue.main.async {
                delegate.onSignUpPasswordError(error: SignUpPasswordStartError(type: .invalidUsername))
            }
            return
        }
        guard inputValidator.isInputValid(password) else {
            DispatchQueue.main.async {
                delegate.onSignUpPasswordError(error: SignUpPasswordStartError(type: .invalidPassword))
            }
            return
        }

        let controller = controllerFactory.makeSignUpController()
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)

        Task {
            await controller.signUpStartPassword(
                parameters: .init(
                    username: username,
                    password: password,
                    attributes: attributes ?? [:],
                    context: context
                ),
                delegate: delegate
            )
        }
    }

    public func signUpUsingCode(
        username: String,
        attributes: [String: Any]? = nil,
        correlationId: UUID? = nil,
        delegate: SignUpCodeStartDelegate
    ) {
        guard inputValidator.isInputValid(username) else {
            DispatchQueue.main.async {
                delegate.onSignUpCodeError(error: SignUpCodeStartError(type: .invalidUsername))
            }
            return
        }

        let controller = controllerFactory.makeSignUpController()
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)

        Task {
            await controller.signUpStartCode(
                parameters: .init(
                    username: username,
                    password: nil,
                    attributes: attributes ?? [:],
                    context: context
                ),
                delegate: delegate
            )
        }
    }

    public func signInUsingPassword(
        username: String,
        password: String,
        scopes: [String]? = nil,
        correlationId: UUID? = nil,
        delegate: SignInPasswordStartDelegate
    ) {
        guard inputValidator.isInputValid(username) else {
            DispatchQueue.main.async {
                delegate.onSignInPasswordError(error: SignInPasswordStartError(type: .invalidUsername))
            }
            return
        }
        guard inputValidator.isInputValid(password) else {
            DispatchQueue.main.async {
                delegate.onSignInPasswordError(error: SignInPasswordStartError(type: .invalidPassword))
            }
            return
        }
        let controller = controllerFactory.makeSignInController()
        let params = MSALNativeAuthSignInWithPasswordParameters(
            username: username,
            password: password,
            correlationId: correlationId,
            scopes: scopes)
        controller.signIn(params: params, delegate: delegate)
    }

    public func signInUsingCode(
        username: String,
        scopes: [String]? = nil,
        correlationId: UUID? = nil,
        delegate: SignInCodeStartDelegate
    ) {
        guard inputValidator.isInputValid(username) else {
            DispatchQueue.main.async {
                delegate.onSignInCodeError(error: SignInCodeStartError(type: .invalidUsername))
            }
            return
        }
        let controller = controllerFactory.makeSignInController()
        let params = MSALNativeAuthSignInWithCodeParameters(
            username: username,
            correlationId: correlationId,
            scopes: scopes)
        controller.signIn(params: params, delegate: delegate)
    }

    public func resetPassword(
        username: String,
        correlationId: UUID? = nil,
        delegate: ResetPasswordStartDelegate
    ) {
        guard inputValidator.isInputValid(username) else {
            DispatchQueue.main.async {
                delegate.onResetPasswordError(error: ResetPasswordStartError(type: .invalidUsername))
            }
            return
        }

        let controller = controllerFactory.makeResetPasswordController()
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)

        controller.resetPassword(username: username, context: context, delegate: delegate)
    }

    public func getUserAccount() async throws -> MSALNativeAuthUserAccount? {
        return MSALNativeAuthUserAccount(
            username: "email@contoso.com",
            accessToken: kMockAccessToken,
            rawIdToken: nil,
            scopes: [],
            expiresOn: Date()
        )
    }

    private static func getInternalChallengeTypes(
        _ challengeTypes: MSALNativeAuthChallengeTypes) -> [MSALNativeAuthInternalChallengeType] {
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
