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

    convenience init(config: MSALNativeAuthConfiguration, cacheAccessor: MSALNativeAuthCacheInterface) {
        let factory = MSALNativeAuthResultFactory(config: config, cacheAccessor: cacheAccessor)
        self.init(
            clientId: config.clientId,
            signInRequestProvider: MSALNativeAuthSignInRequestProvider(
                requestConfigurator: MSALNativeAuthRequestConfigurator(config: config)),
            tokenRequestProvider: MSALNativeAuthTokenRequestProvider(
                requestConfigurator: MSALNativeAuthRequestConfigurator(config: config)),
            cacheAccessor: cacheAccessor,
            factory: factory,
            signInResponseValidator: MSALNativeAuthSignInResponseValidator(),
            tokenResponseValidator: MSALNativeAuthTokenResponseValidator(
                factory: factory,
                msidValidator: MSIDTokenResponseValidator())
        )
    }

    // MARK: - Internal

    func signIn(params: MSALNativeAuthSignInParameters) async -> SignInControllerResponse {
        let eventId: MSALNativeAuthTelemetryApiId =
        params.password == nil ? .telemetryApiIdSignInWithCodeStart : .telemetryApiIdSignInWithPasswordStart
        MSALLogger.log(level: .info, context: params.context, format: "SignIn started")
        let telemetryInfo = TelemetryInfo(
            event: makeAndStartTelemetryEvent(id: eventId, context: params.context),
            context: params.context
        )

        let initiateValidatedResponse = await performAndValidateSignInInitiate(username: params.username, telemetryInfo: telemetryInfo)
        let result = await handleInitiateResponse(initiateValidatedResponse, telemetryInfo: telemetryInfo)

        switch result {
        case .success(let challengeValidatedResponse):
            return await handleChallengeResponse(challengeValidatedResponse, params: params, telemetryInfo: telemetryInfo)
        case .failure(let error):
            return .init(
                .error(error.convertToSignInStartError(correlationId: params.context.correlationId())),
                correlationId: params.context.correlationId()
            )
        }
    }

    func signIn(
        username: String,
        continuationToken: String?,
        scopes: [String]?,
        context: MSALNativeAuthRequestContext
    ) async -> SignInAfterPreviousFlowControllerResponse {
        MSALLogger.log(level: .info, context: context, format: "SignIn after previous flow started")
        let telemetryInfo = TelemetryInfo(
            event: makeAndStartTelemetryEvent(id: .telemetryApiIdSignInAfterSignUp, context: context),
            context: context
        )
        guard let continuationToken = continuationToken else {
            MSALLogger.log(level: .error, context: context, format: "SignIn after previous flow not available because continuationToken is nil")
            let error = SignInAfterSignUpError(message: MSALNativeAuthErrorMessage.signInNotAvailable, correlationId: context.correlationId())
            stopTelemetryEvent(telemetryInfo, error: error)
            return .init(.failure(error), correlationId: context.correlationId())
        }
        let scopes = joinScopes(scopes)
        guard let request = createTokenRequest(
            username: username,
            scopes: scopes,
            continuationToken: continuationToken,
            grantType: .continuationToken,
            context: context
        ) else {
            let error = SignInAfterSignUpError(correlationId: context.correlationId())
            stopTelemetryEvent(telemetryInfo, error: error)
            return .init(.failure(error), correlationId: context.correlationId())
        }
        let config = factory.makeMSIDConfiguration(scopes: scopes)
        let response = await performAndValidateTokenRequest(request, config: config, context: context)

        return await withCheckedContinuation { continuation in
            handleTokenResponse(
                response,
                scopes: scopes,
                telemetryInfo: telemetryInfo,
                onSuccess: { accountResult in
                    continuation.resume(
                        returning: .init(.success(accountResult), correlationId: context.correlationId(), telemetryUpdate: { [weak self] result in
                        self?.stopTelemetryEvent(telemetryInfo.event, context: context, delegateDispatcherResult: result)
                    }))
                },
                onError: { error in
                    let error = SignInAfterSignUpError(
                        message: error.errorDescription,
                        correlationId: error.correlationId,
                        errorCodes: error.errorCodes,
                        errorUri: error.errorUri
                    )
                    continuation.resume(returning: .init(.failure(error), correlationId: context.correlationId()))
                }
            )
        }
    }

    // swiftlint:disable:next function_body_length
    func submitCode(
        _ code: String,
        continuationToken: String,
        context: MSALNativeAuthRequestContext,
        scopes: [String]
    ) async -> SignInSubmitCodeControllerResponse {
        let telemetryInfo = TelemetryInfo(
            event: makeAndStartTelemetryEvent(id: .telemetryApiIdSignInSubmitCode, context: context),
            context: context
        )
        guard let request = createTokenRequest(
            scopes: scopes,
            continuationToken: continuationToken,
            oobCode: code,
            grantType: .oobCode,
            includeChallengeType: false,
            context: context) else {
            MSALLogger.log(level: .error, context: context, format: "SignIn, submit code: unable to create token request")

            return processSubmitCodeFailure(
                errorType: .generalError(nil),
                telemetryInfo: telemetryInfo,
                scopes: scopes,
                continuationToken: continuationToken,
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
                        continuation.resume(
                            returning: .init(
                                .completed(accountResult),
                                correlationId: context.correlationId(),
                                telemetryUpdate: { [weak self] result in
                            self?.stopTelemetryEvent(telemetryInfo.event, context: context, delegateDispatcherResult: result)
                        }))
                    },
                    onError: { [weak self] error in
                        MSALLogger.log(level: .error, context: context, format: "SignIn submit code, token request failed with error \(error)")
                        guard let self = self else { return }
                        continuation.resume(returning: self.processSubmitCodeFailure(
                            errorType: .generalError(nil),
                            telemetryInfo: telemetryInfo,
                            scopes: scopes,
                            continuationToken: continuationToken,
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
                continuationToken: continuationToken,
                context: context
            )
        }
    }

    // swiftlint:disable:next function_body_length
    func submitPassword(
        _ password: String,
        username: String,
        continuationToken: String,
        context: MSALNativeAuthRequestContext,
        scopes: [String]
    ) async -> SignInSubmitPasswordControllerResponse {
        let telemetryInfo = TelemetryInfo(
            event: makeAndStartTelemetryEvent(id: .telemetryApiIdSignInSubmitPassword, context: context),
            context: context
        )
        guard let request = createTokenRequest(
            username: username,
            password: password,
            scopes: scopes,
            continuationToken: continuationToken,
            grantType: .password,
            context: context) else {
            MSALLogger.log(level: .error, context: context, format: "SignIn, submit password: unable to create token request")
            return processSubmitPasswordFailure(
                errorType: .generalError(nil),
                telemetryInfo: telemetryInfo,
                username: username,
                continuationToken: continuationToken,
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
                        continuation.resume(
                            returning: .init(
                                .completed(accountResult),
                                correlationId: context.correlationId(),
                                telemetryUpdate: { [weak self] result in
                            self?.stopTelemetryEvent(telemetryInfo.event, context: context, delegateDispatcherResult: result)
                        }))
                    },
                    onError: { [weak self] error in
                        MSALLogger.log(level: .error, context: context, format: "SignIn submit password, token request failed with error \(error)")
                        guard let self = self else { return }
                        continuation.resume(returning: self.processSubmitPasswordFailure(
                            errorType: .generalError(nil),
                            telemetryInfo: telemetryInfo,
                            username: username,
                            continuationToken: continuationToken,
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
                continuationToken: continuationToken,
                scopes: scopes
            )
        }
    }

    func resendCode(
        continuationToken: String,
        context: MSALNativeAuthRequestContext,
        scopes: [String]
    ) async -> SignInResendCodeControllerResponse {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdSignInResendCode, context: context)
        let result = await performAndValidateChallengeRequest(continuationToken: continuationToken, context: context)
        switch result {
        case .passwordRequired:
            let error = ResendCodeError(correlationId: context.correlationId())
            MSALLogger.log(level: .error, context: context, format: "SignIn ResendCode: received unexpected password required API result")
            stopTelemetryEvent(event, context: context, error: error)
            return .init(.error(error: error, newState: nil), correlationId: context.correlationId())
        case .error(let challengeError):
            let error = challengeError.convertToResendCodeError(correlationId: context.correlationId())
            MSALLogger.log(level: .error, context: context, format: "SignIn ResendCode: received challenge error response: \(challengeError)")
            stopTelemetryEvent(event, context: context, error: error)
            return .init(.error(
                error: error,
                newState: SignInCodeRequiredState(
                    scopes: scopes,
                    controller: self,
                    continuationToken: continuationToken,
                    correlationId: context.correlationId())
            ), correlationId: context.correlationId())
        case .codeRequired(let newContinuationToken, let sentTo, let channelType, let codeLength):
            let state = SignInCodeRequiredState(
                scopes: scopes,
                controller: self,
                continuationToken: newContinuationToken,
                correlationId: context.correlationId()
            )
            return .init(
                .codeRequired(
                    newState: state,
                    sentTo: sentTo,
                    channelTargetType: channelType,
                    codeLength: codeLength
                ),
                correlationId: context.correlationId(),
                telemetryUpdate: { [weak self] result in
                    self?.stopTelemetryEvent(event, context: context, delegateDispatcherResult: result)
                })
        }
    }

    // MARK: - Private

    private func processSubmitCodeFailure(
        errorType: MSALNativeAuthTokenValidatedErrorType,
        telemetryInfo: TelemetryInfo,
        scopes: [String],
        continuationToken: String,
        context: MSALNativeAuthRequestContext
    ) -> SignInSubmitCodeControllerResponse {
        MSALLogger.log(
            level: .error,
            context: context,
            format: "SignIn completed with errorType: \(errorType)")
        stopTelemetryEvent(telemetryInfo, error: errorType)
        let state = SignInCodeRequiredState(
            scopes: scopes,
            controller: self,
            continuationToken: continuationToken,
            correlationId: context.correlationId()
        )
        return .init(
            .error(error: errorType.convertToVerifyCodeError(correlationId: context.correlationId()), newState: state),
            correlationId: context.correlationId()
        )
    }

    private func processSubmitPasswordFailure(
        errorType: MSALNativeAuthTokenValidatedErrorType,
        telemetryInfo: TelemetryInfo,
        username: String,
        continuationToken: String,
        scopes: [String]
    ) -> SignInSubmitPasswordControllerResponse {
        MSALLogger.log(
            level: .error,
            context: telemetryInfo.context,
            format: "SignIn with username and password completed with errorType: \(errorType)")
        stopTelemetryEvent(telemetryInfo, error: errorType)
        let state = SignInPasswordRequiredState(
            scopes: scopes,
            username: username,
            controller: self,
            continuationToken: continuationToken,
            correlationId: telemetryInfo.context.correlationId()
        )
        return .init(
            .error(error: errorType.convertToPasswordRequiredError(correlationId: telemetryInfo.context.correlationId()), newState: state),
            correlationId: telemetryInfo.context.correlationId()
        )
    }

    private func performAndValidateSignInInitiate(
        username: String,
        telemetryInfo: TelemetryInfo
    ) async -> MSALNativeAuthSignInInitiateValidatedResponse {
        guard let request = createInitiateRequest(username: username, context: telemetryInfo.context) else {
            let errorDescription = "SignIn Initiate: Cannot create Initiate request object"
            MSALLogger.log(level: .error, context: telemetryInfo.context, format: errorDescription)
            let error = MSALNativeAuthSignInInitiateValidatedErrorType.invalidRequest(.init(errorDescription: errorDescription))
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
        case .success(let continuationToken):
            let challengeValidatedResponse = await performAndValidateChallengeRequest(
                continuationToken: continuationToken,
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
        onError: @escaping (SignInStartError) -> Void
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
            let error = errorType.convertToSignInPasswordStartError(correlationId: telemetryInfo.context.correlationId())
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
        onError: @escaping (SignInStartError) -> Void
    ) {
        do {
            let tokenResult = try cacheTokenResponse(tokenResponse, context: context, msidConfiguration: config)

            if let userAccountResult = factory.makeUserAccountResult(tokenResult: tokenResult, context: context) {
                MSALLogger.log(level: .info, context: context, format: "SignIn completed successfully")
                telemetryInfo.event?.setUserInformation(tokenResult.account)
                stopTelemetryEvent(telemetryInfo)
                onSuccess(userAccountResult)
            } else {
                let errorType = MSALNativeAuthTokenValidatedErrorType.generalError(nil)
                MSALLogger.log(level: .error, context: telemetryInfo.context, format: "SignIn completed with error. Error creating UserAccountResult")
                stopTelemetryEvent(telemetryInfo, error: errorType)
                onError(errorType.convertToSignInPasswordStartError(correlationId: telemetryInfo.context.correlationId()))
            }
        } catch {
            let errorType = MSALNativeAuthTokenValidatedErrorType.generalError(nil)
            MSALLogger.log(level: .error, context: telemetryInfo.context, format: "SignIn completed with error \(error)")
            stopTelemetryEvent(telemetryInfo, error: errorType)
            onError(errorType.convertToSignInPasswordStartError(correlationId: telemetryInfo.context.correlationId()))
        }
    }

    // swiftlint:disable:next function_body_length
    private func handleChallengeResponse(
        _ validatedResponse: MSALNativeAuthSignInChallengeValidatedResponse,
        params: MSALNativeAuthSignInParameters,
        telemetryInfo: TelemetryInfo
    ) async -> SignInControllerResponse {
        let scopes = joinScopes(params.scopes)
        let isSignInUsingPassword = params.password != nil
        switch validatedResponse {
        case .passwordRequired(let continuationToken):
            if isSignInUsingPassword {
                guard let request = createTokenRequest(
                    username: params.username,
                    password: params.password,
                    scopes: scopes,
                    continuationToken: continuationToken,
                    grantType: .password,
                    context: telemetryInfo.context
                ) else {
                    stopTelemetryEvent(telemetryInfo, error: MSALNativeAuthInternalError.invalidRequest)
                    return .init(
                        .error(SignInStartError(type: .generalError, correlationId: telemetryInfo.context.correlationId())),
                        correlationId: telemetryInfo.context.correlationId()
                    )
                }

                let config = factory.makeMSIDConfiguration(scopes: scopes)
                let response = await performAndValidateTokenRequest(request, config: config, context: telemetryInfo.context)

                return await withCheckedContinuation { continuation in
                    handleTokenResponse(response,
                        scopes: scopes,
                        telemetryInfo: telemetryInfo,
                        onSuccess: { accountResult in
                        continuation.resume(returning: SignInControllerResponse(.completed(accountResult),
                                                                                correlationId: telemetryInfo.context.correlationId(),
                                                                                telemetryUpdate: { [weak self] result in
                            self?.stopTelemetryEvent(telemetryInfo.event, context: telemetryInfo.context, delegateDispatcherResult: result)
                        }))
                        },
                        onError: { error in
                            continuation.resume(
                                returning: SignInControllerResponse(.error(error), correlationId: telemetryInfo.context.correlationId())
                            )
                        }
                    )
                }
            } else {
                let state = SignInPasswordRequiredState(
                    scopes: scopes,
                    username: params.username,
                    controller: self,
                    continuationToken: continuationToken,
                    correlationId: params.context.correlationId()
                )

                return .init(
                    .passwordRequired(newState: state),
                    correlationId: telemetryInfo.context.correlationId(),
                    telemetryUpdate: { [weak self] result in
                    self?.stopTelemetryEvent(telemetryInfo.event, context: telemetryInfo.context, delegateDispatcherResult: result)
                })
            }
        case .codeRequired(let continuationToken, let sentTo, let channelType, let codeLength):
            if isSignInUsingPassword {
                MSALLogger.log(level: .warning, context: telemetryInfo.context, format: MSALNativeAuthErrorMessage.codeRequiredForPasswordUserLog)
            }
            let state = SignInCodeRequiredState(scopes: scopes,
                                                controller: self,
                                                continuationToken: continuationToken,
                                                correlationId: params.context.correlationId())
            return .init(
                .codeRequired(
                    newState: state,
                    sentTo: sentTo,
                    channelTargetType: channelType,
                    codeLength: codeLength
                ),
                correlationId: telemetryInfo.context.correlationId(),
                telemetryUpdate: { [weak self] result in
                    self?.stopTelemetryEvent(telemetryInfo.event, context: telemetryInfo.context, delegateDispatcherResult: result)
                })
        case .error(let challengeError):
            let error = challengeError.convertToSignInStartError(correlationId: telemetryInfo.context.correlationId())
            MSALLogger.log(level: .error,
                           context: telemetryInfo.context,
                           format: "SignIn, completed with error: \(error.errorDescription ?? "No error description")")
            stopTelemetryEvent(telemetryInfo, error: error)
            return .init(.error(error), correlationId: telemetryInfo.context.correlationId())
        }
    }

    private func performAndValidateChallengeRequest(
        continuationToken: String,
        context: MSALNativeAuthRequestContext
    ) async -> MSALNativeAuthSignInChallengeValidatedResponse {
        guard let challengeRequest = createChallengeRequest(continuationToken: continuationToken, context: context) else {
            let errorDescription = "SignIn ResendCode: Cannot create Challenge request object"
            MSALLogger.log(level: .error, context: context, format: errorDescription)
            return .error(.invalidRequest(.init(errorDescription: errorDescription)))
        }
        let challengeResponse: Result<MSALNativeAuthSignInChallengeResponse, Error> = await performRequest(challengeRequest, context: context)
        return signInResponseValidator.validate(context: context, result: challengeResponse)
    }

    private func createInitiateRequest(username: String, context: MSALNativeAuthRequestContext) -> MSIDHttpRequest? {
        let params = MSALNativeAuthSignInInitiateRequestParameters(context: context, username: username)
        do {
            return try signInRequestProvider.inititate(parameters: params, context: context)
        } catch {
            MSALLogger.log(level: .error, context: context, format: "Error creating SignIn Initiate Request: \(error)")
            return nil
        }
    }

    private func createChallengeRequest(
        continuationToken: String,
        context: MSALNativeAuthRequestContext
    ) -> MSIDHttpRequest? {
        do {
            let params = MSALNativeAuthSignInChallengeRequestParameters(
                context: context,
                continuationToken: continuationToken
            )
            return try signInRequestProvider.challenge(parameters: params, context: context)
        } catch {
            MSALLogger.log(level: .error, context: context, format: "Error creating SignIn Challenge Request: \(error)")
            return nil
        }
    }
}
