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

@_implementationOnly import MSAL_Private

import Foundation

class MSALNativeAuthTokenController: MSALNativeAuthBaseController, MSALNativeAuthTokenRequestHandling {

    // MARK: - Variables

    let factory: MSALNativeAuthResultBuildable
    private let requestProvider: MSALNativeAuthTokenRequestProviding
    private let responseValidator: MSALNativeAuthTokenResponseValidating
    private let cacheAccessor: MSALNativeAuthCacheInterface
    private let tokenCacher: MSALNativeAuthTokenCacher

    init(
        clientId: String,
        requestProvider: MSALNativeAuthTokenRequestProviding,
        cacheAccessor: MSALNativeAuthCacheInterface,
        factory: MSALNativeAuthResultBuildable,
        responseValidator: MSALNativeAuthTokenResponseValidating
    ) {
        self.requestProvider = requestProvider
        self.factory = factory
        self.responseValidator = responseValidator
        self.cacheAccessor = cacheAccessor
        self.tokenCacher = MSALNativeAuthTokenCacher(cacheAccessor: cacheAccessor)
        super.init(
            clientId: clientId
        )
    }

    func performAndValidateTokenRequest(
        _ request: MSIDHttpRequest,
        context: MSALNativeAuthRequestContext) async -> MSALNativeAuthTokenValidatedResponse {
            let ciamTokenResponse: Result<MSALNativeAuthCIAMTokenResponse, Error> = await performTokenRequest(request, context: context)
            return responseValidator.validate(
                context: context,
                result: ciamTokenResponse
            )
        }

    func createTokenRequest(
        username: String? = nil,
        password: String? = nil,
        scopes: [String]? = nil,
        continuationToken: String? = nil,
        oobCode: String? = nil,
        grantType: MSALNativeAuthGrantType,
        includeChallengeType: Bool = true,
        claimsRequestJson: String? = nil,
        context: MSALNativeAuthRequestContext) -> MSIDHttpRequest? {
            do {
                let params = MSALNativeAuthTokenRequestParameters(
                    context: context,
                    username: username,
                    continuationToken: continuationToken,
                    grantType: grantType,
                    scope: scopes?.joinScopes(),
                    password: password,
                    oobCode: oobCode,
                    includeChallengeType: includeChallengeType,
                    refreshToken: nil,
                    claimsRequestJson: claimsRequestJson)
                return try requestProvider.signInWithPassword(parameters: params, context: context)
            } catch {
                MSALNativeAuthLogger.log(level: .error, context: context, format: "Error creating SignIn Token Request: \(error)")
                return nil
            }
        }

    func createRefreshTokenRequest(
        scopes: [String],
        refreshToken: String?,
        context: MSALNativeAuthRequestContext) -> MSIDHttpRequest? {
            guard let refreshToken = refreshToken else {
                MSALNativeAuthLogger.log(level: .error, context: context, format: "Error creating Refresh Token Request, refresh token is nil!")
                return nil
            }
            do {
                let params = MSALNativeAuthTokenRequestParameters(
                    context: context,
                    username: nil,
                    continuationToken: nil,
                    grantType: .refreshToken,
                    scope: scopes.joinScopes(),
                    password: nil,
                    oobCode: nil,
                    includeChallengeType: false,
                    refreshToken: refreshToken,
                    claimsRequestJson: nil)
                return try requestProvider.refreshToken(parameters: params, context: context)
            } catch {
                MSALNativeAuthLogger.log(level: .error, context: context, format: "Error creating Refresh Token Request: \(error)")
                return nil
            }
        }

    func cacheTokenResponse(
        _ tokenResponse: MSIDTokenResponse,
        context: MSIDRequestContext,
        msidConfiguration: MSIDConfiguration
    ) throws -> MSIDTokenResult {
        return try tokenCacher.cache(
            tokenResponse,
            context: context,
            msidConfiguration: msidConfiguration
        ) { [responseValidator] tokenResult, accountIdentifier in
            try responseValidator.validateAccount(with: tokenResult, context: context, accountIdentifier: accountIdentifier)
        }
    }
}
