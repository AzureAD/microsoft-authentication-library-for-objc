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
    func signIn(params: MSALNativeAuthSignInWithPasswordParameters, delegate: SignInStartDelegate) async
    func signIn(params: MSALNativeAuthSignInWithCodeParameters, delegate: SignInCodeStartDelegate) async
    func submitCode(
        _ code: String,
        credentialToken: String,
        context: MSALNativeAuthRequestContext,
        scopes: [String],
        delegate: SignInVerifyCodeDelegate) async
    func resendCode(credentialToken: String, context: MSALNativeAuthRequestContext, scopes: [String], delegate: SignInResendCodeDelegate) async
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

    func signIn(params: MSALNativeAuthSignInWithPasswordParameters, delegate: SignInStartDelegate) async {
        let context = MSALNativeAuthRequestContext(correlationId: params.correlationId)
        MSALLogger.log(level: .verbose, context: context, format: "SignIn with email and password started")
        let scopes = joinScopes(params.scopes)
        let telemetryEvent = makeAndStartTelemetryEvent(id: .telemetryApiIdSignInWithPasswordStart, context: context)
        guard let request = createTokenRequest(
            username: params.username,
            password: params.password,
            scopes: scopes,
            grantType: .password,
            context: context
        ) else {
            stopTelemetryEvent(telemetryEvent, context: context, error: MSALNativeAuthError.invalidRequest)
            delegate.onSignInError(error: SignInStartError(type: .generalError))
            return
        }
        let config = factory.makeMSIDConfiguration(scope: scopes)
        let response = await performAndValidateTokenRequest(request, telemetryEvent: telemetryEvent, config: config, context: context)
        await handleSignInTokenROPCResult(
            response,
            scopes: scopes,
            context: context,
            telemetryEvent: telemetryEvent,
            delegate: delegate)
    }

    func signIn(params: MSALNativeAuthSignInWithCodeParameters, delegate: SignInCodeStartDelegate) {
        // call here /initiate
    }

    func submitCode(
        _ code: String,
        credentialToken: String,
        context: MSALNativeAuthRequestContext,
        scopes: [String],
        delegate: SignInVerifyCodeDelegate) async {
        let telemetryEvent = makeAndStartTelemetryEvent(id: .telemetryApiIdSignInSubmitCode, context: context)
        guard let request =
                createTokenRequest(scopes: scopes, credentialToken: credentialToken, oobCode: code, grantType: .oobCode, context: context ) else {
            stopTelemetryEvent(telemetryEvent, context: context, error: MSALNativeAuthError.invalidRequest)
            delegate.onSignInVerifyCodeError(
                error: VerifyCodeError(type: .generalError),
                newState: SignInCodeSentState(scopes: scopes, controller: self, flowToken: credentialToken))
            return
        }
        let config = factory.makeMSIDConfiguration(scope: scopes)
        let response = await performAndValidateTokenRequest(request, telemetryEvent: telemetryEvent, config: config, context: context)
        switch response {
        case .success(let validatedTokenResult, let tokenResponse):
            handleSuccessfulTokenResult(
                tokenResult: validatedTokenResult,
                tokenResponse: tokenResponse,
                telemetryEvent: telemetryEvent, context: context, config: config, delegate: delegate)
        case .credentialRequired:
            MSALLogger.log(
                level: .error,
                context: context,
                format: "SignIn submitCode, received unexpected credentialRequired result from /token API")
            stopTelemetryEvent(telemetryEvent, context: context, error: MSALNativeAuthError.generalError)
            delegate.onSignInVerifyCodeError(error: VerifyCodeError(type: .generalError), newState: nil)
        case .error(let errorType):
            MSALLogger.log(
                level: .verbose,
                context: context,
                format: "SignIn with email and password completed with errorType: \(errorType)")
            stopTelemetryEvent(telemetryEvent, context: context, error: errorType)
            delegate.onSignInVerifyCodeError(
                error: errorType.convertToVerifyCodeError(),
                newState: SignInCodeSentState(scopes: scopes, controller: self, flowToken: credentialToken))
        }
    }

    func resendCode(credentialToken: String, context: MSALNativeAuthRequestContext, scopes: [String], delegate: SignInResendCodeDelegate) async {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdSignInResendCode, context: context)
        guard let challengeRequest = createChallengeRequest(credentialToken: credentialToken, context: context) else {
            MSALLogger.log(level: .error, context: context, format: "SignIn ResendCode: Cannot create Challenge request object")
            let error = MSALNativeAuthGenericError()
            stopTelemetryEvent(event, context: context, error: error)
            DispatchQueue.main.async {
                delegate.onSignInResendCodeError(error: error, newState: nil)
            }
            return
        }
        let challengeResponse: Result<MSALNativeAuthSignInChallengeResponse, Error> = await performRequest(challengeRequest, context: context, event: event)
        let result = responseValidator.validateSignInChallengeResponse(context: context, result: challengeResponse)
        var error: MSALNativeAuthGenericError? = nil
        switch result {
        case .passwordRequired:
            error = MSALNativeAuthGenericError()
            MSALLogger.log(level: .error, context: context, format: "SignIn ResendCode: received unexpected password required API result")
            DispatchQueue.main.async {
                delegate.onSignInResendCodeError(error: MSALNativeAuthGenericError(), newState: nil)
            }
        case .error(let challengeError):
            error = MSALNativeAuthGenericError()
            MSALLogger.log(level: .error, context: context, format: "SignIn ResendCode: received challenge error response: \(challengeError)")
            DispatchQueue.main.async {
                delegate.onSignInResendCodeError(error: MSALNativeAuthGenericError(), newState: SignInCodeSentState(scopes: scopes, controller: self, flowToken: credentialToken))
            }
        case .codeRequired(let credentialToken, let sentTo, let channelType, let codeLength):
            let state = SignInCodeSentState(scopes: scopes, controller: self, flowToken: credentialToken)
            DispatchQueue.main.async {
                delegate.onSignInResendCodeSent(newState: state, displayName: sentTo, codeLength: codeLength)
            }
        }
        stopTelemetryEvent(event, context: context, error: error)
    }

    // MARK: - Private

    private func handleSignInTokenROPCResult(
        _ response: MSALNativeAuthSignInTokenValidatedResponse,
        scopes: [String],
        context: MSALNativeAuthRequestContext,
        telemetryEvent: MSIDTelemetryAPIEvent?,
        delegate: SignInStartDelegate) async {
            let config = factory.makeMSIDConfiguration(scope: scopes)
            switch response {
            case .success(let validatedTokenResult, let tokenResponse):
                handleSuccessfulTokenResult(
                    tokenResult: validatedTokenResult,
                    tokenResponse: tokenResponse,
                    telemetryEvent: telemetryEvent,
                    context: context,
                    config: config,
                    delegate: delegate)
            case .credentialRequired(let credentialToken):
                guard let challengeRequest = createChallengeRequest(credentialToken: credentialToken, context: context) else {
                    stopTelemetryEvent(telemetryEvent, context: context, error: MSALNativeAuthError.invalidRequest)
                    DispatchQueue.main.async {
                        delegate.onSignInError(error: SignInStartError(type: .generalError))
                    }
                    return
                }
                let challengeResponse: Result<MSALNativeAuthSignInChallengeResponse, Error> =
                await performRequest(challengeRequest, context: context, event: telemetryEvent)
                handleSignInChallengeResponse(
                    challengeResponse,
                    context: context,
                    telemetryEvent: telemetryEvent,
                    scopes: scopes,
                    delegate: delegate)
            case .error(let errorType):
                MSALLogger.log(
                    level: .verbose,
                    context: context,
                    format: "SignIn with email and password completed with errorType: \(errorType)")
                stopTelemetryEvent(telemetryEvent, context: context, error: errorType)
                delegate.onSignInError(error: errorType.convertToSignInStartError())
        }
    }

    private func handleSuccessfulTokenResult(
        tokenResult: MSIDTokenResult,
        tokenResponse: MSIDTokenResponse,
        telemetryEvent: MSIDTelemetryAPIEvent?,
        context: MSALNativeAuthRequestContext,
        config: MSIDConfiguration,
        delegate: SignInCompletedDelegate) {
        telemetryEvent?.setUserInformation(tokenResult.account)
        cacheTokenResponse(tokenResponse, context: context, msidConfiguration: config)
        let account = factory.makeUserAccount(tokenResult: tokenResult)
        stopTelemetryEvent(telemetryEvent, context: context)
        MSALLogger.log(
            level: .verbose,
            context: context,
            format: "SignIn with email and password completed successfully")
        delegate.onSignInCompleted(result: account)
    }

    private func handleSignInChallengeResponse(
        _ challengeResponse: Result<MSALNativeAuthSignInChallengeResponse, Error>,
        context: MSALNativeAuthRequestContext,
        telemetryEvent: MSIDTelemetryAPIEvent?,
        scopes: [String],
        delegate: SignInStartDelegate) {
            let result = responseValidator.validateSignInChallengeResponse(context: context, result: challengeResponse)
            switch result {
            case .passwordRequired(let credentialToken):
                print("merge Silviu's PR to and handle PasswordRequired state \(credentialToken)")
                //TODO: can't happen here
            case .error(let challengeError):
                DispatchQueue.main.async {
                    delegate.onSignInError(error: challengeError.convertToSignInStartError())
                }
            case .codeRequired(let credentialToken, let sentTo, let channelType, let codeLength):
                let state = SignInCodeSentState(scopes: scopes, controller: self, flowToken: credentialToken)
                DispatchQueue.main.async {
                    delegate.onSignInCodeSent(newState: state, displayName: sentTo, codeLength: codeLength)
                }
            }
            stopTelemetryEvent(telemetryEvent, context: context)
    }

    private func performAndValidateTokenRequest(
        _ request: MSIDHttpRequest,
        telemetryEvent: MSIDTelemetryAPIEvent?,
        config: MSIDConfiguration,
        context: MSALNativeAuthRequestContext) async -> MSALNativeAuthSignInTokenValidatedResponse {
        let aadTokenResponse: Result<MSIDAADTokenResponse, Error> = await performRequest(request, context: context, event: telemetryEvent)
        return responseValidator.validateSignInTokenResponse(
            context: context,
            msidConfiguration: config,
            result: aadTokenResponse
        )
    }

    private func createTokenRequest(
        username: String? = nil,
        password: String? = nil,
        scopes: [String],
        credentialToken: String? = nil,
        oobCode: String? = nil,
        grantType: MSALNativeAuthGrantType,
        context: MSIDRequestContext) -> MSIDHttpRequest? {
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
