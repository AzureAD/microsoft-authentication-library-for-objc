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
final class MSALNativeAuthSignInController: MSALNativeAuthTokenController, MSALNativeAuthSignInControlling {

    // MARK: - Variables

    private let signInRequestProvider: MSALNativeAuthSignInRequestProviding
    private let signInResponseValidator: MSALNativeAuthSignInResponseValidating

    // MARK: - Init

    init(
        clientId: String,
        signInRequestProvider: MSALNativeAuthSignInRequestProviding,
        tokenRequestProvider: MSALNativeAuthTokenRequestProviding,
        cacheAccessor: MSALNativeAuthCacheInterface,
        factory: MSALNativeAuthResultBuildable,
        signInResponseValidator: MSALNativeAuthSignInResponseValidating,
        tokenResponseValidator: MSALNativeAuthTokenResponseValidating
    ) {
        self.signInRequestProvider = signInRequestProvider
        self.signInResponseValidator = signInResponseValidator
        super.init(
            clientId: clientId,
            requestProvider: tokenRequestProvider,
            cacheAccessor: cacheAccessor,
            factory: factory,
            responseValidator: tokenResponseValidator
        )
    }

    convenience init(config: MSALNativeAuthConfiguration) {
        let factory = MSALNativeAuthResultFactory(config: config)
        self.init(
            clientId: config.clientId,
            signInRequestProvider: MSALNativeAuthSignInRequestProvider(
                requestConfigurator: MSALNativeAuthRequestConfigurator(config: config)),
            tokenRequestProvider: MSALNativeAuthTokenRequestProvider(
                requestConfigurator: MSALNativeAuthRequestConfigurator(config: config)),
            cacheAccessor: MSALNativeAuthCacheAccessor(),
            factory: factory,
            signInResponseValidator: MSALNativeAuthSignInResponseValidator(),
            tokenResponseValidator: MSALNativeAuthTokenResponseValidator(
                factory: factory,
                msidValidator: MSIDTokenResponseValidator())
        )
    }

    // MARK: - Internal

    func signIn(params: MSALNativeAuthSignInWithPasswordParameters, delegate: SignInPasswordStartDelegate) async {
        MSALLogger.log(level: .verbose, context: params.context, format: "SignIn with username and password started")
        let telemetryInfo = TelemetryInfo(
            event: makeAndStartTelemetryEvent(id: .telemetryApiIdSignInWithPasswordStart, context: params.context),
            context: params.context
        )

        let validatedResponse = await performAndValidateSignInInitiate(username: params.username, telemetryInfo: telemetryInfo)

        await handleInitiateResponse(
            validatedResponse,
            telemetryInfo: telemetryInfo,
            onSuccess: { [weak self] challengeValidatedResponse in
                guard let self = self else {
                    MSALLogger.log(level: .error, context: params.context, format: "sign-in controller nil")
                    return DispatchQueue.main.async { delegate.onSignInPasswordError(error: .init(type: .generalError)) }
                }
                await self.handleChallengeResponse(challengeValidatedResponse, params: params, telemetryInfo: telemetryInfo, delegate: delegate)
            },
            onError: { error in
                DispatchQueue.main.async { delegate.onSignInPasswordError(error: error.convertToSignInPasswordStartError()) }
            }
        )
    }

    func signIn(params: MSALNativeAuthSignInWithCodeParameters, delegate: SignInStartDelegate) async {
        MSALLogger.log(level: .verbose, context: params.context, format: "SignIn started")
        let telemetryInfo = TelemetryInfo(
            event: makeAndStartTelemetryEvent(id: .telemetryApiIdSignInWithCodeStart, context: params.context),
            context: params.context
        )

        let validatedResponse = await performAndValidateSignInInitiate(username: params.username, telemetryInfo: telemetryInfo)

        await handleInitiateResponse(
            validatedResponse,
            telemetryInfo: telemetryInfo,
            onSuccess: { [weak self] challengeValidatedResponse in
                guard let self = self else {
                    MSALLogger.log(level: .error, context: params.context, format: "sign-in controller nil")
                    return DispatchQueue.main.async { delegate.onSignInError(error: .init(type: .generalError)) }
                }
                self.handleChallengeResponse(challengeValidatedResponse, params: params, telemetryInfo: telemetryInfo, delegate: delegate)
            },
            onError: { error in
                DispatchQueue.main.async { delegate.onSignInError(error: error.convertToSignInStartError()) }
            }
        )
    }

