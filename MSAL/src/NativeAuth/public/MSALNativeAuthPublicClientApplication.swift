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
public enum MSALNativeAuthChallengeType: Int {
    case oob
    case password
}

@objcMembers
public final class MSALNativeAuthPublicClientApplication: MSALPublicClientApplication {

    private let controllerFactory: MSALNativeAuthRequestControllerBuildable
    private let inputValidator: MSALNativeAuthInputValidating

    public init(
        configuration config: MSALPublicClientApplicationConfig,
        challengeTypes: [MSALNativeAuthChallengeType]) throws {
        guard let aadAuthority = config.authority as? MSALAADAuthority else {
            throw MSALNativeAuthError.invalidAuthority
        }

        let nativeConfiguration = try MSALNativeAuthConfiguration(
            clientId: config.clientId,
            authority: aadAuthority,
            challengeTypes: MSALNativeAuthPublicClientApplication.getInternalChallengeTypes(challengeTypes)
        )

        self.controllerFactory = MSALNativeAuthRequestControllerFactory(config: nativeConfiguration)
        self.inputValidator = MSALNativeAuthInputValidator()

        try super.init(configuration: config)
    }

    public init(
        clientId: String,
        challengeTypes: [MSALNativeAuthChallengeType],
        rawTenant: String? = nil,
        redirectUri: String? = nil) throws {
        let aadAuthority = try MSALNativeAuthAuthorityProvider()
            .authority(rawTenant: rawTenant)

        let nativeConfiguration = try MSALNativeAuthConfiguration(
            clientId: clientId,
            authority: aadAuthority,
            rawTenant: rawTenant,
            challengeTypes: MSALNativeAuthPublicClientApplication.getInternalChallengeTypes(challengeTypes)
        )

        self.controllerFactory = MSALNativeAuthRequestControllerFactory(config: nativeConfiguration)
        self.inputValidator = MSALNativeAuthInputValidator()

        let configuration = MSALPublicClientApplicationConfig(
            clientId: clientId,
            redirectUri: redirectUri,
            authority: aadAuthority
        )

        try super.init(configuration: configuration)
    }

    init(
        controllerFactory: MSALNativeAuthRequestControllerBuildable,
        inputValidator: MSALNativeAuthInputValidating
    ) {
        self.controllerFactory = controllerFactory
        self.inputValidator = inputValidator

        super.init()
    }

    // MARK: delegate methods

    public func signUp(
        username: String,
        password: String?,
        attributes: [String: Any]? = nil,
        correlationId: UUID? = nil,
        delegate: SignUpStartDelegate
    ) {
        guard inputValidator.isInputValid(username) else {
            delegate.onSignUpError(error: SignUpStartError(type: .invalidUsername))
            return
        }
        if let password = password, !inputValidator.isInputValid(password) {
            delegate.onSignUpError(error: SignUpStartError(type: .passwordInvalid))
            return
        }
        switch username {
        case "exists@contoso.com": delegate.onSignUpError(error: SignUpStartError(type: .userAlreadyExists))
        case "redirect@contoso.com": delegate.onSignUpError(error: SignUpStartError(type: .redirect))
        case "invalidpassword@contoso.com": delegate.onSignUpError(error: SignUpStartError(type: .passwordInvalid))
        case "invalidemail@contoso.com": delegate.onSignUpError(error: SignUpStartError(type:
                .invalidUsername, message: "email \(username) is invalid"))
        case "invalidattributes@contoso.com": delegate.onSignUpError(error: SignUpStartError(type: .invalidAttributes))
        case "generalerror@contoso.com": delegate.onSignUpError(error: SignUpStartError(type: .generalError))
        default: delegate.onCodeSent(
            state: SignUpCodeSentState(flowToken: "signup_token"),
            displayName: username,
            codeLength: 4)
        }
    }

    public func signIn(
        username: String,
        password: String?,
        correlationId: UUID? = nil,
        delegate: SignInStartDelegate
    ) {
        guard inputValidator.isInputValid(username) else {
            delegate.onSignInError(error: SignInStartError(type: .invalidUsername))
            return
        }
        if let password = password, !inputValidator.isInputValid(password) {
            delegate.onSignInError(error: SignInStartError(type: .passwordInvalid))
            return
        }
        switch username {
        case "notfound@contoso.com": delegate.onSignInError(error: SignInStartError(type: .userNotFound))
        case "redirect@contoso.com": delegate.onSignInError(error: SignInStartError(type: .redirect))
        case "invalidauth@contoso.com": delegate.onSignInError(error: SignInStartError(type: .invalidAuthenticationType))
        case "invalidpassword@contoso.com": delegate.onSignInError(error: SignInStartError(type: .passwordInvalid))
        case "generalerror@contoso.com": delegate.onSignInError(error: SignInStartError(type: .generalError))
        case "oob@contoso.com": delegate.onCodeSent(
            state: SignInCodeSentState(flowToken: "credential_token"),
            displayName: username,
            codeLength: 4)
        default: delegate.completed(
                result:
                    MSALNativeAuthUserAccount(
                        username: username,
                        accessToken: "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsIng1dCI6Imk2bEdrM0ZaenhSY1ViMkMzbkVRN3N5SEpsWSIsImtpZCI6Imk2bEdrM0ZaenhSY1ViMkMzbkVRN3N5SEpsWSJ9"))
        }
    }

    public func resetPassword(
        username: String,
        correlationId: UUID? = nil,
        delegate: ResetPasswordStartDelegate
    ) {
        guard inputValidator.isInputValid(username) else {
            delegate.onResetPasswordError(error: ResetPasswordStartError(type: .invalidUsername))
            return
        }
        switch username {
        case "redirect@contoso.com": delegate.onResetPasswordError(error: ResetPasswordStartError(type: .redirect))
        case "nopassword@contoso.com": delegate.onResetPasswordError(error: ResetPasswordStartError(type: .userDoesNotHavePassword))
        case "notfound@contoso.com": delegate.onResetPasswordError(error: ResetPasswordStartError(type: .userNotFound))
        case "generalerror@contoso.com": delegate.onResetPasswordError(error: ResetPasswordStartError(type: .generalError))
        default: delegate.onCodeSent(state:
                                        CodeSentResetPasswordState(flowToken: "password_reset_token"), displayName: username, codeLength: 4)
        }
    }

    public func getUserAccount() async throws -> MSALNativeAuthUserAccount {
        return MSALNativeAuthUserAccount(
            username: "email@contoso.com",
            accessToken: "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsIng1dCI6Imk2bEdrM0ZaenhSY1ViMkMzbkVRN3N5SEpsWSIsImtpZCI6Imk2bEdrM0ZaenhSY1ViMkMzbkVRN3N5SEpsWSJ9"
        )
    }

    private static func getInternalChallengeTypes(
        _ challengeTypes: [MSALNativeAuthChallengeType]) -> [MSALNativeAuthInternalChallengeType] {
            var internalChallengeTypes = challengeTypes.map({
                MSALNativeAuthInternalChallengeType.getChallengeType(type: $0)
            })
            internalChallengeTypes.append(.redirect)
            return internalChallengeTypes
    }
}
