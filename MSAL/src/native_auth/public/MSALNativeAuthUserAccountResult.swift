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
    @objc public let account: MSALAccount

    let authTokens: MSALNativeAuthTokens
    let configuration: MSALNativeAuthConfiguration
    private let cacheAccessor: MSALNativeAuthCacheInterface

    /// Get the ID token for the account.
    @objc public var idToken: String? {
        authTokens.rawIdToken
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
            MSALLogger.log(
                level: .error,
                context: context,
                format: "Clearing MSAL token cache for the current account failed with error %@: \(error)"
            )
        }
    }

    /// Retrieves an access token for the account.
    /// - Parameters:
    ///   - forceRefresh: Ignore any existing access token in the cache and force MSAL to get a new access token from the service.
    ///   - correlationId: Optional. UUID to correlate this request with the server for debugging.
    ///   - delegate: Delegate that receives callbacks for the Get Access Token flow.
    @available(*, deprecated, message: "Use the 'getAccessToken' method that also receives a list of scopes to be included in the token")
    @objc public func getAccessToken(forceRefresh: Bool = false, correlationId: UUID? = nil, delegate: CredentialsDelegate) {
        Task {
            let controllerResponse = await getAccessTokenInternal(
                forceRefresh: forceRefresh,
                correlationId: correlationId,
                cacheAccessor: cacheAccessor
            )

            let delegateDispatcher = CredentialsDelegateDispatcher(delegate: delegate, telemetryUpdate: controllerResponse.telemetryUpdate)

            switch controllerResponse.result {
            case .success(let accessTokenResult):
                await delegateDispatcher.dispatchAccessTokenRetrieveCompleted(
                    result: accessTokenResult,
                    correlationId: controllerResponse.correlationId
                )
            case .failure(let error):
                await delegate.onAccessTokenRetrieveError(error: error)
            }
        }
    }

    /// Retrieves an access token for the account.
    /// - Parameters:
    ///   - client: The instance of Native Auth public client application.
    ///   - forceRefresh: Ignore any existing access token in the cache and force MSAL to get a new access token from the service.
    ///   - scopes: Optional. Permissions that should be included in the access token received after sign in flow has completed
    ///   - correlationId: Optional. UUID to correlate this request with the server for debugging.
    ///   - delegate: Delegate that receives callbacks for the Get Access Token flow.
    public func getAccessToken(forceRefresh: Bool = false,
                               scopes: [String]? = nil,
                               correlationId: UUID? = nil,
                               delegate: CredentialsDelegate) {

        let params = MSALSilentTokenParameters(scopes: scopes ?? [], account: account)
        params.forceRefresh = forceRefresh

        guard let config = MSALNativeAuthPublicClientApplication.sharedConfiguration,
              let challengeTypes = MSALNativeAuthPublicClientApplication.sharedChallengeTypes,
              let client = try? MSALNativeAuthPublicClientApplication(configuration: config, challengeTypes: challengeTypes)
        else { return }

        client.acquireTokenSilent(with: params) { result, error in

            if let error = error as? NSError {
                let accessTokenError = RetrieveAccessTokenError(type: .generalError,
                                                                correlationId: result?.correlationId ?? UUID(),
                                                                errorCodes: [error.code])
                Task { await delegate.onAccessTokenRetrieveError(error: accessTokenError) }
                return
            }

            if let result = result {
                let delegateDispatcher = CredentialsDelegateDispatcher(delegate: delegate, telemetryUpdate: nil)
                let accessTokenResult = MSALNativeAuthTokenResult(accessToken: result.accessToken,
                                                                  scopes: result.scopes,
                                                                  expiresOn: result.expiresOn)
                Task { await delegateDispatcher.dispatchAccessTokenRetrieveCompleted(result: accessTokenResult, correlationId: result.correlationId) }
                return
            }
            
            Task { await delegate.onAccessTokenRetrieveError(error: RetrieveAccessTokenError(type: .generalError, correlationId: correlationId ?? UUID())) }
        }
    }
}
