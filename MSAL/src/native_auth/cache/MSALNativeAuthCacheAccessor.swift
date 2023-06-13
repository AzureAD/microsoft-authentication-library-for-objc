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

class MSALNativeAuthCacheAccessor: MSALNativeAuthCacheInterface {

    private let tokenCacheAccessor: MSIDDefaultTokenCacheAccessor = {
        let dataSource = MSIDKeychainTokenCache()
        return MSIDDefaultTokenCacheAccessor(dataSource: dataSource, otherCacheAccessors: [])
    }()

    func getTokens(
        accountIdentifier: MSIDAccountIdentifier,
        configuration: MSIDConfiguration,
        context: MSIDRequestContext) throws -> MSALNativeAuthTokens {
        let idToken = try tokenCacheAccessor.getIDToken(
            forAccount: accountIdentifier,
            configuration: configuration,
            idTokenType: MSIDCredentialType.MSIDIDTokenType,
            context: context)
        let refreshToken = try tokenCacheAccessor.getRefreshToken(
            withAccount: accountIdentifier,
            familyId: nil,
            configuration: configuration,
            context: context)
        let accessToken = try tokenCacheAccessor.getAccessToken(
            forAccount: accountIdentifier,
            configuration: configuration,
            context: context)
        return MSALNativeAuthTokens(idToken: idToken, accessToken: accessToken, refreshToken: refreshToken)
    }

    func getAccount(
        accountIdentifier: MSIDAccountIdentifier,
        authority: MSIDAuthority,
        context: MSIDRequestContext) throws -> MSIDAccount? {
        return try tokenCacheAccessor.getAccountFor(
            accountIdentifier,
            authority: authority,
            realmHint: nil,
            context: context)
    }

    func saveTokensAndAccount(
        tokenResult: MSIDTokenResponse,
        configuration: MSIDConfiguration,
        context: MSIDRequestContext) throws {
        try tokenCacheAccessor.saveTokens(
            with: configuration,
            response: tokenResult,
            factory: MSIDCIAMOauth2Factory(),
            context: context)
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
}
