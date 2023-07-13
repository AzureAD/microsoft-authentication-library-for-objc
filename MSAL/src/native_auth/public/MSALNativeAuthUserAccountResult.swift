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

/// Represents information returned to the application after a sign in operation.
@objc public class MSALNativeAuthUserAccountResult: NSObject {
    private let account: MSALAccount
    private let authTokens: MSALNativeAuthTokens
    private let configuration: MSALNativeAuthConfiguration
    private let cacheAccessor: MSALNativeAuthCacheInterface

    /// Get the username for the account.
    @objc public var username: String {
        account.username ?? ""
    }

    /// Get the ID token for the account.
    @objc public var idToken: String? {
        authTokens.rawIdToken
    }

    /// Get the list of permissions for the access token for the account if present, otherwise returns an empty array.
    @objc public var scopes: [String] {
        authTokens.accessToken?.scopes.array as? [String] ?? []
    }

    /// Get the expiration date for the access token for the account if present, otherwise returns nil.
    @objc public var expiresOn: Date? {
        authTokens.accessToken?.expiresOn
    }

    /// Get the claims for the account if present, otheriwse returns an empty dictionary.
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

    /// Removes the current account from the cache.
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

    /// Retrieves an access token for the account.
    /// - Parameters:
    ///   - delegate: Delegate that receives callbacks for the Get Access Token flow.
    ///   - forceRefresh: Ignore any existing access token in the cache and force MSAL to get a new access token from the service.
    ///   - correlationId: UUID to correlate this request with the server for debugging.
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
