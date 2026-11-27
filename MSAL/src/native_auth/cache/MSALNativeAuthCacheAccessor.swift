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

import Foundation
@_implementationOnly import MSAL_Private

final class MSALNativeAuthCacheAccessor: MSALNativeAuthCacheInterface {
    private let tokenCacheAccessor: MSIDDefaultTokenCacheAccessor

    private let accountMetadataCache: MSIDAccountMetadataCacheAccessor

    private let externalAccountProvider: MSALExternalAccountHandler = MSALExternalAccountHandler()
    private let validator = MSIDTokenResponseValidator()

    init(tokenCache: MSIDDefaultTokenCacheAccessor, accountMetadataCache: MSIDAccountMetadataCacheAccessor) {
        self.tokenCacheAccessor = tokenCache
        self.accountMetadataCache = accountMetadataCache
    }

    func getIdToken(
        account: MSALAccount,
        configuration: MSIDConfiguration,
        context: MSIDRequestContext) throws -> String? {
            let accountConfiguration = try getAccountConfiguration(configuration: configuration, account: account)
            let idToken = try tokenCacheAccessor.getIDToken(
                forAccount: account.lookupAccountIdentifier,
                configuration: accountConfiguration,
                idTokenType: MSIDCredentialType.MSIDIDTokenType,
                context: context)
            return idToken.rawIdToken
        }

    func getAllAccounts(configuration: MSIDConfiguration) throws -> [MSALAccount] {
        let request = MSALAccountsProvider(tokenCache: tokenCacheAccessor,
                                           accountMetadataCache: accountMetadataCache,
                                           clientId: configuration.clientId,
                                           externalAccountProvider: externalAccountProvider)
        return try request?.allAccounts() ?? []
    }

    func validateAndSaveTokensAndAccount(
        tokenResponse: MSIDTokenResponse,
        configuration: MSIDConfiguration,
        context: MSIDRequestContext,
        claimsRequestJson: String?) throws -> MSIDTokenResult? {
            let ciamOauth2Provider = getCIAMOauth2Provider(clientId: configuration.clientId)
            return try validator.validateAndSave(tokenResponse,
                                                  oauthFactory: ciamOauth2Provider.msidOauth2Factory,
                                                  tokenCache: tokenCacheAccessor,
                                                  accountMetadataCache: accountMetadataCache,
                                                  requestParameters: getRequestParameters(tokenResponse: tokenResponse,
                                                                                          configuration: configuration,
                                                                                          context: context,
                                                                                          claimsRequestJson: claimsRequestJson),
                                                  saveSSOStateOnly: false)
        }

    func removeTokens(
        accountIdentifier: MSIDAccountIdentifier,
        authority: MSIDAuthority,
        clientId: String,
        context: MSIDRequestContext) throws {
            try tokenCacheAccessor.clearCache(
                forAccount: accountIdentifier,
                authority: authority,
                clientId: clientId,
                familyId: nil,
                clearAccounts: false,
                context: context)
        }

    func clearCache(
        accountIdentifier: MSIDAccountIdentifier,
        authority: MSIDAuthority,
        clientId: String,
        context: MSIDRequestContext) throws {
            try tokenCacheAccessor.clearCache(
                forAccount: accountIdentifier,
                authority: authority,
                clientId: clientId,
                familyId: nil,
                clearAccounts: true,
                context: context)
        }

    private func getCIAMOauth2Provider(clientId: String) -> MSALCIAMOauth2Provider {
        return MSALCIAMOauth2Provider(clientId: clientId,
                               tokenCache: tokenCacheAccessor,
                               accountMetadataCache: accountMetadataCache)

    }

    private func getAccountConfiguration(configuration: MSIDConfiguration,
                                         account: MSALAccount) throws -> MSIDConfiguration? {
        // When retrieving tokens from the cache, we first have to get the
        // Tenant Id from the AccountMetadataCache. Because in NativeAuth
        // We use only CIAM authorities, we retrieve using its provider
        let ciamOauth2Provider = getCIAMOauth2Provider(clientId: configuration.clientId)
        let accountConfiguration = configuration.copy() as? MSIDConfiguration
        let errorPointer: NSErrorPointer = nil
        let requestAuthority = ciamOauth2Provider.issuerAuthority(with: account,
                                                                      request: configuration.authority,
                                                                      instanceAware: false,
                                                                      error: errorPointer)
        if let errorPointer = errorPointer, let error = errorPointer.pointee {
            throw error
        }
        accountConfiguration?.authority = requestAuthority
        return accountConfiguration
    }
}
