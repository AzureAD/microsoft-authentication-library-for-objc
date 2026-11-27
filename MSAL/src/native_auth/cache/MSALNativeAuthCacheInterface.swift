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
@_implementationOnly import MSAL_Private

protocol MSALNativeAuthCacheInterface {
    init(tokenCache: MSIDDefaultTokenCacheAccessor, accountMetadataCache: MSIDAccountMetadataCacheAccessor)

    func getIdToken(
        account: MSALAccount,
        configuration: MSIDConfiguration,
        context: MSIDRequestContext) throws -> String?

    func getAllAccounts(configuration: MSIDConfiguration) throws -> [MSALAccount]

    func validateAndSaveTokensAndAccount(
        tokenResponse: MSIDTokenResponse,
        configuration: MSIDConfiguration,
        context: MSIDRequestContext,
        claimsRequestJson: String?) throws -> MSIDTokenResult?

    func removeTokens(
        accountIdentifier: MSIDAccountIdentifier,
        authority: MSIDAuthority,
        clientId: String,
        context: MSIDRequestContext) throws

    func clearCache(
        accountIdentifier: MSIDAccountIdentifier,
        authority: MSIDAuthority,
        clientId: String,
        context: MSIDRequestContext) throws
}

extension MSALNativeAuthCacheInterface {

    func cache(
        _ tokenResponse: MSIDTokenResponse,
        context: MSIDRequestContext,
        msidConfiguration: MSIDConfiguration,
        claimsRequestJson: String?,
        validateAccount: (_ tokenResult: MSIDTokenResult, _ accountIdentifier: MSIDAccountIdentifier) throws -> Bool
    ) throws -> MSIDTokenResult {
        let validatedResult = try validateBeforeCaching(
            tokenResponse: tokenResponse,
            configuration: msidConfiguration,
            context: context,
            claimsRequestJson: claimsRequestJson
        )
        // The base validator can return a nil account despite MSIDTokenResult's nonnull annotation.
        let account: MSIDAccount? = validatedResult.account
        guard account?.accountIdentifier?.homeAccountId != nil else {
            MSALNativeAuthLogger.log(level: .error, context: context, format: "Missing home account identifier in token response")
            throw MSALNativeAuthInternalError.invalidResponse
        }

        let displayableId = tokenResponse.idTokenObj?.username()
        let homeAccountId = tokenResponse.idTokenObj?.userId

        guard let accountIdentifier = MSIDAccountIdentifier(displayableId: displayableId, homeAccountId: homeAccountId) else {
            MSALNativeAuthLogger.log(level: .error, context: context, format: "Error creating account identifier")
            throw MSALNativeAuthInternalError.invalidResponse
        }

        guard try validateAccount(validatedResult, accountIdentifier) else {
            throw MSALNativeAuthInternalError.invalidResponse
        }

        // Validate before replacing the existing account; rejected responses must not evict it.
        clearExistingAccount(msidConfiguration: msidConfiguration, context: context)

        let savedResult = try validateAndSaveTokensAndAccount(
            tokenResponse: tokenResponse,
            configuration: msidConfiguration,
            context: context,
            claimsRequestJson: claimsRequestJson
        )

        guard let result = savedResult else {
            MSALNativeAuthLogger.log(level: .error, context: context, format: "Error caching token response")
            throw MSALNativeAuthInternalError.invalidResponse
        }

        return result
    }

    private func validateBeforeCaching(
        tokenResponse: MSIDTokenResponse,
        configuration: MSIDConfiguration,
        context: MSIDRequestContext,
        claimsRequestJson: String?
    ) throws -> MSIDTokenResult {
        let parameters = try getRequestParameters(
            tokenResponse: tokenResponse,
            configuration: configuration,
            context: context,
            claimsRequestJson: claimsRequestJson
        )
        if tokenResponse.error == nil {
            // A non-string token must not become an absent token at the Objective-C boundary.
            guard tokenResponse.rawIdToken == nil || tokenResponse.rawIdToken is String else {
                throw MSALNativeAuthInternalError.invalidResponse
            }
            try parameters.validateAgeAssuranceIdToken(tokenResponse.rawIdToken as? String)
        }
        var validationError: NSError?
        guard let result = MSIDTokenResponseValidator().validate(
            tokenResponse,
            oauthFactory: MSIDCIAMOauth2Factory(),
            configuration: configuration,
            requestAccount: parameters.accountIdentifier,
            correlationID: context.correlationId(),
            error: &validationError
        ) else {
            throw (validationError as Error?) ?? MSALNativeAuthInternalError.invalidResponse
        }
        return result
    }

    func getRequestParameters(
        tokenResponse: MSIDTokenResponse,
        configuration: MSIDConfiguration,
        context: MSIDRequestContext,
        claimsRequestJson: String?
    ) throws -> MSIDRequestParameters {
        let parameters = MSIDRequestParameters()
        parameters.correlationId = context.correlationId()
        parameters.logComponent = context.logComponent()
        parameters.telemetryRequestId = context.telemetryRequestId()
        parameters.appRequestMetadata = context.appRequestMetadata()
        parameters.msidConfiguration = configuration
        parameters.clientId = configuration.clientId
        parameters.accountIdentifier = MSIDAccountIdentifier(
            displayableId: tokenResponse.idTokenObj?.username(),
            homeAccountId: tokenResponse.idTokenObj?.userId
        )
        parameters.authority = configuration.authority
        parameters.instanceAware = false
        parameters.oidcScope = (MSALPublicClientApplication.defaultOIDCScopes().array as? [String])?.joinScopes()
        if let json = claimsRequestJson {
            guard let dictionary = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any] else {
                throw MSALNativeAuthInternalError.invalidRequest
            }
            parameters.claimsRequest = try MSIDClaimsRequest(jsonDictionary: dictionary)
        }
        return parameters
    }

    private func clearExistingAccount(msidConfiguration: MSIDConfiguration, context: MSIDRequestContext) {
        do {
            let accounts = try getAllAccounts(configuration: msidConfiguration)
            if let account = accounts.first {
                if let identifier = MSIDAccountIdentifier(displayableId: account.username, homeAccountId: account.identifier) {
                    try clearCache(
                        accountIdentifier: identifier,
                        authority: msidConfiguration.authority,
                        clientId: msidConfiguration.clientId,
                        context: context)
                }
            } else {
                MSALNativeAuthLogger.log(
                    level: .warning,
                    context: context,
                    format: "Error creating MSIDAccountIdentifier out of MSALAccount (ignoring)")
            }
        } catch {
            MSALNativeAuthLogger.log(level: .warning, context: context, format: "Error clearing previous account (ignoring)")
        }
    }
}
