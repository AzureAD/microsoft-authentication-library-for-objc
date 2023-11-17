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

    func signIn(params: MSALNativeAuthSignInWithPasswordParameters) async -> SignInPasswordControllerResponse {
        MSALLogger.log(level: .verbose, context: params.context, format: "SignIn with username and password started")
        let telemetryInfo = TelemetryInfo(
            event: makeAndStartTelemetryEvent(id: .telemetryApiIdSignInWithPasswordStart, context: params.context),
            context: params.context
        )

        let initiateValidatedResponse = await performAndValidateSignInInitiate(username: params.username, telemetryInfo: telemetryInfo)
        let result = await handleInitiateResponse(initiateValidatedResponse, telemetryInfo: telemetryInfo)

        switch result {
        case .success(let challengeValidatedResponse):
            return await handleChallengeResponse(challengeValidatedResponse, params: params, telemetryInfo: telemetryInfo)
        case .failure(let error):
            return .init(.error(error.convertToSignInPasswordStartError()))
        }
    }

    func signIn(params: MSALNativeAuthSignInWithCodeParameters) async -> SignInCodeControllerResponse {
        MSALLogger.log(level: .verbose, context: params.context, format: "SignIn started")
        let telemetryInfo = TelemetryInfo(
            event: makeAndStartTelemetryEvent(id: .telemetryApiIdSignInWithCodeStart, context: params.context),
            context: params.context
        )

        let initiateValidatedResponse = await performAndValidateSignInInitiate(username: params.username, telemetryInfo: telemetryInfo)
        let result = await handleInitiateResponse(initiateValidatedResponse, telemetryInfo: telemetryInfo)

        switch result {
        case .success(let challengeValidatedResponse):
            return await handleChallengeResponse(challengeValidatedResponse, params: params, telemetryInfo: telemetryInfo)
        case .failure(let error):
            return .init(.error(error.convertToSignInStartError()))
        }
    }

    func signIn(
        username: String,
        slt: String?,
        scopes: [String]?,
        context: MSALNativeAuthRequestContext
    ) async -> Result<MSALNativeAuthUserAccountResult, SignInAfterSignUpError> {
        MSALLogger.log(level: .verbose, context: context, format: "SignIn after signUp started")
        let telemetryInfo = TelemetryInfo(
            event: makeAndStartTelemetryEvent(id: .telemetryApiIdSignInAfterSignUp, context: context),
            context: context
        )
        guard let slt = slt else {
            MSALLogger.log(level: .error, context: context, format: "SignIn not available because SLT is nil")
            let error = SignInAfterSignUpError(message: MSALNativeAuthErrorMessage.signInNotAvailable)
            stopTelemetryEvent(telemetryInfo, error: error)
            return .failure(error)
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
            return .failure(error)
        }
        let config = factory.makeMSIDConfiguration(scopes: scopes)
        let response = await performAndValidateTokenRequest(request, config: config, context: context)

        return await withCheckedContinuation { continuation in
            handleTokenResponse(
                response,
                scopes: scopes,
                telemetryInfo: telemetryInfo,
                onSuccess: { accountResult in
                    continuation.resume(returning: .success(accountResult))
                },
                onError: { error in
                    continuation.resume(returning: .failure(SignInAfterSignUpError(message: error.errorDescription)))
                }
            )
        }
    }

    // swiftlint:disable:next function_body_length
    func submitCode(
        _ code: String,
        credentialToken: String,
        context: MSALNativeAuthRequestContext,
        scopes: [String]
    ) async -> SignInVerifyCodeResult {
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

            return processSubmitCodeFailure(
                errorType: .generalError,
                telemetryInfo: telemetryInfo,
                scopes: scopes,
                credentialToken: credentialToken,
                context: context
            )
        }
        let config = factory.makeMSIDConfiguration(scopes: scopes)
        let response = await performAndValidateTokenRequest(request, config: config, context: context)
        switch response {
        case .success(let tokenResponse):
            return await withCheckedContinuation { continuation in
                handleMSIDTokenResponse(
                    tokenResponse: tokenResponse,
                    context: context,
                    telemetryInfo: telemetryInfo,
                    config: config,
                    onSuccess: { accountResult in
                        continuation.resume(returning: .completed(accountResult))
                    },
                    onError: { [weak self] error in
                        MSALLogger.log(level: .error, context: context, format: "SignIn submit code, token request failed with error \(error)")
                        guard let self = self else { return }
                        continuation.resume(returning: self.processSubmitCodeFailure(
                            errorType: .generalError,
                            telemetryInfo: telemetryInfo,
                            scopes: scopes,
                            credentialToken: credentialToken,
                            context: context
                        ))
                    }
                )
            }
        case .error(let errorType):
            return processSubmitCodeFailure(
                errorType: errorType,
                telemetryInfo: telemetryInfo,
                scopes: scopes,
                credentialToken: credentialToken,
                context: context
            )
        }
    }

    // swiftlint:disable:next function_body_length
    func submitPassword(
        _ password: String,
        username: String,
        credentialToken: String,
        context: MSALNativeAuthRequestContext,
        scopes: [String]
    ) async -> SignInPasswordRequiredResult {
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
            return processSubmitPasswordFailure(
                errorType: .generalError,
                telemetryInfo: telemetryInfo,
                username: username,
                credentialToken: credentialToken,
                scopes: scopes
            )
        }
        let config = factory.makeMSIDConfiguration(scopes: scopes)
        let response = await performAndValidateTokenRequest(request, config: config, context: context)
        switch response {
        case .success(let tokenResponse):
            return await withCheckedContinuation { continuation in
                handleMSIDTokenResponse(
                    tokenResponse: tokenResponse,
                    context: context,
                    telemetryInfo: telemetryInfo,
                    config: config,
                    onSuccess: { accountResult in
                        continuation.resume(returning: .completed(accountResult))
                    },
                    onError: { [weak self] error in
                        MSALLogger.log(level: .error, context: context, format: "SignIn submit password, token request failed with error \(error)")
                        guard let self = self else { return }
                        continuation.resume(returning: self.processSubmitPasswordFailure(
                            errorType: .generalError,
                            telemetryInfo: telemetryInfo,
                            username: username,
                            credentialToken: credentialToken,
                            scopes: scopes
                        ))
                    }
                )
            }

        case .error(let errorType):
            return processSubmitPasswordFailure(
                errorType: errorType,
                telemetryInfo: telemetryInfo,
                username: username,
                credentialToken: credentialToken,
                scopes: scopes
            )
        }
    }

    func resendCode(
        credentialToken: String,
        context: MSALNativeAuthRequestContext,
        scopes: [String]
    ) async -> SignInResendCodeResult {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdSignInResendCode, context: context)
        let result = await performAndValidateChallengeRequest(credentialToken: credentialToken, context: context)
        switch result {
        case .passwordRequired:
            let error = ResendCodeError()
            MSALLogger.log(level: .error, context: context, format: "SignIn ResendCode: received unexpected password required API result")
            stopTelemetryEvent(event, context: context, error: error)
            return .error(error: error, newState: nil)
        case .error(let challengeError):
            let error = ResendCodeError()
            MSALLogger.log(level: .error, context: context, format: "SignIn ResendCode: received challenge error response: \(challengeError)")
            stopTelemetryEvent(event, context: context, error: error)
            return .error(error: error, newState: SignInCodeRequiredState(scopes: scopes, controller: self, flowToken: credentialToken, correlationId: context.correlationId()))
        case .codeRequired(let credentialToken, let sentTo, let channelType, let codeLength):
            let state = SignInCodeRequiredState(scopes: scopes, controller: self, flowToken: credentialToken, correlationId: context.correlationId())
            stopTelemetryEvent(event, context: context)
            return .codeRequired(newState: state, sentTo: sentTo, channelTargetType: channelType, codeLength: codeLength)
        }
    }

    // MARK: - Private

    private func processSubmitCodeFailure(
        errorType: MSALNativeAuthTokenValidatedErrorType,
        telemetryInfo: TelemetryInfo,
        scopes: [String],
        credentialToken: String,
        context: MSALNativeAuthRequestContext
    ) -> SignInVerifyCodeResult {
        MSALLogger.log(
            level: .error,
            context: context,
            format: "SignIn completed with errorType: \(errorType)")
        stopTelemetryEvent(telemetryInfo, error: errorType)
        let state = SignInCodeRequiredState(scopes: scopes, controller: self, flowToken: credentialToken, correlationId: context.correlationId())
        return .error(error: errorType.convertToVerifyCodeError(), newState: state)
    }

    private func processSubmitPasswordFailure(
        errorType: MSALNativeAuthTokenValidatedErrorType,
        telemetryInfo: TelemetryInfo,
        username: String,
        credentialToken: String,
        scopes: [String]
    ) -> SignInPasswordRequiredResult {
        MSALLogger.log(
            level: .error,
            context: telemetryInfo.context,
            format: "SignIn with username and password completed with errorType: \(errorType)")
        stopTelemetryEvent(telemetryInfo, error: errorType)
        let state = SignInPasswordRequiredState(scopes: scopes, username: username, controller: self, flowToken: credentialToken, correlationId: telemetryInfo.context.correlationId())
        return .error(error: errorType.convertToPasswordRequiredError(), newState: state)
    }

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
        telemetryInfo: TelemetryInfo
    ) async -> Result<MSALNativeAuthSignInChallengeValidatedResponse, MSALNativeAuthSignInInitiateValidatedErrorType> {
        switch validatedResponse {
        case .success(let credentialToken):
            let challengeValidatedResponse = await performAndValidateChallengeRequest(
                credentialToken: credentialToken,
                context: telemetryInfo.context
            )
            return .success(challengeValidatedResponse)
        case .error(let error):
            MSALLogger.log(level: .error, context: telemetryInfo.context, format: "SignIn: an error occurred after calling /initiate API: \(error)")
            stopTelemetryEvent(telemetryInfo, error: error)
            return .failure(error)
        }
    }

    private func handleTokenResponse(
        _ response: MSALNativeAuthTokenValidatedResponse,
        scopes: [String],
        telemetryInfo: TelemetryInfo,
        onSuccess: @escaping (MSALNativeAuthUserAccountResult) -> Void,
        onError: @escaping (SignInPasswordStartError) -> Void
    ) {
        let config = factory.makeMSIDConfiguration(scopes: scopes)
        switch response {
        case .success(let tokenResponse):
            return handleMSIDTokenResponse(
                tokenResponse: tokenResponse,
                context: telemetryInfo.context,
                telemetryInfo: telemetryInfo,
                config: config,
                onSuccess: onSuccess,
                onError: onError
            )
        case .error(let errorType):
            let error = errorType.convertToSignInPasswordStartError()
            MSALLogger.log(level: .error,
                           context: telemetryInfo.context,
                           format: "SignIn completed with errorType: \(error.errorDescription ?? "No error description")")
            stopTelemetryEvent(telemetryInfo, error: error)
            onError(error)
        }
    }

    private func handleMSIDTokenResponse(
        tokenResponse: MSIDTokenResponse,
        context: MSALNativeAuthRequestContext,
        telemetryInfo: TelemetryInfo,
        config: MSIDConfiguration,
        onSuccess: @escaping (MSALNativeAuthUserAccountResult) -> Void,
        onError: @escaping (SignInPasswordStartError) -> Void
    ) {
        do {
            let tokenResult = try cacheTokenResponse(tokenResponse, context: context, msidConfiguration: config)

            if let userAccountResult = factory.makeUserAccountResult(tokenResult: tokenResult, context: context) {
                MSALLogger.log(level: .verbose, context: context, format: "SignIn completed successfully")
                telemetryInfo.event?.setUserInformation(tokenResult.account)
                stopTelemetryEvent(telemetryInfo)
                onSuccess(userAccountResult)
            } else {
                let errorType = MSALNativeAuthTokenValidatedErrorType.generalError
                MSALLogger.log(level: .error, context: telemetryInfo.context, format: "SignIn completed with error. Error creating UserAccountResult")
                stopTelemetryEvent(telemetryInfo, error: errorType)
                onError(errorType.convertToSignInPasswordStartError())
            }
        } catch {
            let errorType = MSALNativeAuthTokenValidatedErrorType.generalError
            MSALLogger.log(level: .error, context: telemetryInfo.context, format: "SignIn completed with error \(error)")
            stopTelemetryEvent(telemetryInfo, error: errorType)
            onError(errorType.convertToSignInPasswordStartError())
        }
    }

    private func handleChallengeResponse(
        _ validatedResponse: MSALNativeAuthSignInChallengeValidatedResponse,
        params: MSALNativeAuthSignInWithCodeParameters,
        telemetryInfo: TelemetryInfo
    ) async -> SignInCodeControllerResponse {
        let scopes = joinScopes(params.scopes)

        switch validatedResponse {
        case .passwordRequired(let credentialToken):
            let state = SignInPasswordRequiredState(
                scopes: scopes,
                username: params.username,
                controller: self,
                flowToken: credentialToken,
                correlationId: params.context.correlationId()
            )

            return .init(.passwordRequired(newState: state), telemetryUpdate: { [weak self] result in
                switch result {
                case .success:
                    MSALLogger.log(level: .verbose, context: telemetryInfo.context, format: "SignIn, password required")
                    self?.stopTelemetryEvent(telemetryInfo)
                case .failure(let error):
                    MSALLogger.log(
                        level: .error,
                        context: telemetryInfo.context,
                        format: "SignIn error: \(error.errorDescription ?? "No error description")"
                    )
                    self?.stopTelemetryEvent(telemetryInfo, error: error)
                }
            })
        case .codeRequired(let credentialToken, let sentTo, let channelType, let codeLength):
            let state = SignInCodeRequiredState(scopes: scopes, controller: self, flowToken: credentialToken, correlationId: params.context.correlationId())
            stopTelemetryEvent(telemetryInfo)
            return .init(.codeRequired(newState: state, sentTo: sentTo, channelTargetType: channelType, codeLength: codeLength))
        case .error(let challengeError):
            let error = challengeError.convertToSignInStartError()
            MSALLogger.log(level: .error,
                           context: telemetryInfo.context,
                           format: "SignIn, completed with error: \(error.errorDescription ?? "No error description")")
            stopTelemetryEvent(telemetryInfo, error: error)
            return .init(.error(error))
        }
    }

    // swiftlint:disable:next function_body_length
    private func handleChallengeResponse(
        _ validatedResponse: MSALNativeAuthSignInChallengeValidatedResponse,
        params: MSALNativeAuthSignInWithPasswordParameters,
        telemetryInfo: TelemetryInfo
    ) async -> SignInPasswordControllerResponse {
        let scopes = joinScopes(params.scopes)

        switch validatedResponse {
        case .codeRequired(let credentialToken, let sentTo, let channelType, let codeLength):
            MSALLogger.log(level: .warning, context: telemetryInfo.context, format: MSALNativeAuthErrorMessage.codeRequiredForPasswordUserLog)
            let result: SignInPasswordStartResult = .codeRequired(
                newState: SignInCodeRequiredState(scopes: scopes, controller: self, flowToken: credentialToken, correlationId: params.context.correlationId()),
                sentTo: sentTo,
                channelTargetType: channelType,
                codeLength: codeLength
            )

            return .init(result, telemetryUpdate: { [weak self] result in
                switch result {
                case .success:
                    self?.stopTelemetryEvent(telemetryInfo)
                case .failure(let error):
                    MSALLogger.log(
                        level: .error,
                        context: telemetryInfo.context,
                        format: "SignIn error \(error.errorDescription ?? "No error description")"
                    )
                    self?.stopTelemetryEvent(telemetryInfo, error: error)
                }
            })
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
                return .init(.error(SignInPasswordStartError(type: .generalError)))
            }

            let config = factory.makeMSIDConfiguration(scopes: scopes)
            let response = await performAndValidateTokenRequest(request, config: config, context: telemetryInfo.context)

            return await withCheckedContinuation { continuation in
                handleTokenResponse(response,
                    scopes: scopes,
                    telemetryInfo: telemetryInfo,
                    onSuccess: { accountResult in
                        continuation.resume(returning: SignInPasswordControllerResponse(.completed(accountResult)))
                    },
                    onError: { error in
                        continuation.resume(returning: SignInPasswordControllerResponse(.error(error)))
                    }
                )
            }
        case .error(let challengeError):
            let error = challengeError.convertToSignInPasswordStartError()
            MSALLogger.log(level: .error,
                           context: telemetryInfo.context,
                           format: "SignIn, completed with error: \(error.errorDescription ?? "No error description")")
            stopTelemetryEvent(telemetryInfo, error: error)
            return .init(.error(error))
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
