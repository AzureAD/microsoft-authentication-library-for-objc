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

class MSALNativeAuthTokenController: MSALNativeAuthBaseController {

    // MARK: - Variables

    let factory: MSALNativeAuthResultBuildable
    private let requestProvider: MSALNativeAuthTokenRequestProviding
    private let responseValidator: MSALNativeAuthTokenResponseValidating
    private let cacheAccessor: MSALNativeAuthCacheInterface

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

    func joinScopes(_ scopes: [String]?) -> [String] {
        let defaultOIDCScopes = MSALPublicClientApplication.defaultOIDCScopes().array
        guard let scopes = scopes else {
            return defaultOIDCScopes as? [String] ?? []
        }
        let joinedScopes = NSMutableOrderedSet(array: scopes)
        joinedScopes.addObjects(from: defaultOIDCScopes)
        return joinedScopes.array as? [String] ?? []
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
        let displayableId = tokenResponse.idTokenObj?.username()
        let homeAccountId = tokenResponse.idTokenObj?.userId

        guard let accountIdentifier = MSIDAccountIdentifier(displayableId: displayableId, homeAccountId: homeAccountId) else {
            MSALNativeAuthLogger.log(level: .error, context: context, format: "Error creating account identifier")
            throw MSALNativeAuthInternalError.invalidResponse
        }

        guard let result = cacheTokenResponseRetrieveTokenResult(tokenResponse,
                                                                 context: context,
                                                                 msidConfiguration: msidConfiguration) else {
            MSALNativeAuthLogger.log(level: .error, context: context, format: "Error caching token response")
            throw MSALNativeAuthInternalError.invalidResponse
        }

        guard try responseValidator.validateAccount(with: result,
                                                    context: context,
                                                    accountIdentifier: accountIdentifier) else {
            MSALNativeAuthLogger.log(level: .error, context: context, format: "Error validating account")
            throw MSALNativeAuthInternalError.invalidResponse
        }

        return result
    }
}

// Extension is required because Swift compiler throws an error due to
// name similarity with another Objective C function when building for Release
extension MSALNativeAuthTokenController {

    private func cacheTokenResponseRetrieveTokenResult(
        _ tokenResponse: MSIDTokenResponse,
        context: MSIDRequestContext,
        msidConfiguration: MSIDConfiguration
    ) -> MSIDTokenResult? {
        do {
            // If there is an account existing already in the cache, we remove it
            try clearAccount(msidConfiguration: msidConfiguration, context: context)
        } catch {
            MSALNativeAuthLogger.logPII(level: .warning, context: context, format: "Error clearing account \(MSALLogMask.maskEUII(error)) (ignoring)")
        }
        do {
            let result = try cacheAccessor.validateAndSaveTokensAndAccount(tokenResponse: tokenResponse,
                                                                           configuration: msidConfiguration,
                                                                           context: context)
            return result
        } catch {
            MSALNativeAuthLogger.logPII(level: .warning,
                                        context: context,
                                        format: "Error caching response: \(MSALLogMask.maskEUII(error)) (ignoring)")
        }
        return nil
    }

    private func clearAccount(msidConfiguration: MSIDConfiguration, context: MSIDRequestContext) throws {
        do {
            let accounts = try cacheAccessor.getAllAccounts(configuration: msidConfiguration)
            if let account = accounts.first {
                if let identifier = MSIDAccountIdentifier(displayableId: account.username, homeAccountId: account.identifier) {
                    try cacheAccessor.clearCache(accountIdentifier: identifier,
                                                  authority: msidConfiguration.authority,
                                                  clientId: msidConfiguration.clientId,
                                                  context: context)
                }
            } else {
                MSALNativeAuthLogger.log(level: .warning,
                               context: context,
                               format: "Error creating MSIDAccountIdentifier out of MSALAccount (ignoring)")
            }
        } catch {
            MSALNativeAuthLogger.log(level: .warning, context: context, format: "Error clearing previous account (ignoring)")
        }
    }

    private func performTokenRequest(
        _ request: MSIDHttpRequest,
        context: MSIDRequestContext
    ) async -> Result<MSALNativeAuthCIAMTokenResponse, Error> {
        return await withCheckedContinuation { continuation in
            request.send { response, error in
                if let error = error {
                    continuation.resume(returning: .failure(error))
                    return
                }
                guard let responseDict = response as? [AnyHashable: Any] else {
                    continuation.resume(returning: .failure(MSALNativeAuthInternalError.invalidResponse))
                    return
                }
                do {
                    let tokenResponse = try MSALNativeAuthCIAMTokenResponse(jsonDictionary: responseDict)
                    // use request correlation id if server doesn't return one
                    tokenResponse.correlationId = tokenResponse.correlationId ?? request.context?.correlationId().uuidString
                    continuation.resume(returning: .success(tokenResponse))
                } catch {
                    MSALNativeAuthLogger.log(level: .error, context: context, format: "Error token request - Both result and error are nil")
                    continuation.resume(returning: .failure(MSALNativeAuthInternalError.invalidResponse))
                }
            }
        }
    }
}