    func signIn(username: String, slt: String?, scopes: [String]?, context: MSALNativeAuthRequestContext, delegate: SignInAfterSignUpDelegate) async {
        MSALLogger.log(level: .verbose, context: context, format: "SignIn after signUp started")
        let telemetryInfo = TelemetryInfo(
            event: makeAndStartTelemetryEvent(id: .telemetryApiIdSignInAfterSignUp, context: context),
            context: context
        )
        guard let slt = slt else {
            MSALLogger.log(level: .error, context: context, format: "SignIn not available because SLT is nil")
            let error = SignInAfterSignUpError(message: MSALNativeAuthErrorMessage.signInNotAvailable)
            stopTelemetryEvent(telemetryInfo, error: error)
            DispatchQueue.main.async { delegate.onSignInAfterSignUpError(error: error) }
            return
        }
        let scopes = joinScopes(scopes)
        guard let request = createTokenRequest(
            username: username,
            scopes: scopes,
            signInSLT: slt,
            grantType: .slt,
            context: context
        ) else {
            let error = SignInAfterSignUpError()
            stopTelemetryEvent(telemetryInfo, error: error)
            DispatchQueue.main.async { delegate.onSignInAfterSignUpError(error: error) }
            return
        }
        let config = factory.makeMSIDConfiguration(scopes: scopes)
        let response = await performAndValidateTokenRequest(request, config: config, context: context)
        handleTokenResponse(
            response,
            scopes: scopes,
            telemetryInfo: telemetryInfo,
            onSuccess: delegate.onSignInCompleted,
            onError: { passwordRequiredError in
                delegate.onSignInAfterSignUpError(error: SignInAfterSignUpError(message: passwordRequiredError.errorDescription))
            }
        )
    }

    func submitCode(
        _ code: String,
        credentialToken: String,
        context: MSALNativeAuthRequestContext,
        scopes: [String],
        delegate: SignInVerifyCodeDelegate) async {
            let telemetryInfo = TelemetryInfo(
                event: makeAndStartTelemetryEvent(id: .telemetryApiIdSignInSubmitCode, context: context),
                context: context
            )
            guard let request = createTokenRequest(
                scopes: scopes,
                credentialToken: credentialToken,
                oobCode: code,
                grantType: .oobCode,
                includeChallengeType: false,
                context: context) else {
                MSALLogger.log(level: .error, context: context, format: "SignIn, submit code: unable to create token request")
                failSubmitCode(errorType: .generalError,
                               telemetryInfo: telemetryInfo,
                               scopes: scopes,
                               credentialToken: credentialToken,
                               context: context,
                               delegate: delegate)
                return
            }
            let config = factory.makeMSIDConfiguration(scopes: scopes)
            let response = await performAndValidateTokenRequest(request, config: config, context: context)
            switch response {
            case .success(let tokenResponse):
                do {
                    try handleMSIDTokenResponse(tokenResponse: tokenResponse,
                                                context: context,
                                                telemetryInfo: telemetryInfo,
                                                config: config,
                                                onSuccess: delegate.onSignInCompleted)

                } catch {
                    MSALLogger.log(
                        level: .error,
                        context: context,
                        format: "SignIn submit code, token request failed with error \(error)")
                    failSubmitCode(errorType: .generalError,
                                   telemetryInfo: telemetryInfo,
                                   scopes: scopes,
                                   credentialToken: credentialToken,
                                   context: context,
                                   delegate: delegate)
                }
            case .error(let errorType):
                failSubmitCode(errorType: errorType,
                               telemetryInfo: telemetryInfo,
                               scopes: scopes,
                               credentialToken: credentialToken,
                               context: context,
                               delegate: delegate)
            }
        }

    func failSubmitCode(
        errorType: MSALNativeAuthTokenValidatedErrorType,
        telemetryInfo: TelemetryInfo,
        scopes: [String],
        credentialToken: String,
        context: MSALNativeAuthRequestContext,
        delegate: SignInVerifyCodeDelegate
    ) {
        MSALLogger.log(
            level: .error,
            context: context,
            format: "SignIn completed with errorType: \(errorType)")
        stopTelemetryEvent(telemetryInfo, error: errorType)
        DispatchQueue.main.async {
            delegate.onSignInVerifyCodeError(
                error: errorType.convertToVerifyCodeError(),
                newState: SignInCodeRequiredState(scopes: scopes, controller: self, flowToken: credentialToken))
        }
    }

