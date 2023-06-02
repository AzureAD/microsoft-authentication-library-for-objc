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

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
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
                requestConfigurator: MSALNativeAuthRequestConfigurator(config: config)),
            cacheAccessor: MSALNativeAuthCacheAccessor(),
            factory: MSALNativeAuthResultFactory(config: config),
            responseValidator: MSALNativeAuthSignInResponseValidator(responseHandler: MSALNativeAuthResponseHandler())
        )
    }

    // MARK: - Internal

    func signIn(params: MSALNativeAuthSignInWithPasswordParameters, delegate: SignInPasswordStartDelegate) async {
        MSALLogger.log(level: .verbose, context: params.context, format: "SignIn with email and password started")
        let scopes = joinScopes(params.scopes)
        let telemetryEvent = makeAndStartTelemetryEvent(id: .telemetryApiIdSignInWithPasswordStart, context: params.context)
        guard let request = createTokenRequest(
            username: params.username,
            password: params.password,
            scopes: scopes,
            grantType: .password,
            addNcaFlag: true,
            context: params.context
        ) else {
            stopTelemetryEvent(telemetryEvent, context: params.context, error: MSALNativeAuthError.invalidRequest)
            DispatchQueue.main.async { delegate.onSignInPasswordError(error: SignInPasswordStartError(type: .generalError)) }
            return
        }
        let config = factory.makeMSIDConfiguration(scope: scopes)
        let response = await performAndValidateTokenRequest(request, config: config, context: params.context)
        await handleSignInTokenResult(
            response,
            scopes: scopes,
            context: params.context,
            telemetryEvent: telemetryEvent,
            delegate: delegate)
    }

    func signIn(params: MSALNativeAuthSignInWithCodeParameters, delegate: SignInCodeStartDelegate) async {
        MSALLogger.log(level: .verbose, context: params.context, format: "SignIn using code started")
        let telemetryEvent = makeAndStartTelemetryEvent(id: .telemetryApiIdSignInWithCodeStart, context: params.context)
        guard let request = createInitiateRequest(username: params.username, context: params.context) else {
            stopTelemetryEvent(telemetryEvent, context: params.context, error: MSALNativeAuthError.invalidRequest)
            DispatchQueue.main.async {  delegate.onSignInCodeError(error: SignInCodeStartError(type: .generalError)) }
            return
        }
        let initiateResponse: Result<MSALNativeAuthSignInInitiateResponse, Error> =
        await performRequest(request, context: params.context)
        let validatedResponse = responseValidator.validate(context: params.context, result: initiateResponse)
        switch validatedResponse {
        case .success(credentialToken: let credentialToken):
            let validatedResponse =
            await performAndValidateChallengeRequest(credentialToken: credentialToken, telemetryEvent: telemetryEvent, context: params.context)
            let scopes = joinScopes(params.scopes)
            handleSignInChallengeResponse(
                validatedResponse,
                context: params.context,
                username: params.username,
                telemetryEvent: telemetryEvent,
                scopes: scopes,
                delegate: delegate)
        case .error(let error):
            MSALLogger.log(level: .error, context: params.context, format: "SignIn using code: an error occurred after calling /initiate API")
            stopTelemetryEvent(telemetryEvent, context: params.context, error: error)
            DispatchQueue.main.async { delegate.onSignInCodeError(error: error.convertToSignInCodeStartError()) }
        }
    }

    func submitCode(
        _ code: String,
        credentialToken: String,
        context: MSALNativeAuthRequestContext,
        scopes: [String],
        delegate: SignInVerifyCodeDelegate) async {
        let telemetryEvent = makeAndStartTelemetryEvent(id: .telemetryApiIdSignInSubmitCode, context: context)
        guard let request = createTokenRequest(
            scopes: scopes,
            credentialToken: credentialToken,
            oobCode: code,
            grantType: .oobCode,
            includeChallengeType: false,
            context: context) else {
            stopTelemetryEvent(telemetryEvent, context: context, error: MSALNativeAuthError.invalidRequest)
            DispatchQueue.main.async {
                delegate.onSignInVerifyCodeError(
                    error: VerifyCodeError(type: .generalError),
                    newState: SignInCodeRequiredState(scopes: scopes, controller: self, flowToken: credentialToken))
            }
            return
        }
        let config = factory.makeMSIDConfiguration(scope: scopes)
        let response = await performAndValidateTokenRequest(request, config: config, context: context)
        switch response {
        case .success(let validatedTokenResult, let tokenResponse):
            handleSuccessfulTokenResult(
                tokenResult: validatedTokenResult,
                tokenResponse: tokenResponse,
                telemetryEvent: telemetryEvent, context: context, config: config, delegate: delegate)
        case .error(let errorType):
            MSALLogger.log(
                level: .verbose,
                context: context,
                format: "SignIn with password completed with errorType: \(errorType)")
            stopTelemetryEvent(telemetryEvent, context: context, error: errorType)
            DispatchQueue.main.async {
                delegate.onSignInVerifyCodeError(
                    error: errorType.convertToVerifyCodeError(),
                    newState: SignInCodeRequiredState(scopes: scopes, controller: self, flowToken: credentialToken))
            }
        }
    }

    func submitPassword(
        _ password: String,
        username: String,
        credentialToken: String,
        context: MSALNativeAuthRequestContext,
        scopes: [String],
        delegate: SignInPasswordRequiredDelegate) async {
        let telemetryEvent = makeAndStartTelemetryEvent(id: .telemetryApiIdSignInSubmitPassword, context: context)
        guard let request = createTokenRequest(
            username: username, password: password, scopes: scopes, credentialToken: credentialToken, grantType: .password, context: context) else {
            stopTelemetryEvent(telemetryEvent, context: context, error: MSALNativeAuthError.invalidRequest)
            DispatchQueue.main.async {
                delegate.onSignInPasswordRequiredError(
                    error: PasswordRequiredError(type: .generalError),
                    newState: SignInPasswordRequiredState(scopes: scopes, username: username, controller: self, flowToken: credentialToken))
            }
            return
        }
        let config = factory.makeMSIDConfiguration(scope: scopes)
        let response = await performAndValidateTokenRequest(request, config: config, context: context)
        switch response {
        case .success(let validatedTokenResult, let tokenResponse):
            handleSuccessfulTokenResult(
                tokenResult: validatedTokenResult,
                tokenResponse: tokenResponse,
                telemetryEvent: telemetryEvent, context: context, config: config, delegate: delegate)
        case .error(let errorType):
            MSALLogger.log(
                level: .verbose,
                context: context,
                format: "SignIn with email and password completed with errorType: \(errorType)")
            stopTelemetryEvent(telemetryEvent, context: context, error: errorType)
            DispatchQueue.main.async {
                delegate.onSignInPasswordRequiredError(
                    error: errorType.convertToPasswordRequiredError(),
                    newState: SignInPasswordRequiredState(scopes: scopes, username: username, controller: self, flowToken: credentialToken))
            }
        }
    }

    func resendCode(credentialToken: String, context: MSALNativeAuthRequestContext, scopes: [String], delegate: SignInResendCodeDelegate) async {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdSignInResendCode, context: context)
        let result = await performAndValidateChallengeRequest(credentialToken: credentialToken, telemetryEvent: event, context: context)
        var error: MSALNativeAuthGenericError?
        switch result {
        case .passwordRequired:
            error = MSALNativeAuthGenericError()
            MSALLogger.log(level: .error, context: context, format: "SignIn ResendCode: received unexpected password required API result")
            DispatchQueue.main.async { delegate.onSignInResendCodeError(error: MSALNativeAuthGenericError(), newState: nil) }
        case .error(let challengeError):
            error = MSALNativeAuthGenericError()
            MSALLogger.log(level: .error, context: context, format: "SignIn ResendCode: received challenge error response: \(challengeError)")
            DispatchQueue.main.async {
                delegate.onSignInResendCodeError(
                    error: MSALNativeAuthGenericError(),
                    newState: SignInCodeRequiredState(scopes: scopes, controller: self, flowToken: credentialToken))
            }
        case .codeRequired(let credentialToken, let sentTo, let channelType, let codeLength):
            let state = SignInCodeRequiredState(scopes: scopes, controller: self, flowToken: credentialToken)
            DispatchQueue.main.async {
                delegate.onSignInResendCodeCodeRequired(newState: state, sentTo: sentTo, channelTargetType: channelType, codeLength: codeLength)
            }
        }
        stopTelemetryEvent(event, context: context, error: error)
    }

    // MARK: - Private

    private func handleSignInTokenResult(
        _ response: MSALNativeAuthSignInTokenValidatedResponse,
        scopes: [String],
        context: MSALNativeAuthRequestContext,
        telemetryEvent: MSIDTelemetryAPIEvent?,
        delegate: SignInPasswordStartDelegate) async {
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
            case .error(let errorType):
                MSALLogger.log(
                    level: .verbose,
                    context: context,
                    format: "SignIn with email and password completed with errorType: \(errorType)")
                stopTelemetryEvent(telemetryEvent, context: context, error: errorType)
                DispatchQueue.main.async { delegate.onSignInPasswordError(error: errorType.convertToSignInPasswordStartError()) }
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
        DispatchQueue.main.async { delegate.onSignInCompleted(result: account) }
    }

    private func handleSignInChallengeResponse(
        _ validatedResponse: MSALNativeAuthSignInChallengeValidatedResponse,
        context: MSALNativeAuthRequestContext,
        scopes: [String],
        codeRequiredMethod: ((SignInCodeRequiredState, String, MSALNativeAuthChannelType, Int) -> Void)?) -> SignInPasswordStartError? {
        switch validatedResponse {
        case .passwordRequired:
            MSALLogger.log(
                level: .error,
                context: context,
                format: "SignIn with password: unexpected password required result")
                return SignInPasswordStartError(type: .generalError)
        case .error(let challengeError):
            return challengeError.convertToSignInPasswordStartError()
        case .codeRequired(let credentialToken, let sentTo, let channelType, let codeLength):
            let state = SignInCodeRequiredState(scopes: scopes, controller: self, flowToken: credentialToken)
            if let codeRequiredMethod = codeRequiredMethod {
                DispatchQueue.main.async { codeRequiredMethod(state, sentTo, channelType, codeLength) }
                return nil
            } else {
                return SignInPasswordStartError(type: .generalError, message: "Implementation of onSignInCodeRequired required")
            }
        }
    }

    private func handleSignInChallengeResponse(
        _ validatedResponse: MSALNativeAuthSignInChallengeValidatedResponse,
        context: MSALNativeAuthRequestContext,
        username: String,
        telemetryEvent: MSIDTelemetryAPIEvent?,
        scopes: [String],
        delegate: SignInCodeStartDelegate) {
            switch validatedResponse {
            case .passwordRequired(let credentialToken):
                DispatchQueue.main.async {
                    if let passwordRequiredMethod = delegate.onSignInPasswordRequired {
                        self.stopTelemetryEvent(telemetryEvent, context: context)
                        passwordRequiredMethod(SignInPasswordRequiredState(
                            scopes: scopes,
                            username: username,
                            controller: self,
                            flowToken: credentialToken)
                        )
                    } else {
                        self.stopTelemetryEvent(telemetryEvent, context: context, error: MSALNativeAuthGenericError())
                        delegate.onSignInCodeError(
                            error: SignInCodeStartError(type: .generalError, message: "Implementation of onSignInPasswordRequired required"))
                    }
                }
            case .error(let challengeError):
                DispatchQueue.main.async { delegate.onSignInCodeError(error: challengeError.convertToSignInCodeStartError()) }
                stopTelemetryEvent(telemetryEvent, context: context, error: MSALNativeAuthGenericError())
            case .codeRequired(let credentialToken, let sentTo, let channelType, let codeLength):
                let state = SignInCodeRequiredState(scopes: scopes, controller: self, flowToken: credentialToken)
                DispatchQueue.main.async {
                    delegate.onSignInCodeRequired(newState: state, sentTo: sentTo, channelTargetType: channelType, codeLength: codeLength)
                }
                stopTelemetryEvent(telemetryEvent, context: context)
            }
    }

    private func performAndValidateTokenRequest(
        _ request: MSIDHttpRequest,
        config: MSIDConfiguration,
        context: MSALNativeAuthRequestContext) async -> MSALNativeAuthSignInTokenValidatedResponse {
        let aadTokenResponse: Result<MSIDAADTokenResponse, Error> = await performTokenRequest(request, context: context)
        return responseValidator.validate(
            context: context,
            msidConfiguration: config,
            result: aadTokenResponse
        )
    }

    private func performAndValidateChallengeRequest(
        credentialToken: String,
        telemetryEvent: MSIDTelemetryAPIEvent?,
        context: MSALNativeAuthRequestContext) async -> MSALNativeAuthSignInChallengeValidatedResponse {
            guard let challengeRequest = createChallengeRequest(credentialToken: credentialToken, context: context) else {
                MSALLogger.log(level: .error, context: context, format: "SignIn ResendCode: Cannot create Challenge request object")
                return .error(.invalidRequest)
            }
            let challengeResponse: Result<MSALNativeAuthSignInChallengeResponse, Error> =
            await performRequest(challengeRequest, context: context)
            return responseValidator.validate(context: context, result: challengeResponse)
    }

    private func createTokenRequest(
        username: String? = nil,
        password: String? = nil,
        scopes: [String],
        credentialToken: String? = nil,
        oobCode: String? = nil,
        grantType: MSALNativeAuthGrantType,
        addNcaFlag: Bool = false,
        includeChallengeType: Bool = true,
        context: MSIDRequestContext) -> MSIDHttpRequest? {
        do {
            let params = MSALNativeAuthSignInTokenRequestParameters(
                context: context,
                username: username,
                credentialToken: credentialToken,
                signInSLT: nil,
                grantType: grantType,
                scope: scopes.joined(separator: " "),
                password: password,
                oobCode: oobCode,
                addNcaFlag: addNcaFlag,
                includeChallengeType: includeChallengeType)
            return try requestProvider.token(parameters: params, context: context)
        } catch {
            MSALLogger.log(level: .error, context: context, format: "Error creating SignIn Token Request: \(error)")
            return nil
        }
    }

    private func createInitiateRequest(username: String, context: MSIDRequestContext) -> MSIDHttpRequest? {
        let params = MSALNativeAuthSignInInitiateRequestParameters(context: context, username: username)
        do {
            return try requestProvider.inititate(parameters: params, context: context)
        } catch {
            MSALLogger.log(level: .error, context: context, format: "Error creating SignIn Initiate Request: \(error)")
            return nil
        }
    }

    private func createChallengeRequest(
        credentialToken: String,
        context: MSIDRequestContext
    ) -> MSIDHttpRequest? {
        do {
            let params = MSALNativeAuthSignInChallengeRequestParameters(
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

    private func performTokenRequest(_ request: MSIDHttpRequest, context: MSIDRequestContext) async -> Result<MSIDAADTokenResponse, Error> {
        return await withCheckedContinuation { continuation in
            request.send { response, error in
                if let error = error {
                    continuation.resume(returning: .failure(error))
                    return
                }
                guard let responseDict = response as? [AnyHashable: Any] else {
                    continuation.resume(returning: .failure(MSALNativeAuthError.invalidResponse))
                    return
                }
                do {
                    let tokenResponse = try MSIDAADTokenResponse(jsonDictionary: responseDict)
                    tokenResponse.correlationId = request.context?.correlationId().uuidString
                    continuation.resume(returning: .success(tokenResponse))
                } catch {
                    MSALLogger.log(level: .error, context: context, format: "Error request - Both result and error are nil")
                    continuation.resume(returning: .failure(MSALNativeAuthError.invalidResponse))
                }
            }
        }
    }
}
