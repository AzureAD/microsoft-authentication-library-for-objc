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

protocol MSALNativeAuthResultBuildable {

    var config: MSALNativeAuthConfiguration {get}

    func makeAccount(tokenResult: MSIDTokenResult, context: MSIDRequestContext) -> MSALAccount

    func makeAuthTokens(tokenResult: MSIDTokenResult, context: MSIDRequestContext) -> MSALNativeAuthTokens?

    func makeUserAccountResult(tokenResult: MSIDTokenResult, context: MSIDRequestContext) -> MSALNativeAuthUserAccountResult?

    func makeUserAccountResult(account: MSALAccount, authTokens: MSALNativeAuthTokens) -> MSALNativeAuthUserAccountResult?

    func makeMSIDConfiguration(scopes: [String]) -> MSIDConfiguration
}

final class MSALNativeAuthResultFactory: MSALNativeAuthResultBuildable {

    let config: MSALNativeAuthConfiguration
    let cacheAccessor: MSALNativeAuthCacheInterface
    private weak var application: MSALNativeAuthPublicClientApplication?

    init(config: MSALNativeAuthConfiguration, cacheAccessor: MSALNativeAuthCacheInterface, application: MSALNativeAuthPublicClientApplication?) {
        self.config = config
        self.cacheAccessor = cacheAccessor
        self.application = application
    }

    func makeAccount(tokenResult: MSIDTokenResult, context: MSIDRequestContext) -> MSALAccount {
        var jsonDictionary: [AnyHashable: Any]?
        do {
            let claims = try MSIDIdTokenClaims.init(rawIdToken: tokenResult.rawIdToken)
            jsonDictionary = claims.jsonDictionary()
            if jsonDictionary == nil {
                MSALLogger.log(
                    level: .warning,
                    context: context,
                    format: "Initialising account without claims")
            }
        } catch {
            MSALLogger.log(
                level: .warning,
                context: context,
                format: "Claims for account could not be created - \(error)" )
        }
        return MSALAccount.init(msidAccount: tokenResult.account,
                                createTenantProfile: false,
                                accountClaims: jsonDictionary)
    }

    func makeAuthTokens(tokenResult: MSIDTokenResult, context: MSIDRequestContext) -> MSALNativeAuthTokens? {
        guard let refreshToken = tokenResult.refreshToken as? MSIDRefreshToken else {
            MSALLogger.log(
                level: .error,
                context: context,
                format: "Refresh token invalid, account result could not be created")
            return nil
        }
        return MSALNativeAuthTokens(accessToken: tokenResult.accessToken,
                                              refreshToken: refreshToken,
                                              rawIdToken: tokenResult.rawIdToken)
    }

    func makeUserAccountResult(tokenResult: MSIDTokenResult, context: MSIDRequestContext) -> MSALNativeAuthUserAccountResult? {
        let account =  makeAccount(tokenResult: tokenResult, context: context)
        guard let authTokens = makeAuthTokens(tokenResult: tokenResult, context: context) else {
            MSALLogger.log(
                level: .error,
                context: context,
                format: "Auth Tokens could not be created")
            return nil
        }
        return .init(account: account, authTokens: authTokens, configuration: config, cacheAccessor: cacheAccessor, application: application)
    }

    func makeUserAccountResult(account: MSALAccount, authTokens: MSALNativeAuthTokens) -> MSALNativeAuthUserAccountResult? {
        return .init(account: account, authTokens: authTokens, configuration: config, cacheAccessor: cacheAccessor, application: application)
    }

    func makeMSIDConfiguration(scopes: [String]) -> MSIDConfiguration {
        return .init(
            authority: config.authority,
            redirectUri: nil,
            clientId: config.clientId,
            target: scopes.joinScopes()
        )
    }
}
