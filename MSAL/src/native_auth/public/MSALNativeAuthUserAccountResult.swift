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

/// Class that groups account and token information.
@objc public class MSALNativeAuthUserAccountResult: NSObject {
    /// The account object that holds account information.
    @objc public var account: MSALAccount

    let configuration: MSALNativeAuthConfiguration
    internal var rawIdToken: String?
    private let cacheAccessor: MSALNativeAuthCacheInterface
    private let inputValidator: MSALNativeAuthInputValidating

    /// Get the latest ID token for the account.
    @objc public var idToken: String? {
        rawIdToken
    }

    init(
        account: MSALAccount,
        rawIdToken: String?,
        configuration: MSALNativeAuthConfiguration,
        cacheAccessor: MSALNativeAuthCacheInterface,
        inputValidator: MSALNativeAuthInputValidating = MSALNativeAuthInputValidator()
    ) {
        self.account = account
        self.rawIdToken = rawIdToken
        self.configuration = configuration
        self.cacheAccessor = cacheAccessor
        self.inputValidator = inputValidator
    }

    /// Removes all the data from the cache.
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
            MSALLogger.logPII(
                level: .error,
                context: context,
                format: "Clearing MSAL token cache for the current account failed with error %@: \(MSALLogMaskWrapper.maskEUII(error))"
            )
        }
    }

    /// Retrieves the access token for the default OIDC(openid, offline_access, profile) scopes from the cache.
    /// - Parameters:
    ///   - forceRefresh: Optional. Ignore any existing access token in the cache and force MSAL to get a new access token from the service.
    ///   - correlationId: Optional. UUID to correlate this request with the server for debugging.
    ///   - delegate: Delegate that receives callbacks for the Get Access Token flow.
    @objc public func getAccessToken(forceRefresh: Bool = false,
                                     correlationId: UUID? = nil,
                                     delegate: CredentialsDelegate) {
        MSALLogger.log(
            level: .info,
            context: nil,
            format: "Retrieving access token without scopes.")

        getAccessTokenInternal(forceRefresh: forceRefresh,
                               scopes: [],
                               correlationId: correlationId,
                               delegate: delegate)
    }

    /// Retrieves the access token for the currently signed in account from the cache such that
    /// the scope of retrieved access token is a superset of requested scopes. If the access token
    /// has expired, it will be refreshed using the refresh token that's stored in the cache. If no
    /// access token matching the requested scopes is found in cache then a new access token is fetched.
    /// - Parameters:
    ///   - scopes: Permissions you want included in the access token received in the result. Not all scopes are guaranteed to be included in the access token returned.
    ///   - forceRefresh: Optional. Ignore any existing access token in the cache and force MSAL to get a new access token from the service.
    ///   - correlationId: Optional. UUID to correlate this request with the server for debugging.
    ///   - delegate: Delegate that receives callbacks for the Get Access Token flow.
    public func getAccessToken(scopes: [String],
                               forceRefresh: Bool = false,
                               correlationId: UUID? = nil,
                               delegate: CredentialsDelegate) {

        guard inputValidator.isInputValid(scopes) else {
            Task { await delegate.onAccessTokenRetrieveError(error: RetrieveAccessTokenError(type: .invalidScope,
                                                                                             correlationId: correlationId ?? UUID())) }
            return
        }

        MSALLogger.log(
            level: .info,
            context: nil,
            format: "Retrieving access token with scopes started."
        )

        getAccessTokenInternal(forceRefresh: forceRefresh,
                               scopes: scopes,
                               correlationId: correlationId,
                               delegate: delegate)
    }
}
