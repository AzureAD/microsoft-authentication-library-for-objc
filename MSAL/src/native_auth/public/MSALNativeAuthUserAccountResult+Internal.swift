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

extension MSALNativeAuthUserAccountResult {

    func getAccessTokenInternal(forceRefresh: Bool = false,
                                scopes: [String],
                                correlationId: UUID? = nil,
                                delegate: CredentialsDelegate) {

        let params = MSALSilentTokenParameters(scopes: scopes, account: account)
        params.forceRefresh = forceRefresh
        params.correlationId = correlationId

        guard let config = MSALNativeAuthPublicClientApplication.sharedConfiguration,
              let challengeTypes = MSALNativeAuthPublicClientApplication.sharedChallengeTypes,
              let client = try? MSALNativeAuthPublicClientApplication(configuration: config, challengeTypes: challengeTypes)
        else {
            Task { await delegate.onAccessTokenRetrieveError(error: RetrieveAccessTokenError(type: .generalError,
                                                                                             correlationId: correlationId ?? UUID())) }
            return
        }

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

            Task { await delegate.onAccessTokenRetrieveError(error: RetrieveAccessTokenError(type: .generalError, 
                                                                                             correlationId: correlationId ?? UUID())) }
        }
    }
}
