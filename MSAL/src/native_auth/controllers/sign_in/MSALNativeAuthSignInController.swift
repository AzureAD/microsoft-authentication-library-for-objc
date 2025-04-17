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
final class MSALNativeAuthSignInController: MSALNativeAuthTokenController, MSALNativeAuthSignInControlling, MSALNativeAuthMFAControlling {

    // MARK: - Variables

    private let signInRequestProvider: MSALNativeAuthSignInRequestProviding
    private let signInResponseValidator: MSALNativeAuthSignInResponseValidating
    private let nativeAuthConfig: MSALNativeAuthConfiguration
    // MARK: - Init

    init(
        clientId: String,
        signInRequestProvider: MSALNativeAuthSignInRequestProviding,
        tokenRequestProvider: MSALNativeAuthTokenRequestProviding,
        cacheAccessor: MSALNativeAuthCacheInterface,
        factory: MSALNativeAuthResultBuildable,
        signInResponseValidator: MSALNativeAuthSignInResponseValidating,
        tokenResponseValidator: MSALNativeAuthTokenResponseValidating,
        nativeAuthConfig: MSALNativeAuthConfiguration
    ) {
        self.signInRequestProvider = signInRequestProvider
        self.signInResponseValidator = signInResponseValidator
        self.nativeAuthConfig = nativeAuthConfig
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
                msidValidator: MSIDTokenResponseValidator()),
            nativeAuthConfig: config
        )
    }

    // MARK: - Internal

    func signIn(params: MSALNativeAuthInternalSignInParameters) async -> SignInControllerResponse {
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

    // swiftlint:disable:next function_body_length
    func signIn(
        username: String?,
        grantType: MSALNativeAuthGrantType?,
        continuationToken: String?,
        scopes: [String]?,
        claimsRequestJson: String?,
        telemetryId: MSALNativeAuthTelemetryApiId,
        context: MSALNativeAuthRequestContext
    ) async -> SignInAfterPreviousFlowControllerResponse {
        MSALLogger.log(level: .info, context: context, format: "SignIn after previous flow started")
        let telemetryInfo = TelemetryInfo(
            event: makeAndStartTelemetryEvent(id: telemetryId, context: context),
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
            claimsRequestJson: claimsRequestJson,
            context: context
        ) else {
            let error = SignInAfterSignUpError(correlationId: context.correlationId())
            stopTelemetryEvent(telemetryInfo, error: error)
            return .init(.failure(error), correlationId: context.correlationId())
        }
        let response = await performAndValidateTokenRequest(request, context: context)
        let result = await handleTokenResponse(response,
                                               scopes: scopes,
                                               claimsRequestJson: claimsRequestJson,
                                               telemetryInfo: telemetryInfo)
        switch result {
        case .success(let accountResult):
        return .init(.success(accountResult), correlationId: context.correlationId(), telemetryUpdate: { [weak self] result in
                            self?.stopTelemetryEvent(telemetryInfo.event, context: context, delegateDispatcherResult: result)
                        })
        case .awaitingMFA(_):
                    let error = SignInAfterSignUpError(correlationId: context.correlationId())
                    MSALLogger.log(level: .error, context: context, format: "SignIn: received unexpected MFA required API result")
                    self.stopTelemetryEvent(telemetryInfo.event, context: context, error: error)
            return .init(.failure(error), correlationId: context.correlationId())
        case .jITAuthMethodsSelectionRequired(_, _):
                    let error = SignInAfterSignUpError(correlationId: context.correlationId())
                    MSALLogger.log(level: .error, context: context, format: "SignIn: received unexpected JIT required API result")
                    self.stopTelemetryEvent(telemetryInfo.event, context: context, error: error)
                    return .init(.failure(error), correlationId: context.correlationId())
        case .error(let error):
            let error = SignInAfterSignUpError(
                        message: error.errorDescription,
                        correlationId: error.correlationId,
                        errorCodes: error.errorCodes,
                        errorUri: error.errorUri
                    )
                    return .init(.failure(error), correlationId: context.correlationId())
        }
    }

    func submitCode(
        _ code: String,
        continuationToken: String,
        context: MSALNativeAuthRequestContext,
        scopes: [String],
        claimsRequestJson: String?
    ) async -> SignInSubmitCodeControllerResponse {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdSignInSubmitCode, context: context)
        return await submitCode(
            code,
            continuationToken: continuationToken,
            context: context,
            scopes: scopes,
            telemetryEvent: event,
            claimsRequestJson: claimsRequestJson
        )
    }

    // swiftlint:disable:next function_body_length
    func submitPassword(
        _ password: String,
        username: String,
        continuationToken: String,
        context: MSALNativeAuthRequestContext,
        scopes: [String],
        claimsRequestJson: String?
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
            claimsRequestJson: claimsRequestJson,
            context: context) else {
            MSALLogger.log(level: .error, context: context, format: "SignIn, submit password: unable to create token request")
            return processSubmitPasswordFailure(
                errorType: .generalError(nil),
                telemetryInfo: telemetryInfo,
                username: username,
                continuationToken: continuationToken,
                scopes: scopes,
                claimsRequestJson: claimsRequestJson
            )
        }
        let config = factory.makeMSIDConfiguration(scopes: scopes)
        let response = await performAndValidateTokenRequest(request, context: context)
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
                        MSALLogger.logPII(
                            level: .error,
                            context: context,
                            format: "SignIn submit password, token request failed with error \(MSALLogMask.maskPII(error.errorDescription))"
                        )
                        guard let self = self else { return }
                        continuation.resume(returning: self.processSubmitPasswordFailure(
                            errorType: .generalError(nil),
                            telemetryInfo: telemetryInfo,
                            username: username,
                            continuationToken: continuationToken,
                            scopes: scopes,
                            claimsRequestJson: claimsRequestJson
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
                scopes: scopes,
                claimsRequestJson: claimsRequestJson
            )
        case .strongAuthRequired(let newContinuationToken):
            MSALLogger.log(level: .info, context: context, format: "Strong authentication required.")
            let state = AwaitingMFAState(
                controller: self,
                scopes: scopes,
                claimsRequestJson: claimsRequestJson,
                continuationToken: newContinuationToken,
                correlationId: context.correlationId()
            )
            return .init(
                .awaitingMFA(newState: state),
                correlationId: context.correlationId(),
                telemetryUpdate: { [weak self] result in
                    self?.stopTelemetryEvent(telemetryInfo.event, context: context, delegateDispatcherResult: result)
                })
        case.jitRequired(continuationToken: let newContinuationToken):
            MSALLogger.log(level: .info, context: context, format: "JIT required.")
            let jitController = createJITController()
            let jitIntrospectResponse = await jitController.getJITAuthMethods(continuationToken: newContinuationToken, context: context)
            switch jitIntrospectResponse.result {
            case .selectionRequired(let authMethods, let newState):
                return .init(
                    .jitAuthMethodsSelectionRequired(authMethods: authMethods, newState: newState),
                    correlationId: context.correlationId(),
                    telemetryUpdate: { [weak self] result in
                        self?.stopTelemetryEvent(telemetryInfo.event, context: context, delegateDispatcherResult: result)
                    })
            case .error(let error):
                return .init(
                    .error(error: error.convertToPasswordRequiredError(correlationId: telemetryInfo.context.correlationId()), newState: nil),
                    correlationId: telemetryInfo.context.correlationId()
                )
            }
        }
    }

    // swiftlint:disable:next function_body_length
    func resendCode(
        continuationToken: String,
        context: MSALNativeAuthRequestContext,
        scopes: [String],
        claimsRequestJson: String?
    ) async -> SignInResendCodeControllerResponse {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdSignInResendCode, context: context)
        let result = await performAndValidateChallengeRequest(
            continuationToken: continuationToken,
            context: context,
            logErrorMessage: "SignIn ResendCode: cannot create challenge request object"
        )
        switch result {
        case .passwordRequired:
            let error = ResendCodeError(correlationId: context.correlationId())
            MSALLogger.log(level: .error, context: context, format: "SignIn ResendCode: received unexpected password required API result")
            stopTelemetryEvent(event, context: context, error: error)
            return .init(.error(error: error, newState: nil), correlationId: context.correlationId())
        case .error(let challengeError):
            let error = challengeError.convertToResendCodeError(correlationId: context.correlationId())
            MSALLogger.logPII(
                level: .error,
                context: context,
                format: "SignIn ResendCode: received challenge error response: \(MSALLogMask.maskPII(error.errorDescription))"
            )
            stopTelemetryEvent(event, context: context, error: error)
            return .init(.error(
                error: error,
                newState: SignInCodeRequiredState(
                    scopes: scopes,
                    controller: self,
                    claimsRequestJson: claimsRequestJson,
                    continuationToken: continuationToken,
                    correlationId: context.correlationId())
            ), correlationId: context.correlationId())
        case .codeRequired(let newContinuationToken, let sentTo, let channelType, let codeLength):
            let state = SignInCodeRequiredState(
                scopes: scopes,
                controller: self,
                claimsRequestJson: claimsRequestJson,
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
        case .introspectRequired:
            let error = ResendCodeError(correlationId: context.correlationId())
            MSALLogger.log(level: .error, context: context, format: "ResendCode: received unexpected introspect required API result")
            self.stopTelemetryEvent(event, context: context, error: error)
            return .init(.error(error: error, newState: nil), correlationId: context.correlationId())
        }
    }

    // swiftlint:disable:next function_body_length
    func requestChallenge(
        continuationToken: String,
        authMethod: MSALAuthMethod?,
        context: MSALNativeAuthRequestContext,
        scopes: [String],
        claimsRequestJson: String?
    ) async -> MFARequestChallengeControllerResponse {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdMFARequestChallenge, context: context)
        let result = await performAndValidateChallengeRequest(
            continuationToken: continuationToken,
            context: context,
            logErrorMessage: "MFA RequestChallenge: cannot create challenge request object",
            mfaAuthMethodId: authMethod?.id
        )
        switch result {
        case .passwordRequired:
            let error = MFARequestChallengeError(type: .generalError, correlationId: context.correlationId())
            MSALLogger.log(level: .error, context: context, format: "MFA request challenge: received unexpected password required API result")
            stopTelemetryEvent(event, context: context, error: error)
            return .init(.error(error: error, newState: nil), correlationId: context.correlationId())
        case .error(let challengeError):
            let error = challengeError.convertToMFARequestChallengeError(correlationId: context.correlationId())
            MSALLogger.logPII(
                level: .error,
                context: context,
                format: "MFA request challenge: received challenge error response: \(MSALLogMask.maskPII(error.errorDescription))"
            )
            stopTelemetryEvent(event, context: context, error: error)
            return .init(.error(
                error: error,
                newState: MFARequiredState(
                    controller: self,
                    scopes: scopes,
                    claimsRequestJson: claimsRequestJson,
                    continuationToken: continuationToken,
                    correlationId: context.correlationId()
                )
            ), correlationId: context.correlationId())
        case .codeRequired(let newContinuationToken, let sentTo, let channelType, let codeLength):
            let state = MFARequiredState(
                controller: self,
                scopes: scopes,
                claimsRequestJson: claimsRequestJson,
                continuationToken: newContinuationToken,
                correlationId: context.correlationId()
            )
            return .init(
                .verificationRequired(
                    sentTo: sentTo,
                    channelTargetType: channelType,
                    codeLength: codeLength,
                    newState: state
                ),
                correlationId: context.correlationId(),
                telemetryUpdate: { [weak self] result in
                    self?.stopTelemetryEvent(event, context: context, delegateDispatcherResult: result)
                })
        case .introspectRequired:
            let telemetryInfo = TelemetryInfo(event: event, context: context)
            let response = await performAndValidateIntrospectRequest(continuationToken: continuationToken, context: context)
            let introspectResponse = handleIntrospectResponse(
                response, scopes: scopes,
                telemetryInfo: telemetryInfo,
                continuationToken: continuationToken,
                claimsRequestJson: claimsRequestJson
            )
            switch introspectResponse.result {
            case .selectionRequired(let authMethods, let newState):
                return .init(.selectionRequired(
                    authMethods: authMethods,
                    newState: newState),
                             correlationId: introspectResponse.correlationId,
                             telemetryUpdate: { [weak self] result in
                    self?.stopTelemetryEvent(telemetryInfo.event, context: telemetryInfo.context, delegateDispatcherResult: result)
                })
            case .error(let error, let newState):
                let mfaRequestChallengeError = error.toMFARequestChallengeError()
                return .init(.error(error: mfaRequestChallengeError, newState: newState), correlationId: introspectResponse.correlationId)
            }
        }
    }

    func getAuthMethods(
        continuationToken: String,
        context: MSALNativeAuthRequestContext,
        scopes: [String],
        claimsRequestJson: String?
    ) async -> MFAGetAuthMethodsControllerResponse {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdMFAGetAuthMethods, context: context)
        let result = await performAndValidateIntrospectRequest(continuationToken: continuationToken, context: context)
        let telemetryInfo = TelemetryInfo(event: event, context: context)
        return handleIntrospectResponse(
            result,
            scopes: scopes,
            telemetryInfo: telemetryInfo,
            continuationToken: continuationToken,
            claimsRequestJson: claimsRequestJson
        )
    }

    func submitChallenge(
        challenge: String,
        continuationToken: String,
        context: MSALNativeAuthRequestContext,
        scopes: [String],
        claimsRequestJson: String?
    ) async -> MFASubmitChallengeControllerResponse {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdMFASubmitChallenge, context: context)
        let response = await submitCode(
            challenge,
            continuationToken: continuationToken,
            context: context,
            scopes: scopes,
            telemetryEvent: event,
            claimsRequestJson: claimsRequestJson
        )
        switch response.result {
        case .completed(let accountResult):
            return .init(
                .completed(accountResult),
                correlationId: response.correlationId,
                telemetryUpdate: { [weak self] result in
                    self?.stopTelemetryEvent(event, context: context, delegateDispatcherResult: result)
                })
        case .error(let error, let newState):
            let submitChallengeError = MFASubmitChallengeError(error: error)
            var mfaState: MFARequiredState?
            if let newState {
                mfaState = MFARequiredState(
                    controller: self,
                    scopes: newState.scopes,
                    claimsRequestJson: newState.claimsRequestJson,
                    continuationToken: newState.continuationToken,
                    correlationId: newState.correlationId
                )
            }
            return .init(.error(error: submitChallengeError, newState: mfaState), correlationId: response.correlationId)
        }
    }

    // MARK: - Private

    // swiftlint:disable:next function_body_length
    private func submitCode(
        _ code: String,
        continuationToken: String,
        context: MSALNativeAuthRequestContext,
        scopes: [String],
        telemetryEvent: MSIDTelemetryAPIEvent?,
        claimsRequestJson: String?
    ) async -> SignInSubmitCodeControllerResponse {
        let telemetryInfo = TelemetryInfo(
            event: telemetryEvent,
            context: context
        )
        guard let request = createTokenRequest(
            scopes: scopes,
            continuationToken: continuationToken,
            oobCode: code,
            grantType: .oobCode,
            includeChallengeType: false,
            claimsRequestJson: claimsRequestJson,
            context: context) else {
            MSALLogger.log(level: .error, context: context, format: "Submit code: unable to create token request")

            return processSubmitCodeFailure(
                errorType: .generalError(nil),
                telemetryInfo: telemetryInfo,
                scopes: scopes,
                claimsRequestJson: claimsRequestJson,
                continuationToken: continuationToken,
                context: context
            )
        }
        let config = factory.makeMSIDConfiguration(scopes: scopes)
        let response = await performAndValidateTokenRequest(request, context: context)
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
                        MSALLogger.logPII(
                            level: .error,
                            context: context,
                            format: "Submit code, token request failed with error \(MSALLogMask.maskPII(error.errorDescription))"
                        )
                        guard let self = self else { return }
                        continuation.resume(returning: self.processSubmitCodeFailure(
                            errorType: .generalError(nil),
                            telemetryInfo: telemetryInfo,
                            scopes: scopes,
                            claimsRequestJson: claimsRequestJson,
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
                claimsRequestJson: claimsRequestJson,
                continuationToken: continuationToken,
                context: context
            )
        case .strongAuthRequired:
            let error = VerifyCodeError(type: .generalError, correlationId: context.correlationId())
            MSALLogger.log(level: .error, context: context, format: "Submit code: received unexpected MFA required API result")
            stopTelemetryEvent(telemetryInfo.event, context: context, error: error)
            return .init(.error(error: error, newState: nil), correlationId: context.correlationId())
        case .jitRequired:
            let error = VerifyCodeError(type: .generalError, correlationId: context.correlationId())
            MSALLogger.log(level: .error, context: context, format: "Submit code: received unexpected JIT required API result")
            stopTelemetryEvent(telemetryInfo.event, context: context, error: error)
            return .init(.error(error: error, newState: nil), correlationId: context.correlationId())
        }
    }

    private func processSubmitCodeFailure(
        errorType: MSALNativeAuthTokenValidatedErrorType,
        telemetryInfo: TelemetryInfo,
        scopes: [String],
        claimsRequestJson: String?,
        continuationToken: String,
        context: MSALNativeAuthRequestContext
    ) -> SignInSubmitCodeControllerResponse {
        MSALLogger.logPII(
            level: .error,
            context: context,
            format: "SignIn completed with errorType: \(MSALLogMask.maskPII(errorType))")
        stopTelemetryEvent(telemetryInfo, error: errorType)
        let state = SignInCodeRequiredState(
            scopes: scopes,
            controller: self,
            claimsRequestJson: claimsRequestJson,
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
        scopes: [String],
        claimsRequestJson: String?
    ) -> SignInSubmitPasswordControllerResponse {
        MSALLogger.logPII(
            level: .error,
            context: telemetryInfo.context,
            format: "SignIn with username and password completed with errorType: \(MSALLogMask.maskPII(errorType))")
        stopTelemetryEvent(telemetryInfo, error: errorType)
        let state = SignInPasswordRequiredState(
            scopes: scopes,
            username: username,
            controller: self,
            claimsRequestJson: claimsRequestJson,
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
        let validatedResponse = signInResponseValidator.validateInitiate(context: telemetryInfo.context, result: initiateResponse)

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
                context: telemetryInfo.context,
                logErrorMessage: "SignIn: cannot create challenge request object"
            )
            return .success(challengeValidatedResponse)
        case .error(let error):
            MSALLogger.logPII(
                level: .error,
                context: telemetryInfo.context,
                format: "SignIn: an error occurred after calling /initiate API: \(MSALLogMask.maskPII(error))"
            )
            stopTelemetryEvent(telemetryInfo, error: error)
            return .failure(error)
        }
    }

    private func handleIntrospectResponse(
        _ response: MSALNativeAuthSignInIntrospectValidatedResponse,
        scopes: [String],
        telemetryInfo: TelemetryInfo,
        continuationToken: String,
        claimsRequestJson: String?
    ) -> MFAGetAuthMethodsControllerResponse {
        switch response {
        case .authMethodsRetrieved(let newContinuationToken, let authMethods):
            let newState = MFARequiredState(
                controller: self,
                scopes: scopes,
                claimsRequestJson: claimsRequestJson,
                continuationToken: newContinuationToken,
                correlationId: telemetryInfo.context.correlationId()
            )
            return .init(.selectionRequired(
                authMethods: authMethods.map({$0.toPublicAuthMethod()}),
                newState: newState
            ), correlationId: telemetryInfo.context.correlationId(),
                         telemetryUpdate: { [weak self] result in
                self?.stopTelemetryEvent(telemetryInfo.event, context: telemetryInfo.context, delegateDispatcherResult: result)
            })
        case .error(let error):
            MSALLogger.logPII(
                level: .error,
                context: telemetryInfo.context,
                format: "MFA: an error occurred after calling /introspect API: \(MSALLogMask.maskPII(error))"
            )
            stopTelemetryEvent(telemetryInfo, error: error)
            return .init(.error(
                error: error.convertToMFAGetAuthMethodsError(correlationId: telemetryInfo.context.correlationId()),
                newState: MFARequiredState(
                    controller: self,
                    scopes: scopes,
                    claimsRequestJson: claimsRequestJson,
                    continuationToken: continuationToken,
                    correlationId: telemetryInfo.context.correlationId()
                )
            ), correlationId: telemetryInfo.context.correlationId())
        }
    }

    enum TestTokenResult {
        case success(MSALNativeAuthUserAccountResult)
        case awaitingMFA(AwaitingMFAState)
        case jITAuthMethodsSelectionRequired([MSALAuthMethod], RegisterStrongAuthState)
        case error(SignInStartError)
    }

    private func handleTokenResponse(
        _ response: MSALNativeAuthTokenValidatedResponse,
        scopes: [String]?,
        claimsRequestJson: String?,
        telemetryInfo: TelemetryInfo
    ) async -> TestTokenResult {
        let config = factory.makeMSIDConfiguration(scopes: scopes ?? [])
        switch response {
        case .success(let tokenResponse):
            return await withCheckedContinuation { continuation in
                handleMSIDTokenResponse(
                    tokenResponse: tokenResponse,
                    context: telemetryInfo.context,
                    telemetryInfo: telemetryInfo,
                    config: config,
                    onSuccess: { accountResult in
                        continuation.resume(
                            returning: TestTokenResult.success(accountResult)
                        )},
                    onError: { error in
                        continuation.resume(returning: TestTokenResult.error(error)
                        )
                    }
                )
            }

        case .error(let errorType):
            let error = errorType.convertToSignInPasswordStartError(correlationId: telemetryInfo.context.correlationId())
            MSALLogger.logPII(level: .error,
                              context: telemetryInfo.context,
                              format: "SignIn completed with errorType: \(MSALLogMask.maskPII(error.errorDescription))")
            stopTelemetryEvent(telemetryInfo, error: error)
            return TestTokenResult.error(error)
        case .strongAuthRequired(let continuationToken):
            let state = AwaitingMFAState(
                controller: self,
                scopes: scopes ?? [],
                claimsRequestJson: claimsRequestJson,
                continuationToken: continuationToken,
                correlationId: telemetryInfo.context.correlationId()
            )
            MSALLogger.log(level: .info, context: telemetryInfo.context, format: "Multi factor authentication required")
            return TestTokenResult.awaitingMFA(state)
        case .jitRequired(let continuationToken):
            MSALLogger.log(level: .info, context: telemetryInfo.context, format: "JIT required.")
            let jitController = createJITController()
            let jitIntrospectResponse = await jitController.getJITAuthMethods(continuationToken: continuationToken,
                                                                              context: telemetryInfo.context)
            switch jitIntrospectResponse.result {
            case .selectionRequired(let authMethods, let newState):
                return TestTokenResult.jITAuthMethodsSelectionRequired(authMethods, newState)
            case .error(let errorType):
                let error = errorType.convertToSignInPasswordStartError(correlationId: telemetryInfo.context.correlationId())
                stopTelemetryEvent(telemetryInfo, error: error)
                return TestTokenResult.error(error)
            }

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
                onSuccess(userAccountResult)
            } else {
                let errorType = MSALNativeAuthTokenValidatedErrorType.generalError(nil)
                MSALLogger.log(level: .error, context: telemetryInfo.context, format: "SignIn completed with error. Error creating UserAccountResult")
                stopTelemetryEvent(telemetryInfo, error: errorType)
                onError(errorType.convertToSignInPasswordStartError(correlationId: telemetryInfo.context.correlationId()))
            }
        } catch {
            let errorType = MSALNativeAuthTokenValidatedErrorType.generalError(nil)
            MSALLogger.logPII(level: .error, context: telemetryInfo.context, format: "SignIn completed with error \(MSALLogMask.maskPII(error))")
            stopTelemetryEvent(telemetryInfo, error: errorType)
            onError(errorType.convertToSignInPasswordStartError(correlationId: telemetryInfo.context.correlationId()))
        }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func handleChallengeResponse(
        _ validatedResponse: MSALNativeAuthSignInChallengeValidatedResponse,
        params: MSALNativeAuthInternalSignInParameters,
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
                    claimsRequestJson: params.claimsRequestJson,
                    context: telemetryInfo.context
                ) else {
                    stopTelemetryEvent(telemetryInfo, error: MSALNativeAuthInternalError.invalidRequest)
                    return .init(
                        .error(SignInStartError(type: .generalError, correlationId: telemetryInfo.context.correlationId())),
                        correlationId: telemetryInfo.context.correlationId()
                    )
                }

                let response = await performAndValidateTokenRequest(request, context: telemetryInfo.context)
                let result = await handleTokenResponse(response,
                                                       scopes: scopes,
                                                       claimsRequestJson: params.claimsRequestJson,
                                                       telemetryInfo: telemetryInfo)
                switch result {
                case .success(let accountResult):
                    return SignInControllerResponse(.completed(accountResult),
                                                    correlationId: telemetryInfo.context.correlationId(),
                                                    telemetryUpdate: { [weak self] result in
                        self?.stopTelemetryEvent(telemetryInfo.event, context: telemetryInfo.context, delegateDispatcherResult: result)
                    })
                case .awaitingMFA(let awaitingMFAState):
                    return SignInControllerResponse(
                        .awaitingMFA(newState: awaitingMFAState),
                        correlationId: telemetryInfo.context.correlationId(),
                        telemetryUpdate: { [weak self] result in
                            self?.stopTelemetryEvent(telemetryInfo.event, context: telemetryInfo.context, delegateDispatcherResult: result)
                        })
                case .jITAuthMethodsSelectionRequired(let authMethods, let jitRequiredState):
                    return SignInControllerResponse(
                        .jitAuthMethodsSelectionRequired(authMethods: authMethods, newState: jitRequiredState),
                        correlationId: telemetryInfo.context.correlationId(),
                        telemetryUpdate: { [weak self] result in
                            self?.stopTelemetryEvent(telemetryInfo.event, context: telemetryInfo.context, delegateDispatcherResult: result)
                        })
                case .error(let error):
                    return SignInControllerResponse(.error(error), correlationId: telemetryInfo.context.correlationId())
                }
            } else {
                let state = SignInPasswordRequiredState(
                    scopes: scopes,
                    username: params.username,
                    controller: self,
                    claimsRequestJson: params.claimsRequestJson,
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
                                                claimsRequestJson: params.claimsRequestJson,
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
            MSALLogger.logPII(level: .error,
                              context: telemetryInfo.context,
                              format: "SignIn, completed with error: \(MSALLogMask.maskPII(error.errorDescription))")
            stopTelemetryEvent(telemetryInfo, error: error)
            return .init(.error(error), correlationId: telemetryInfo.context.correlationId())
        case .introspectRequired:
            let error = SignInStartError(type: .generalError, correlationId: telemetryInfo.context.correlationId())
            MSALLogger.log(level: .error, context: telemetryInfo.context, format: "SignIn, received unexpected introspect required API result")
            self.stopTelemetryEvent(telemetryInfo.event, context: telemetryInfo.context, error: error)
            return .init(.error(error), correlationId: telemetryInfo.context.correlationId())
        }
    }

    private func performAndValidateChallengeRequest(
        continuationToken: String,
        context: MSALNativeAuthRequestContext,
        logErrorMessage: String,
        mfaAuthMethodId: String? = nil
    ) async -> MSALNativeAuthSignInChallengeValidatedResponse {
        guard let challengeRequest = createChallengeRequest(
            continuationToken: continuationToken,
            context: context,
            mfaAuthMethodId: mfaAuthMethodId
        ) else {
            MSALLogger.log(level: .error, context: context, format: logErrorMessage)
            return .error(.invalidRequest(.init()))
        }
        let challengeResponse: Result<MSALNativeAuthSignInChallengeResponse, Error> = await performRequest(challengeRequest, context: context)
        return signInResponseValidator.validateChallenge(context: context, result: challengeResponse)
    }

    private func performAndValidateIntrospectRequest(
        continuationToken: String,
        context: MSALNativeAuthRequestContext
    ) async -> MSALNativeAuthSignInIntrospectValidatedResponse {
        guard let introspectRequest = createIntrospectRequest(
            continuationToken: continuationToken,
            context: context
        ) else {
            MSALLogger.log(level: .error, context: context, format: "Unable to create signIn/introspect request")
            return .error(.invalidRequest(.init()))
        }
        let introspectResponse: Result<MSALNativeAuthSignInIntrospectResponse, Error> = await performRequest(introspectRequest, context: context)
        return signInResponseValidator.validateIntrospect(context: context, result: introspectResponse)
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

    private func createIntrospectRequest(continuationToken: String, context: MSALNativeAuthRequestContext) -> MSIDHttpRequest? {
        let params = MSALNativeAuthSignInIntrospectRequestParameters(context: context, continuationToken: continuationToken)
        do {
            return try signInRequestProvider.introspect(parameters: params, context: context)
        } catch {
            MSALLogger.log(level: .error, context: context, format: "Error creating signIn introspect request: \(error)")
            return nil
        }
    }

    private func createChallengeRequest(
        continuationToken: String,
        context: MSALNativeAuthRequestContext,
        mfaAuthMethodId: String?
    ) -> MSIDHttpRequest? {
        do {
            let params = MSALNativeAuthSignInChallengeRequestParameters(
                context: context,
                mfaAuthMethodId: mfaAuthMethodId,
                continuationToken: continuationToken
            )
            return try signInRequestProvider.challenge(parameters: params, context: context)
        } catch {
            MSALLogger.log(level: .error, context: context, format: "Error creating SignIn Challenge Request: \(error)")
            return nil
        }
    }

    private func createJITController() -> MSALNativeAuthJITController {
        MSALNativeAuthJITController(
            clientId: clientId,
            jitRequestProvider: MSALNativeAuthJITRequestProvider(requestConfigurator: MSALNativeAuthRequestConfigurator(config: nativeAuthConfig)),
            jitResponseValidator: MSALNativeAuthJITResponseValidator(),
            signInController: self)
    }
}
