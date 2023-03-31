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
public enum ChallengeType: Int {
    case oob
    case password
}

@objcMembers
public final class MSALNativeAuthPublicClientApplication: MSALPublicClientApplication {

    private let controllerFactory: MSALNativeAuthRequestControllerBuildable
    private let inputValidator: MSALNativeAuthInputValidating

    public override init(configuration config: MSALPublicClientApplicationConfig) throws {
        guard let aadAuthority = config.authority as? MSALAADAuthority else {
            throw MSALNativeAuthError.invalidAuthority
        }

        let nativeConfiguration = try MSALNativeAuthConfiguration(
            clientId: config.clientId,
            authority: aadAuthority
        )

        self.controllerFactory = MSALNativeAuthRequestControllerFactory(config: nativeConfiguration)
        self.inputValidator = MSALNativeAuthInputValidator()

        try super.init(configuration: config)
    }

    public init(clientId: String, challengeTypes: [ChallengeType], rawTenant: String? = nil, redirectUri: String? = nil) throws {
        let aadAuthority = try MSALNativeAuthAuthorityProvider()
            .authority(rawTenant: rawTenant)

        let nativeConfiguration = try MSALNativeAuthConfiguration(
            clientId: clientId,
            authority: aadAuthority,
            rawTenant: rawTenant
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

    // MARK: new methods

    public func signUp(email: String, password: String?, attributes: [String: Any], correlationId: UUID? = nil, callback: SignUpStartDelegate) {
        callback.onError(error: SignUpError(type: SignUpErrorType.invalidAttributes))
    }

    public func signIn(email: String, password: String?, correlationId: UUID? = nil, callback: SignInStartDelegate) {
        callback.onError(error: SignInStartError(type: SignInStartErrorType.passwordInvalid))
    }

    public func resetPassword(email: String, correlationId: UUID? = nil, callback: ResetPasswordStartDelegate) {

    }

    //TODO: complete this method
    public func getUserAccount(completion: @escaping (MSALNativeAuthUserAccount, Error) -> Void) {

    }
}
