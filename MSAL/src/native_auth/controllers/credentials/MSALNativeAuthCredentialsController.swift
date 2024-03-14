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

    convenience init(config: MSALNativeAuthConfiguration, cacheAccessor: MSALNativeAuthCacheInterface) {
        let factory = MSALNativeAuthResultFactory(config: config, cacheAccessor: cacheAccessor)
        self.init(
            clientId: config.clientId,
            requestProvider: MSALNativeAuthTokenRequestProvider(
                requestConfigurator: MSALNativeAuthRequestConfigurator(config: config)),
            cacheAccessor: cacheAccessor,
            factory: factory,
            responseValidator: MSALNativeAuthTokenResponseValidator(factory: factory,
                                                                    msidValidator: MSIDTokenResponseValidator())
        )
    }

    // MARK: Internal

    func retrieveUserAccountResult(context: MSALNativeAuthRequestContext) -> MSALNativeAuthUserAccountResult? {
        let accounts = self.allAccounts()
        if let account = accounts.first {
            // we should only retrieve the ID token at this point. Configuration.target can be nil (we don't need scopes)
            // AT needs to be retrieved on getAccessToken function. We need scope here
            // RT needs to be retrieved if AT is not found, expired or force refresh is true (only when needed). Configuration.target can be nil (we don't need scopes)
            // TODO: modify here
            guard let tokens = retrieveTokens(account: account,
                                              scopes: [],
                                              context: context) else {
                MSALLogger.log(level: .verbose, context: nil, format: "No tokens found")
                return nil
            }
            return factory.makeUserAccountResult(account: account, rawIdToken: tokens.rawIdToken)
        } else {
            MSALLogger.log(level: .verbose, context: nil, format: "No account found")
        }
        return nil
    }
    
    func retrieveAccessToken(context: MSALNativeAuthRequestContext, account: MSALAccount, scopes: [String]?, forceRefresh: Bool) async -> RefreshTokenCredentialControllerResponse {
        guard let refreshToken = retrieveRefreshToken(account: account, context: context) else {
            return .init(.failure(
                RetrieveAccessTokenError(
                    type: .generalError,
                    message: "error retrieving refresh token from cache",
                    correlationId: context.correlationId(),
                    errorCodes: [],
                    errorUri: nil)
            ), correlationId: context.correlationId())
        }
        var accessToken: MSIDAccessToken?
        let config = factory.makeMSIDConfiguration(scopes: scopes ?? [])
        accessToken = try? cacheAccessor.getAccessToken(account: account, configuration: config, context: context)
        
        if accessToken == nil || forceRefresh || accessToken!.isExpired() {
            return await self.refreshToken(context: context, scopes: scopes, refreshToken: refreshToken.refreshToken)
        } else {
            return .init(.success(MSALNativeAuthTokenResult(
                accessToken: accessToken!.accessToken, scopes: accessToken!.scopes.array as! [String], expiresOn: accessToken?.expiresOn)), correlationId: context.correlationId())
        }
    }

    func refreshToken(context: MSALNativeAuthRequestContext, scopes: [String]?, refreshToken: String?) async -> RefreshTokenCredentialControllerResponse {
        MSALLogger.log(level: .verbose, context: context, format: "Refresh started")
        let telemetryEvent = makeAndStartTelemetryEvent(id: .telemetryApiIdRefreshToken, context: context)
        guard let request = createRefreshTokenRequest(
            scopes: scopes ?? ["offline_access", "openid", "profile"],
            refreshToken: refreshToken,
            context: context
        ) else {
            stopTelemetryEvent(telemetryEvent, context: context, error: MSALNativeAuthInternalError.invalidRequest)
            return .init(
                .failure(RetrieveAccessTokenError(type: .generalError, correlationId: context.correlationId())),
                correlationId: context.correlationId()
            )
        }
        let config = factory.makeMSIDConfiguration(scopes: scopes ?? ["offline_access", "openid", "profile"])
        let response = await performAndValidateTokenRequest(request, config: config, context: context)
        return handleTokenResponse(
            response,
            scopes: scopes ?? ["offline_access", "openid", "profile"],
            context: context,
            telemetryEvent: telemetryEvent
        )
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
    
    private func retrieveRefreshToken(
        account: MSALAccount,
        context: MSALNativeAuthRequestContext
    ) -> MSIDRefreshToken? {
        do {
            let config = factory.makeMSIDConfiguration(scopes: nil)
            return try cacheAccessor.getRefreshToken(account: account, configuration: config, context: context)
        } catch {
            MSALLogger.log(
                level: .error,
                context: context,
                format: "Error retrieving refresh tokens: \(error)"
            )
        }
        return nil
    }

    private func handleTokenResponse(
        _ response: MSALNativeAuthTokenValidatedResponse,
        scopes: [String],
        context: MSALNativeAuthRequestContext,
        telemetryEvent: MSIDTelemetryAPIEvent?
    ) -> RefreshTokenCredentialControllerResponse {
        let config = factory.makeMSIDConfiguration(scopes: scopes)
        switch response {
        case .success(let tokenResponse):
            return handleMSIDTokenResponse(
                tokenResponse: tokenResponse,
                telemetryEvent: telemetryEvent,
                context: context,
                config: config
            )
        case .error(let errorType):
            let error = errorType.convertToRetrieveAccessTokenError(correlationId: context.correlationId())
            MSALLogger.log(
                level: .error,
                context: context,
                format: "Refresh Token completed with error: \(error.errorDescription ?? "No error description")")
            stopTelemetryEvent(telemetryEvent, context: context, error: error)
            return .init(.failure(error), correlationId: context.correlationId())
        }
    }

    private func handleMSIDTokenResponse(
        tokenResponse: MSIDTokenResponse,
        telemetryEvent: MSIDTelemetryAPIEvent?,
        context: MSALNativeAuthRequestContext,
        config: MSIDConfiguration
    ) -> RefreshTokenCredentialControllerResponse {
        do {
            let tokenResult = try cacheTokenResponse(tokenResponse, context: context, msidConfiguration: config)
            MSALLogger.log(
                level: .verbose,
                context: context,
                format: "Refresh Token completed successfully")
            // TODO: Handle tokenResult.refreshToken as? MSIDRefreshToken in a safer way
            return .init(
                .success(MSALNativeAuthTokenResult(
                    accessToken: tokenResult.accessToken.accessToken, scopes: tokenResult.accessToken.scopes.array as! [String], expiresOn: tokenResult.accessToken.expiresOn)),
                correlationId: context.correlationId(),
                telemetryUpdate: { [weak self] result in
                telemetryEvent?.setUserInformation(tokenResult.account)
                self?.stopTelemetryEvent(telemetryEvent, context: context, delegateDispatcherResult: result)
            })
        } catch {
            let error = RetrieveAccessTokenError(type: .generalError, correlationId: context.correlationId())
            MSALLogger.log(
                level: .error,
                context: context,
                format: "Token Result was not created properly error - \(error)")
            stopTelemetryEvent(telemetryEvent, context: context, error: error)
            return .init(.failure(error), correlationId: context.correlationId())
        }
    }
}
