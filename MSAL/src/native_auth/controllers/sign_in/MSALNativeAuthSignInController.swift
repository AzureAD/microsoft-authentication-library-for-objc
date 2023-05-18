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

@_implementationOnly import MSAL_Private

protocol MSALNativeAuthSignInControlling {
    func signIn(params: MSALNativeAuthSignInWithPasswordParameters, delegate: SignInStartDelegate)
    func signIn(params: MSALNativeAuthSignInWithCodeParameters, delegate: SignInCodeStartDelegate)
    func submitCode(_ code: String, credentialToken: String, context: MSIDRequestContext, delegate: SignInVerifyCodeDelegate)
    func resendCode(credentialToken: String, context: MSIDRequestContext, delegate: SignInResendCodeDelegate)
}

final class MSALNativeAuthSignInController: MSALNativeAuthBaseController, MSALNativeAuthSignInControlling {

    // MARK: - Variables

    private let requestProvider: MSALNativeAuthSignInRequestProviding
    private let factory: MSALNativeAuthResultBuildable
    private let responseValidator: MSALNativeAuthSignInResponseValidating

    // MARK: - Init

    init(
        clientId: String,
        requestProvider: MSALNativeAuthSignInRequestProviding,
        cacheAccessor: MSALNativeAuthCacheInterface,
        factory: MSALNativeAuthResultBuildable,
        responseValidator: MSALNativeAuthSignInResponseValidating
    ) {
        self.requestProvider = requestProvider
        self.factory = factory
        self.responseValidator = responseValidator
        super.init(
            clientId: clientId,
            cacheAccessor: cacheAccessor
        )
    }

    convenience init(config: MSALNativeAuthConfiguration) {
        self.init(
            clientId: config.clientId,
            requestProvider: MSALNativeAuthSignInRequestProvider(
                config: config,
                requestConfigurator: MSALNativeAuthRequestConfigurator()),
            cacheAccessor: MSALNativeAuthCacheAccessor(),
            factory: MSALNativeAuthResultFactory(config: config),
            responseValidator: MSALNativeAuthResponseValidator(responseHandler: MSALNativeAuthResponseHandler())
        )
    }

    func signIn(params: MSALNativeAuthSignInWithPasswordParameters, delegate: SignInStartDelegate) {
        let context = MSALNativeAuthRequestContext(correlationId: params.correlationId)
        MSALLogger.log(level: .verbose, context: context, format: "SignIn with email and password started")
        let scopes = joinScopes(params.scopes)
        let telemetryEvent = makeLocalTelemetryApiEvent(
            name: MSID_TELEMETRY_EVENT_API_EVENT,
            telemetryApiId: .telemetryApiIdSignInWithPassword,
            context: context
        )
        startTelemetryEvent(telemetryEvent, context: context)
        guard let request = createTokenRequest(
            username: params.username,
            password: params.password,
            scopes: scopes,
            context: context
        ) else {
            stopTelemetryEvent(telemetryEvent, context: context, error: MSALNativeAuthError.invalidRequest)
            delegate.onSignInError(error: SignInStartError(type: .generalError))
            return
        }
        Task {
            let aadTokenResponse: Result<MSIDAADTokenResponse, Error> = await performRequest(request, context: context, event: telemetryEvent)
            handleSignInTokenResult(
                aadTokenResponse,
                scopes: scopes,
                context: context,
                telemetryEvent: telemetryEvent,
                delegate: delegate)
        }
    }

    func signIn(params: MSALNativeAuthSignInWithCodeParameters, delegate: SignInCodeStartDelegate) {
        // call here /initiate
    }

    func submitCode(_ code: String, credentialToken: String, context: MSIDRequestContext, delegate: SignInVerifyCodeDelegate) {

    }

    func resendCode(credentialToken: String, context: MSIDRequestContext, delegate: SignInResendCodeDelegate) {

    }

    // MARK: - Private

