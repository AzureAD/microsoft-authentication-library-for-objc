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

    internal let configuration: MSALNativeAuthInternalConfiguration
    internal var rawIdToken: String?
    private let cacheAccessor: MSALNativeAuthCacheInterface
    private let inputValidator: MSALNativeAuthInputValidating
    internal let silentTokenProviderFactory: MSALNativeAuthSilentTokenProviderBuildable

    /// Get the latest ID token for the account.
    @objc public var idToken: String? {
        rawIdToken
    }

    init(
        account: MSALAccount,
        rawIdToken: String?,
        configuration: MSALNativeAuthInternalConfiguration,
        cacheAccessor: MSALNativeAuthCacheInterface,
        inputValidator: MSALNativeAuthInputValidating = MSALNativeAuthInputValidator(),
        silentTokenProviderFactory: MSALNativeAuthSilentTokenProviderBuildable = MSALNativeAuthSilentTokenProviderFactory()
    ) {
        self.account = account
        self.rawIdToken = rawIdToken
        self.configuration = configuration
        self.cacheAccessor = cacheAccessor
        self.inputValidator = inputValidator
        self.silentTokenProviderFactory = silentTokenProviderFactory
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
            MSALNativeAuthLogger.logPII(
                level: .error,
                context: context,
                format: "Clearing MSAL token cache for the current account failed with error %@: \(MSALLogMaskWrapper.maskEUII(error))"
            )
        }
    }

    // Retrieves the access token for the currently signed in account from the cache for the provided parameters.
    /// - Parameters:
    ///   - parameters: Parameters used for the Get Access Token flow.
    ///   - delegate: Delegate that receives callbacks for the Get Access Token flow.
    ///
    @objc public func getAccessToken(parameters: MSALNativeAuthGetAccessTokenParameters,
                                     delegate: CredentialsDelegate) {

        MSALNativeAuthLogger.log(
            level: .info,
            context: nil,
            format: "Retrieving access token with parameters started."
        )

        getAccessTokenInternal(forceRefresh: parameters.forceRefresh,
                               scopes: parameters.scopes ?? [],
                               claimsRequest: parameters.claimsRequest,
                               correlationId: parameters.correlationId,
                               delegate: delegate)
    }
}