    func submitPassword(
        _ password: String,
        username: String,
        credentialToken: String,
        context: MSALNativeAuthRequestContext,
        scopes: [String],
        delegate: SignInPasswordRequiredDelegate) async {
            let telemetryInfo = TelemetryInfo(
                event: makeAndStartTelemetryEvent(id: .telemetryApiIdSignInSubmitPassword, context: context),
                context: context
            )
            guard let request = createTokenRequest(
                username: username,
                password: password,
                scopes: scopes,
                credentialToken: credentialToken,
                grantType: .password,
                context: context) else {
                MSALLogger.log(level: .error, context: context, format: "SignIn, submit password: unable to create token request")
                failSubmitPassword(errorType: .generalError,
                                   telemetryInfo: telemetryInfo,
                                   username: username,
                                   credentialToken: credentialToken,
                                   scopes: scopes,
                                   delegate: delegate)
                return
            }
            let config = factory.makeMSIDConfiguration(scopes: scopes)
            let response = await performAndValidateTokenRequest(request, config: config, context: context)
            switch response {
            case .success(let tokenResponse):
                do {
                    try handleMSIDTokenResponse(tokenResponse: tokenResponse,
                                                context: context,
                                                telemetryInfo: telemetryInfo,
                                                config: config,
                                                onSuccess: delegate.onSignInCompleted)
                } catch {
                    MSALLogger.log(
                        level: .error,
                        context: context,
                        format: "SignIn submit password, token request failed with error \(error)")
                    failSubmitPassword(errorType: .generalError,
                                       telemetryInfo: telemetryInfo,
                                       username: username,
                                       credentialToken: credentialToken,
                                       scopes: scopes,
                                       delegate: delegate)
                }
            case .error(let errorType):
                failSubmitPassword(errorType: errorType,
                                   telemetryInfo: telemetryInfo,
                                   username: username,
                                   credentialToken: credentialToken,
                                   scopes: scopes,
                                   delegate: delegate)
            }
        }

    func failSubmitPassword(
        errorType: MSALNativeAuthTokenValidatedErrorType,
        telemetryInfo: TelemetryInfo,
        username: String,
        credentialToken: String,
        scopes: [String],
        delegate: SignInPasswordRequiredDelegate
    ) {
        MSALLogger.log(
            level: .error,
            context: telemetryInfo.context,
            format: "SignIn with username and password completed with errorType: \(errorType)")
        stopTelemetryEvent(telemetryInfo, error: errorType)
        DispatchQueue.main.async {
            delegate.onSignInPasswordRequiredError(
                error: errorType.convertToPasswordRequiredError(),
                newState: SignInPasswordRequiredState(scopes: scopes, username: username, controller: self, flowToken: credentialToken))
        }
    }

