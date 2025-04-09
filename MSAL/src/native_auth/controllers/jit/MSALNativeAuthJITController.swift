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

final class MSALNativeAuthJITController:
    MSALNativeAuthTokenController,
    MSALNativeAuthJITControlling {

    // MARK: - Variables

    private let jitRequestProvider: MSALNativeAuthJITRequestProviding
    private let jitResponseValidator: MSALNativeAuthJITResponseValidating
    private let signInController: MSALNativeAuthSignInControlling

    // MARK: - Init

    init(
        clientId: String,
        jitRequestProvider: MSALNativeAuthJITRequestProviding,
        tokenRequestProvider: MSALNativeAuthTokenRequestProviding,
        cacheAccessor: MSALNativeAuthCacheInterface,
        factory: MSALNativeAuthResultBuildable,
        jitResponseValidator: MSALNativeAuthJITResponseValidating,
        tokenResponseValidator: MSALNativeAuthTokenResponseValidating,
        signInController: MSALNativeAuthSignInControlling
    ) {
        self.jitRequestProvider = jitRequestProvider
        self.jitResponseValidator = jitResponseValidator
        self.signInController = signInController
        super.init(
            clientId: clientId,
            requestProvider: tokenRequestProvider,
            cacheAccessor: cacheAccessor,
            factory: factory,
            responseValidator: tokenResponseValidator
        )
    }

    convenience init(config: MSALNativeAuthConfiguration, cacheAccessor: MSALNativeAuthCacheInterface) {
        let factory = MSALNativeAuthResultFactory(config: config, cacheAccessor: cacheAccessor)
        self.init(
            clientId: config.clientId,
            jitRequestProvider: MSALNativeAuthJITRequestProvider(
                requestConfigurator: MSALNativeAuthRequestConfigurator(config: config)),
            tokenRequestProvider: MSALNativeAuthTokenRequestProvider(
                requestConfigurator: MSALNativeAuthRequestConfigurator(config: config)),
            cacheAccessor: cacheAccessor,
            factory: factory,
            jitResponseValidator: MSALNativeAuthJITResponseValidator(),
            tokenResponseValidator: MSALNativeAuthTokenResponseValidator(
                factory: factory,
                msidValidator: MSIDTokenResponseValidator()),
            signInController: MSALNativeAuthSignInController(config: config, cacheAccessor: cacheAccessor)
        )
    }
    func getJITAuthMethods(
        continuationToken: String,
        context: MSALNativeAuthRequestContext,
        scopes: [String],
        claimsRequestJson: String?
    ) {

    }

    func requestJITChallenge(
        continuationToken: String,
        authMethod: MSALAuthMethod,
        scopes: [String],
        claimsRequestJson: String?
    ) async -> JITRequestChallengeControllerResponse {
        return .init(.error(error: RegisterStrongAuthChallengeError(type: .generalError, correlationId: UUID()), newState: nil), correlationId: UUID())
    }

    func submitJITChallenge(
        challenge: String,
        continuationToken: String,
        context: MSALNativeAuthRequestContext,
        scopes: [String],
        claimsRequestJson: String?
    ) async -> JITSubmitChallengeControllerResponse {
        return .init(.error(error: RegisterStrongAuthSubmitChallengeError(type: .generalError, correlationId: UUID()), newState: nil), correlationId: UUID())
    }
}
