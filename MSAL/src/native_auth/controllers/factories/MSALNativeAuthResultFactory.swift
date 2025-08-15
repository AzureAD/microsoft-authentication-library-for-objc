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

    var config: MSALNativeAuthInternalConfiguration {get}

    func makeAccount(tokenResult: MSIDTokenResult, context: MSIDRequestContext) -> MSALAccount

    func makeUserAccountResult(tokenResult: MSIDTokenResult, context: MSIDRequestContext) -> MSALNativeAuthUserAccountResult?

    func makeUserAccountResult(account: MSALAccount, rawIdToken: String?) -> MSALNativeAuthUserAccountResult?

    func makeMSIDConfiguration(scopes: [String]) -> MSIDConfiguration
}

final class MSALNativeAuthResultFactory: MSALNativeAuthResultBuildable {

    let config: MSALNativeAuthInternalConfiguration
    let cacheAccessor: MSALNativeAuthCacheInterface

    init(config: MSALNativeAuthInternalConfiguration, cacheAccessor: MSALNativeAuthCacheInterface) {
        self.config = config
        self.cacheAccessor = cacheAccessor
    }

    func makeAccount(tokenResult: MSIDTokenResult, context: MSIDRequestContext) -> MSALAccount {
        var jsonDictionary: [AnyHashable: Any]?
        do {
            let claims = try MSIDIdTokenClaims.init(rawIdToken: tokenResult.rawIdToken)
            jsonDictionary = claims.jsonDictionary()
            if jsonDictionary == nil {
                MSALNativeAuthLogger.log(
                    level: .warning,
                    context: context,
                    format: "Initialising account without claims")
            }
        } catch {
            MSALNativeAuthLogger.logPII(
                level: .warning,
                context: context,
                format: "Claims for account could not be created - \(MSALLogMask.maskEUII(error))" )
        }
        return MSALAccount.init(msidAccount: tokenResult.account,
                                createTenantProfile: false,
                                accountClaims: jsonDictionary)
    }

    func makeUserAccountResult(tokenResult: MSIDTokenResult, context: MSIDRequestContext) -> MSALNativeAuthUserAccountResult? {
        let account =  makeAccount(tokenResult: tokenResult, context: context)
        return .init(account: account, rawIdToken: tokenResult.rawIdToken, configuration: config, cacheAccessor: cacheAccessor)
    }

    func makeUserAccountResult(account: MSALAccount, rawIdToken: String?) -> MSALNativeAuthUserAccountResult? {
        return .init(account: account, rawIdToken: rawIdToken, configuration: config, cacheAccessor: cacheAccessor)
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