    func resendCode(credentialToken: String, context: MSALNativeAuthRequestContext, scopes: [String], delegate: SignInResendCodeDelegate) async {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdSignInResendCode, context: context)
        let result = await performAndValidateChallengeRequest(credentialToken: credentialToken, context: context)
        var error: MSALNativeAuthError?
        switch result {
        case .passwordRequired:
            error = ResendCodeError()
            MSALLogger.log(level: .error, context: context, format: "SignIn ResendCode: received unexpected password required API result")
            DispatchQueue.main.async { delegate.onSignInResendCodeError(error: ResendCodeError(), newState: nil) }
        case .error(let challengeError):
            error = ResendCodeError()
            MSALLogger.log(level: .error, context: context, format: "SignIn ResendCode: received challenge error response: \(challengeError)")
            DispatchQueue.main.async {
                delegate.onSignInResendCodeError(
                    error: ResendCodeError(),
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

    private func performAndValidateSignInInitiate(
        username: String,
        telemetryInfo: TelemetryInfo
    ) async -> MSALNativeAuthSignInInitiateValidatedResponse {
        guard let request = createInitiateRequest(username: username, context: telemetryInfo.context) else {
            let error = MSALNativeAuthSignInInitiateValidatedErrorType.invalidRequest(message: nil)
            stopTelemetryEvent(telemetryInfo, error: error)
            return .error(error)
        }

        let initiateResponse: Result<MSALNativeAuthSignInInitiateResponse, Error> = await performRequest(request, context: telemetryInfo.context)
        let validatedResponse = signInResponseValidator.validate(context: telemetryInfo.context, result: initiateResponse)

        return validatedResponse
    }

    private func handleInitiateResponse(
        _ validatedResponse: MSALNativeAuthSignInInitiateValidatedResponse,
        telemetryInfo: TelemetryInfo,
        onSuccess: @escaping (_ response: MSALNativeAuthSignInChallengeValidatedResponse) async -> Void,
        onError: @escaping (MSALNativeAuthSignInInitiateValidatedErrorType) -> Void
    ) async {
        switch validatedResponse {
        case .success(let credentialToken):
            let challengeValidatedResponse = await performAndValidateChallengeRequest(
                credentialToken: credentialToken,
                context: telemetryInfo.context
            )
            await onSuccess(challengeValidatedResponse)
        case .error(let error):
            MSALLogger.log(level: .error, context: telemetryInfo.context, format: "SignIn: an error occurred after calling /initiate API: \(error)")
            stopTelemetryEvent(telemetryInfo, error: error)
            onError(error)
        }
    }

    private func handleTokenResponse(
        _ response: MSALNativeAuthTokenValidatedResponse,
        scopes: [String],
        telemetryInfo: TelemetryInfo,
        onSuccess: @escaping (MSALNativeAuthUserAccountResult) -> Void,
        onError: @escaping (SignInPasswordStartError) -> Void) {
            let config = factory.makeMSIDConfiguration(scopes: scopes)
            switch response {
            case .success(let tokenResponse):
                do {
                    try handleMSIDTokenResponse(tokenResponse: tokenResponse,
                                                context: telemetryInfo.context,
                                                telemetryInfo: telemetryInfo,
                                                config: config,
                                                onSuccess: onSuccess)
                } catch {
                    let errorType = MSALNativeAuthTokenValidatedErrorType.generalError
                    MSALLogger.log(
                        level: .error,
                        context: telemetryInfo.context,
                        format: "SignIn completed with error: \(error)")
                    stopTelemetryEvent(telemetryInfo, error: errorType)
                    DispatchQueue.main.async { onError(errorType.convertToSignInPasswordStartError()) }
                }
            case .error(let errorType):
                let error = errorType.convertToSignInPasswordStartError()
                MSALLogger.log(level: .error,
                               context: telemetryInfo.context,
                               format: "SignIn completed with errorType: \(error.errorDescription ?? "No error description")")
                stopTelemetryEvent(telemetryInfo, error: error)
                DispatchQueue.main.async { onError(error) }
            }
        }

    private func handleMSIDTokenResponse(
        tokenResponse: MSIDTokenResponse,
        context: MSALNativeAuthRequestContext,
        telemetryInfo: TelemetryInfo,
        config: MSIDConfiguration,
        onSuccess: @escaping (MSALNativeAuthUserAccountResult) -> Void) throws {
            let tokenResult = try cacheTokenResponse(tokenResponse, context: context, msidConfiguration: config)
            guard let userAccountResult = factory.makeUserAccountResult(tokenResult: tokenResult, context: context) else {
                MSALLogger.log(
                    level: .error,
                    context: context,
                    format: "User account result could not be created")
                throw MSALNativeAuthInternalError.generalError
            }

            handleTokenResponseSuccess(result: tokenResult,
                                       userAccountResult: userAccountResult,
                                       telemetryInfo: telemetryInfo,
                                       context: context,
                                       onSuccess: onSuccess)
        }

    private func handleTokenResponseSuccess(
        result: MSIDTokenResult,
        userAccountResult: MSALNativeAuthUserAccountResult,
        telemetryInfo: TelemetryInfo,
        context: MSALNativeAuthRequestContext,
        onSuccess: @escaping (MSALNativeAuthUserAccountResult) -> Void) {
        telemetryInfo.event?.setUserInformation(result.account)
        stopTelemetryEvent(telemetryInfo)
        MSALLogger.log(
            level: .verbose,
            context: context,
            format: "SignIn completed successfully")
        DispatchQueue.main.async { onSuccess(userAccountResult) }
    }

    private func handleChallengeResponse(
        _ validatedResponse: MSALNativeAuthSignInChallengeValidatedResponse,
        params: MSALNativeAuthSignInWithCodeParameters,
        telemetryInfo: TelemetryInfo,
        delegate: SignInStartDelegate
    ) {
        let scopes = joinScopes(params.scopes)

        switch validatedResponse {
        case .passwordRequired(let credentialToken):
            if let passwordRequiredMethod = delegate.onSignInPasswordRequired {
                MSALLogger.log(level: .verbose, context: telemetryInfo.context, format: "SignIn, password required")
                stopTelemetryEvent(telemetryInfo)
                DispatchQueue.main.async {
                    passwordRequiredMethod(SignInPasswordRequiredState(
                        scopes: scopes,
                        username: params.username,
                        controller: self,
                        flowToken: credentialToken)
                    )
                }
            } else {
                MSALLogger.log(level: .error, context: telemetryInfo.context, format: "SignIn, implementation of onSignInPasswordRequired required")
                let error = SignInStartError(type: .generalError, message: MSALNativeAuthErrorMessage.passwordRequiredNotImplemented)
                stopTelemetryEvent(telemetryInfo, error: error)
                DispatchQueue.main.async { delegate.onSignInError(error: error)}
            }
        case .codeRequired(let credentialToken, let sentTo, let channelType, let codeLength):
            let state = SignInCodeRequiredState(scopes: scopes, controller: self, flowToken: credentialToken)
            stopTelemetryEvent(telemetryInfo)
            DispatchQueue.main.async {
                delegate.onSignInCodeRequired(newState: state, sentTo: sentTo, channelTargetType: channelType, codeLength: codeLength)
            }
        case .error(let challengeError):
            let error = challengeError.convertToSignInStartError()
            MSALLogger.log(level: .error,
                           context: telemetryInfo.context,
                           format: "SignIn, completed with error: \(error.errorDescription ?? "No error description")")
            stopTelemetryEvent(telemetryInfo, error: error)
            DispatchQueue.main.async { delegate.onSignInError(error: error) }
        }
    }

    private func handleChallengeResponse(
        _ validatedResponse: MSALNativeAuthSignInChallengeValidatedResponse,
        params: MSALNativeAuthSignInWithPasswordParameters,
        telemetryInfo: TelemetryInfo,
        delegate: SignInPasswordStartDelegate
    ) async {
        let scopes = joinScopes(params.scopes)

        switch validatedResponse {
        case .codeRequired(let credentialToken, let sentTo, let channelType, let codeLength):
            MSALLogger.log(level: .warning, context: telemetryInfo.context, format: MSALNativeAuthErrorMessage.codeRequiredForPasswordUserLog)

            if let codeRequiredMethod = delegate.onSignInCodeRequired {
                stopTelemetryEvent(telemetryInfo)
                let state = SignInCodeRequiredState(scopes: scopes, controller: self, flowToken: credentialToken)
                DispatchQueue.main.async { codeRequiredMethod(state, sentTo, channelType, codeLength) }
            } else {
                MSALLogger.log(level: .error, context: telemetryInfo.context, format: "SignIn, implementation of onSignInCodeRequired required")
                let error = SignInPasswordStartError(type: .generalError, message: MSALNativeAuthErrorMessage.codeRequiredNotImplemented)
                stopTelemetryEvent(telemetryInfo, error: error)
                DispatchQueue.main.async { delegate.onSignInPasswordError(error: error) }
            }
        case .passwordRequired(let credentialToken):
            guard let request = createTokenRequest(
                username: params.username,
                password: params.password,
                scopes: scopes,
                credentialToken: credentialToken,
                grantType: .password,
                context: telemetryInfo.context
            ) else {
                stopTelemetryEvent(telemetryInfo, error: MSALNativeAuthInternalError.invalidRequest)
                DispatchQueue.main.async { delegate.onSignInPasswordError(error: SignInPasswordStartError(type: .generalError)) }
                return
            }

            let config = factory.makeMSIDConfiguration(scopes: scopes)
            let response = await performAndValidateTokenRequest(request, config: config, context: telemetryInfo.context)

            handleTokenResponse(
                response,
                scopes: scopes,
                telemetryInfo: telemetryInfo,
                onSuccess: delegate.onSignInCompleted,
                onError: delegate.onSignInPasswordError
            )
        case .error(let challengeError):
            let error = challengeError.convertToSignInPasswordStartError()
            MSALLogger.log(level: .error,
                           context: telemetryInfo.context,
                           format: "SignIn, completed with error: \(error.errorDescription ?? "No error description")")
            stopTelemetryEvent(telemetryInfo, error: error)
            DispatchQueue.main.async { delegate.onSignInPasswordError(error: error) }
        }
    }

    private func performAndValidateChallengeRequest(
        credentialToken: String,
        context: MSALNativeAuthRequestContext
    ) async -> MSALNativeAuthSignInChallengeValidatedResponse {
        guard let challengeRequest = createChallengeRequest(credentialToken: credentialToken, context: context) else {
            MSALLogger.log(level: .error, context: context, format: "SignIn ResendCode: Cannot create Challenge request object")
            return .error(.invalidRequest(message: nil))
        }
        let challengeResponse: Result<MSALNativeAuthSignInChallengeResponse, Error> = await performRequest(challengeRequest, context: context)
        return signInResponseValidator.validate(context: context, result: challengeResponse)
    }

    private func createInitiateRequest(username: String, context: MSIDRequestContext) -> MSIDHttpRequest? {
        let params = MSALNativeAuthSignInInitiateRequestParameters(context: context, username: username)
        do {
            return try signInRequestProvider.inititate(parameters: params, context: context)
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
            return try signInRequestProvider.challenge(parameters: params, context: context)
        } catch {
            MSALLogger.log(level: .error, context: context, format: "Error creating SignIn Challenge Request: \(error)")
            return nil
        }
    }
}