    private func handleSignInTokenResult(
        _ aadTokenResponse: Result<MSIDAADTokenResponse, Error>,
        scopes: [String],
        context: MSALNativeAuthRequestContext,
        telemetryEvent: MSIDTelemetryAPIEvent?,
        delegate: SignInStartDelegate) {
        let config = factory.makeMSIDConfiguration(scope: scopes)
        let result = responseValidator.validateSignInTokenResponse(
            context: context,
            msidConfiguration: config,
            result: aadTokenResponse
        )
        switch result {
        case .success(let validatedTokenResult, let tokenResponse):
            telemetryEvent?.setUserInformation(validatedTokenResult.account)
            cacheTokenResponse(tokenResponse, context: context, msidConfiguration: config)
            let account = factory.makeUserAccount(tokenResult: validatedTokenResult)
            stopTelemetryEvent(telemetryEvent, context: context)
            MSALLogger.log(
                level: .verbose,
                context: context,
                format: "SignIn with email and password completed successfully")
            delegate.onSignInCompleted(result: account)
        case .credentialRequired(let credentialToken):
            guard let challengeRequest = createChallengeRequest(credentialToken: credentialToken, context: context) else {
                stopTelemetryEvent(telemetryEvent, context: context, error: MSALNativeAuthError.invalidRequest)
                DispatchQueue.main.async {
                    delegate.onSignInError(error: SignInStartError(type: .generalError))
                }
                return
            }
            print("credential required")
            Task {
                let challengeResponse: Result<MSALNativeAuthSignInChallengeResponse, Error> =
                await performRequest(challengeRequest, context: context, event: telemetryEvent)
                handleSignInChallengeResponse(challengeResponse, context: context, config: config, telemetryEvent: telemetryEvent, delegate: delegate)
            }
        case .error(let errorType):
            MSALLogger.log(
                level: .verbose,
                context: context,
                format: "SignIn with email and password completed with errorType: \(errorType)")
            stopTelemetryEvent(telemetryEvent, context: context, error: errorType)
            delegate.onSignInError(error: errorType.convertToSignInStartError())
        }
    }

    private func handleSignInChallengeResponse(
        _ challengeResponse: Result<MSALNativeAuthSignInChallengeResponse, Error>,
        context: MSALNativeAuthRequestContext,
        config: MSIDConfiguration,
        telemetryEvent: MSIDTelemetryAPIEvent?,
        delegate: SignInStartDelegate) {
            let result = responseValidator.validateSignInChallengeResponse(context: context, msidConfiguration: config, result: challengeResponse)
            switch result {
            case .passwordRequired(let credentialToken):
                print("merge Silviu's PR to and handle PasswordRequired state \(credentialToken)")
            case .error(let challengeError):
                return delegate.onSignInError(error: challengeError.convertToSignInStartError())
            case .codeRequired(let credentialToken, let sentTo, let channelType, let codeLength):
                let state = SignInCodeSentState(controller: self, flowToken: credentialToken)
                delegate.onSignInCodeSent(newState: state, displayName: sentTo, codeLength: codeLength)
            }
    }

    private func createTokenRequest(username: String, password: String?, scopes: [String], context: MSIDRequestContext) -> MSIDHttpRequest? {
        do {
            let params = MSALNativeAuthSignInTokenRequestParameters(
                config: factory.config,
                context: context,
                username: username,
                credentialToken: nil,
                signInSLT: nil,
                grantType: .password,
                scope: scopes.joined(separator: ","),
                password: password,
                oobCode: nil)
            return try requestProvider.token(parameters: params, context: context)
        } catch {
            MSALLogger.log(level: .error, context: context, format: "Error creating SignIn Token Request: \(error)")
            return nil
        }
    }

    private func createChallengeRequest(
        credentialToken: String,
        context: MSIDRequestContext
    ) -> MSIDHttpRequest? {
        do {
            let params = MSALNativeAuthSignInChallengeRequestParameters(
                config: factory.config,
                context: context,
                credentialToken: credentialToken
            )
            return try requestProvider.challenge(parameters: params, context: context)
        } catch {
            MSALLogger.log(level: .error, context: context, format: "Error creating SignIn Token Request: \(error)")
            return nil
        }
    }

    private func joinScopes(_ scopes: [String]?) -> [String] {
        let defaultOIDCScopes = MSALPublicClientApplication.defaultOIDCScopes().array
        guard let scopes = scopes else {
            return defaultOIDCScopes as? [String] ?? []
        }
        let joinedScopes = NSMutableOrderedSet(array: scopes)
        joinedScopes.addObjects(from: defaultOIDCScopes)
        return joinedScopes.array as? [String] ?? []
    }

    private func cacheTokenResponse(_ tokenResponse: MSIDTokenResponse, context: MSALNativeAuthRequestContext, msidConfiguration: MSIDConfiguration) {
        do {
            try cacheAccessor?.saveTokensAndAccount(tokenResult: tokenResponse, configuration: msidConfiguration, context: context)
        } catch {
            MSALLogger.log(level: .error, context: context, format: "Error caching response: \(error) (ignoring)")
        }
    }
}
