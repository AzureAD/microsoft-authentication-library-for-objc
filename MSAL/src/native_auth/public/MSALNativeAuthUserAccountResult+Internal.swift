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
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        params.forceRefresh = forceRefresh
        params.correlationId = correlationId

        let challengeTypes = MSALNativeAuthPublicClientApplication.convertChallengeTypes(configuration.challengeTypes)
        let authority = try? MSALCIAMAuthority(url: configuration.authority.url)
        let config = MSALPublicClientApplicationConfig(clientId: configuration.clientId,
                                                       redirectUri: configuration.redirectUri,
                                                       authority: authority)

        guard let client = try? MSALNativeAuthPublicClientApplication(configuration: config, challengeTypes: challengeTypes)
        else {
            MSALLogger.log(
                            level: .error,
                            context: context,
                            format: "Config or challenge types unexpectedly found nil."
                        )
            Task { await delegate.onAccessTokenRetrieveError(
                error: RetrieveAccessTokenError(type: .generalError,
                                                correlationId: correlationId ?? context.correlationId())) }
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
