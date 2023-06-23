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
public class MSALNativeAuthUserAccountResult: NSObject {
    private let account: MSALAccount
    private let authTokens: MSALNativeAuthTokens
    private let configuration: MSALNativeAuthConfiguration
    private let cacheAccessor: MSALNativeAuthCacheInterface

    @objc public var username: String {
        account.username ?? ""
    }
    @objc public var idToken: String? {
        authTokens.rawIdToken
    }
    @objc public var scopes: [String] {
        authTokens.accessToken?.scopes.array as? [String] ?? []
    }
    @objc public var expiresOn: Date? {
        authTokens.accessToken?.expiresOn
    }
    @objc public var accountClaims: [String: Any] {
        account.accountClaims ?? [:]
    }

    init(
        account: MSALAccount,
        authTokens: MSALNativeAuthTokens,
        configuration: MSALNativeAuthConfiguration,
        cacheAccessor: MSALNativeAuthCacheInterface
    ) {
        self.account = account
        self.authTokens = authTokens
        self.configuration = configuration
        self.cacheAccessor = cacheAccessor
    }

    @objc public func signOut() {
        let context = MSALNativeAuthRequestContext()

        do {
            try cacheAccessor.clearCache(
                accountIdentifier: account.lookupAccountIdentifier,
                authority: configuration.authority,
                clientId: configuration.clientId,
                context: context
            )
        } catch {
            MSALLogger.log(
                level: .error,
                context: context,
                format: "Clearing MSAL token cache for the current account failed with error %@: \(error)"
            )
        }
    }

    @objc public func getAccessToken(delegate: CredentialsDelegate, forceRefresh: Bool = false, correlationId: UUID? = nil) {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        if let accessToken = self.authTokens.accessToken {
            if forceRefresh || accessToken.isExpired() {
                let controllerFactory = MSALNativeAuthControllerFactory(config: configuration)
                let credentialsController = controllerFactory.makeCredentialsController()
                Task {
                    await credentialsController.refreshToken(context: context, authTokens: authTokens, delegate: delegate)
                }
            } else {
                Task {
                    await delegate.onAccessTokenRetrieveCompleted(accessToken: accessToken.accessToken)
                }
            }
        } else {
            MSALLogger.log(level: .error, context: context, format: "Retrieve Access Token: Existing token not found")
            Task {
                await delegate.onAccessTokenRetrieveError(error: RetrieveAccessTokenError(type: .tokenNotFound))
            }
        }
    }
}
