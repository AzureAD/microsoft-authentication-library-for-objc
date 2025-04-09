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

    func getAccessTokenInternal(forceRefresh: Bool,
                                scopes: [String],
                                claimsRequest: MSALClaimsRequest?,
                                correlationId: UUID?,
                                delegate: CredentialsDelegate) {

        let params = MSALSilentTokenParameters(scopes: scopes, account: account)
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        params.forceRefresh = forceRefresh
        params.correlationId = correlationId
        params.claimsRequest = claimsRequest

        let challengeTypes = MSALNativeAuthPublicClientApplication.convertChallengeTypes(configuration.challengeTypes)
        let authority = try? MSALCIAMAuthority(url: configuration.authority.url)
        let config = MSALPublicClientApplicationConfig(clientId: configuration.clientId,
                                                       redirectUri: configuration.redirectUri,
                                                       authority: authority)
        config.bypassRedirectURIValidation = configuration.redirectUri == nil

        guard let silentTokenProvider = try? silentTokenProviderFactory.makeSilentTokenProvider(configuration: config, challengeTypes: challengeTypes)
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
        silentTokenProvider.acquireTokenSilent(parameters: params) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error as? NSError {
                let accessTokenError = self.createRetrieveAccessTokenError(error: error, context: context)
                Task { await delegate.onAccessTokenRetrieveError(error: accessTokenError) }
                return
            }

            if let result = result {
                let delegateDispatcher = CredentialsDelegateDispatcher(delegate: delegate, telemetryUpdate: nil)
                self.rawIdToken = result.rawIdToken
                self.account = result.account
                Task { await delegateDispatcher.dispatchAccessTokenRetrieveCompleted(result: result.accessTokenResult,
                                                                                     correlationId: result.correlationId) }
                return
            }

            Task {
                await delegate.onAccessTokenRetrieveError(error: RetrieveAccessTokenError(
                    type: .generalError,
                    correlationId: correlationId ?? context.correlationId())
                )
            }
        }
    }

    private func createRetrieveAccessTokenError(error: NSError, context: MSALNativeAuthRequestContext) -> RetrieveAccessTokenError {
        if let innerError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
           return createRetrieveAccessTokenError(error: innerError, context: context)
        }
        var message = error.userInfo[MSALErrorDescriptionKey] as? String ?? error.localizedDescription
        let errorCodes = error.userInfo[MSALSTSErrorCodesKey] as? [Int] ?? []
        if isMFARequiredError(errorCodes: errorCodes) {
            message = MSALNativeAuthErrorMessage.refreshTokenMFARequiredError + message
        } else if isStrongAuthRequiredError(errorCodes: errorCodes) {
            message = MSALNativeAuthErrorMessage.strongAuthenticationRequiredError + message
        } else if isResetPasswordRequiredError(errorCodes: errorCodes) {
            message = MSALNativeAuthErrorMessage.passwordResetRequired + message
        }
        let correlationId = correlationIdFromMSALError(error: error) ?? context.correlationId()
        return RetrieveAccessTokenError(type: .generalError, message: message, correlationId: correlationId, errorCodes: errorCodes)
    }

    private func correlationIdFromMSALError(error: NSError) -> UUID? {
        return UUID(uuidString: error.userInfo[MSALCorrelationIDKey] as? String ?? "")
    }

    private func isMFARequiredError(errorCodes: [Int]) -> Bool {
        let mfaRequiredErrorCode = 50076
        return errorCodes.contains(mfaRequiredErrorCode)
    }

    private func isStrongAuthRequiredError(errorCodes: [Int]) -> Bool {
        let strongAuthRequiredErrorCode = 50079
        return errorCodes.contains(strongAuthRequiredErrorCode)
    }

    private func isResetPasswordRequiredError(errorCodes: [Int]) -> Bool {
        return errorCodes.contains(MSALNativeAuthESTSApiErrorCodes.resetPasswordRequired.rawValue)
    }
}
