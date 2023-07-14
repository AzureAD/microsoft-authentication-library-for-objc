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
@_implementationOnly import MSAL_Private

final class MSALNativeAuthCredentialsController: MSALNativeAuthTokenController, MSALNativeAuthCredentialsControlling {

    // MARK: - Variables

    private let cacheAccessor: MSALNativeAuthCacheInterface

    // MARK: - Init

    override init(
        clientId: String,
        requestProvider: MSALNativeAuthTokenRequestProviding,
        cacheAccessor: MSALNativeAuthCacheInterface,
        factory: MSALNativeAuthResultBuildable,
        responseValidator: MSALNativeAuthTokenResponseValidating
    ) {
        self.cacheAccessor = cacheAccessor
        super.init(
            clientId: clientId,
            requestProvider: requestProvider,
            cacheAccessor: cacheAccessor,
            factory: factory,
            responseValidator: responseValidator
        )
    }

    convenience init(config: MSALNativeAuthConfiguration) {
        let factory = MSALNativeAuthResultFactory(config: config)
        self.init(
            clientId: config.clientId,
            requestProvider: MSALNativeAuthTokenRequestProvider(
                requestConfigurator: MSALNativeAuthRequestConfigurator(config: config)),
            cacheAccessor: MSALNativeAuthCacheAccessor(),
            factory: factory,
            responseValidator: MSALNativeAuthTokenResponseValidator(factory: factory,
                                                                    msidValidator: MSIDTokenResponseValidator())
        )
    }

    // MARK: Internal

    func retrieveUserAccountResult(context: MSALNativeAuthRequestContext) -> MSALNativeAuthUserAccountResult? {
        let accounts = self.allAccounts()
        if let account = accounts.first {
            // We pass an empty array of scopes because that will return all tokens for that account identifier
            // Because we expect to be only one access token per account at this point, it's ok for the array to be empty
            guard let tokens = retrieveTokens(account: account,
                                              scopes: [],
                                              context: context) else {
                MSALLogger.log(level: .verbose, context: nil, format: "No tokens found")
                return nil
            }
            return factory.makeUserAccountResult(account: account, authTokens: tokens)
        } else {
            MSALLogger.log(level: .verbose, context: nil, format: "No account found")
        }
        return nil
    }

    func refreshToken(context: MSALNativeAuthRequestContext, authTokens: MSALNativeAuthTokens, delegate: CredentialsDelegate) async {
        MSALLogger.log(level: .verbose, context: context, format: "Refresh started")
        let telemetryEvent = makeAndStartTelemetryEvent(id: .telemetryApiIdRefreshToken, context: context)
        let scopes = authTokens.accessToken?.scopes.array as? [String] ?? []
        guard let request = createRefreshTokenRequest(
            scopes: scopes,
            refreshToken: authTokens.refreshToken?.refreshToken,
            context: context
        ) else {
            stopTelemetryEvent(telemetryEvent, context: context, error: MSALNativeAuthInternalError.invalidRequest)
            await delegate.onAccessTokenRetrieveError(error: RetrieveAccessTokenError(type: .generalError))
            return
        }
        let config = factory.makeMSIDConfiguration(scopes: scopes)
        let response = await performAndValidateTokenRequest(request, config: config, context: context)
        await handleTokenResponse(
            response,
            scopes: scopes,
            context: context,
            telemetryEvent: telemetryEvent,
            onSuccess: delegate.onAccessTokenRetrieveCompleted,
            onError: delegate.onAccessTokenRetrieveError)
    }

    // MARK: - Private

    private func allAccounts() -> [MSALAccount] {
        do {
            // We pass an empty array of scopes because that will return all accounts
            // that have been saved for the current Client Id. We expect only one account to exist at this point per Client Id
            let config = factory.makeMSIDConfiguration(scopes: [])
            return try cacheAccessor.getAllAccounts(configuration: config)
        } catch {
            MSALLogger.log(
                level: .error,
                context: nil,
                format: "Error retrieving accounts \(error)")
        }
        return []
    }

    private func retrieveTokens(
        account: MSALAccount,
        scopes: [String],
        context: MSALNativeAuthRequestContext
    ) -> MSALNativeAuthTokens? {
        do {
            let config = factory.makeMSIDConfiguration(scopes: scopes)
            return try cacheAccessor.getTokens(account: account, configuration: config, context: context)
        } catch {
            MSALLogger.log(
                level: .error,
                context: context,
                format: "Error retrieving tokens: \(error)"
            )
        }
        return nil
    }

    private func handleTokenResponse(
        _ response: MSALNativeAuthTokenValidatedResponse,
        scopes: [String],
        context: MSALNativeAuthRequestContext,
        telemetryEvent: MSIDTelemetryAPIEvent?,
        onSuccess: @MainActor @escaping (String) -> Void,
        onError: @MainActor @escaping (RetrieveAccessTokenError) -> Void) async {
            let config = factory.makeMSIDConfiguration(scopes: scopes)
            switch response {
            case .success(let tokenResponse):
                await handleMSIDTokenResponse(
                    tokenResponse: tokenResponse,
                    telemetryEvent: telemetryEvent,
                    context: context,
                    config: config,
                    onSuccess: onSuccess,
                    onError: onError)
            case .error(let errorType):
                MSALLogger.log(
                    level: .error,
                    context: context,
                    format: "Refresh Token completed with errorType: \(errorType)")
                stopTelemetryEvent(telemetryEvent, context: context, error: errorType)
                await onError(errorType.convertToRetrieveAccessTokenError())
            }
        }

    private func handleMSIDTokenResponse(
        tokenResponse: MSIDTokenResponse,
        telemetryEvent: MSIDTelemetryAPIEvent?,
        context: MSALNativeAuthRequestContext,
        config: MSIDConfiguration,
        onSuccess: @MainActor @escaping (String) -> Void,
        onError: @MainActor @escaping (RetrieveAccessTokenError) -> Void) async {
            do {
                let tokenResult = try cacheTokenResponse(tokenResponse, context: context, msidConfiguration: config)
                telemetryEvent?.setUserInformation(tokenResult.account)
                stopTelemetryEvent(telemetryEvent, context: context)
                MSALLogger.log(
                    level: .verbose,
                    context: context,
                    format: "Refresh Token completed successfully")
                await onSuccess(tokenResult.accessToken.accessToken)
            } catch {
                MSALLogger.log(
                    level: .error,
                    context: context,
                    format: "Token Result was not created properly!")
                await onError(RetrieveAccessTokenError(type: .generalError))
            }
        }
}
