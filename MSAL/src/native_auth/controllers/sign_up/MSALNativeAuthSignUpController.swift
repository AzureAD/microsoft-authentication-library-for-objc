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
final class MSALNativeAuthSignUpController: MSALNativeAuthBaseController, MSALNativeAuthSignUpControlling {

    // MARK: - Variables

    private let requestProvider: MSALNativeAuthSignUpRequestProviding
    private let responseValidator: MSALNativeAuthSignUpResponseValidating
    private let signInController: MSALNativeAuthSignInControlling

    // MARK: - Init

    init(
        config: MSALNativeAuthConfiguration,
        requestProvider: MSALNativeAuthSignUpRequestProviding,
        responseValidator: MSALNativeAuthSignUpResponseValidating,
        signInController: MSALNativeAuthSignInControlling
    ) {
        self.requestProvider = requestProvider
        self.responseValidator = responseValidator
        self.signInController = signInController
        super.init(clientId: config.clientId)
    }

    convenience init(config: MSALNativeAuthConfiguration, cacheAccessor: MSALNativeAuthCacheInterface) {
        self.init(
            config: config,
            requestProvider: MSALNativeAuthSignUpRequestProvider(
                requestConfigurator: MSALNativeAuthRequestConfigurator(config: config),
                telemetryProvider: MSALNativeAuthTelemetryProvider()
            ),
            responseValidator: MSALNativeAuthSignUpResponseValidator(),
            signInController: MSALNativeAuthSignInController(config: config, cacheAccessor: cacheAccessor)
        )
    }

    // MARK: - Internal

    func signUpStart(parameters: MSALNativeAuthSignUpStartRequestProviderParameters) async -> SignUpStartControllerResponse {
        let eventId: MSALNativeAuthTelemetryApiId =
        parameters.password != nil ? .telemetryApiIdSignUpPasswordStart : .telemetryApiIdSignUpCodeStart
        let event = makeAndStartTelemetryEvent(id: eventId, context: parameters.context)
        let result = await performAndValidateStartRequest(parameters: parameters)
        return await handleSignUpStartResult(result, username: parameters.username, event: event, context: parameters.context)
    }

    func resendCode(username: String, context: MSALNativeAuthRequestContext, continuationToken: String) async -> SignUpResendCodeControllerResponse {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdSignUpResendCode, context: context)
        let challengeResult = await performAndValidateChallengeRequest(continuationToken: continuationToken, context: context)
        return handleResendCodeResult(challengeResult, username: username, event: event, continuationToken: continuationToken, context: context)
    }

    func submitCode(
        _ code: String,
        username: String,
        continuationToken: String,
        context: MSALNativeAuthRequestContext
    ) async -> SignUpSubmitCodeControllerResponse {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdSignUpSubmitCode, context: context)
        let params = MSALNativeAuthSignUpContinueRequestProviderParams(
            grantType: .oobCode,
            continuationToken: continuationToken,
            oobCode: code,
            context: context
        )

        let result = await performAndValidateContinueRequest(parameters: params)
        return await handleSubmitCodeResult(result, username: username, continuationToken: continuationToken, event: event, context: context)
    }

    func submitPassword(
        _ password: String,
        username: String,
        continuationToken: String,
        context: MSALNativeAuthRequestContext
    ) async -> SignUpSubmitPasswordControllerResponse {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdSignUpSubmitPassword, context: context)

        let params = MSALNativeAuthSignUpContinueRequestProviderParams(
            grantType: .password,
            continuationToken: continuationToken,
            password: password,
            context: context
        )
        let continueRequestResult = await performAndValidateContinueRequest(parameters: params)
        return handleSubmitPasswordResult(
            continueRequestResult,
            username: username,
            continuationToken: continuationToken,
            event: event,
            context: context
        )
    }

    func submitAttributes(
        _ attributes: [String: Any],
        username: String,
        continuationToken: String,
        context: MSALNativeAuthRequestContext
    ) async -> SignUpSubmitAttributesControllerResponse {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdSignUpSubmitAttributes, context: context)
        let params = MSALNativeAuthSignUpContinueRequestProviderParams(
            grantType: .attributes,
            continuationToken: continuationToken,
            attributes: attributes,
            context: context
        )

        let result = await performAndValidateContinueRequest(parameters: params)
        return handleSubmitAttributesResult(result, username: username, continuationToken: continuationToken, event: event, context: context)
    }

    // MARK: - Start Request handling

    private func performAndValidateStartRequest(
        parameters: MSALNativeAuthSignUpStartRequestProviderParameters
    ) async -> MSALNativeAuthSignUpStartValidatedResponse {
        let request: MSIDHttpRequest

        do {
            request = try requestProvider.start(parameters: parameters)
        } catch {
            MSALLogger.log(level: .error, context: parameters.context, format: "Error while creating Start Request: \(error)")
            return .unexpectedError(nil)
        }

        MSALLogger.log(level: .info, context: parameters.context, format: "Performing signup/start request")

        let response: Result<MSALNativeAuthSignUpStartResponse, Error> = await performRequest(request, context: parameters.context)
        return responseValidator.validate(response, with: parameters.context)
    }

    // swiftlint:disable:next function_body_length
    private func handleSignUpStartResult(
        _ result: MSALNativeAuthSignUpStartValidatedResponse,
        username: String,
        event: MSIDTelemetryAPIEvent?,
        context: MSALNativeAuthRequestContext
    ) async -> SignUpStartControllerResponse {
        switch result {
        case .success(let continuationToken):
            MSALLogger.log(level: .info, context: context, format: "Successful signup/start request")
            let challengeResult = await performAndValidateChallengeRequest(continuationToken: continuationToken, context: context)
            return handleSignUpChallengeResult(challengeResult, username: username, event: event, context: context)
        case .attributeValidationFailed(let apiError, let invalidAttributes):
            MSALLogger.log(
                level: .error,
                context: context,
                format: "attribute_validation_failed received from signup/start request for attributes: \(invalidAttributes)"
            )
            let message = String(format: MSALNativeAuthErrorMessage.attributeValidationFailedSignUpStart, invalidAttributes.description)
            let error = apiError.toSignUpStartPublicError(correlationId: context.correlationId(), message: message)
            return .init(.attributesInvalid(invalidAttributes), correlationId: context.correlationId(), telemetryUpdate: { [weak self] result in
                // The telemetry event always fails because the attribute validation failed
                self?.stopTelemetryEvent(event, context: context, delegateDispatcherResult: result, controllerError: error)
            })
        case .redirect:
            let error = SignUpStartError(type: .browserRequired, correlationId: context.correlationId())
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Redirect error in signup/start request \(error.errorDescription ?? "No error description")")
            return .init(.error(error), correlationId: context.correlationId())
        case .error(let apiError),
             .unauthorizedClient(let apiError):
            let error = apiError.toSignUpStartPublicError(correlationId: context.correlationId())
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error in signup/start request \(error.errorDescription ?? "No error description")")
            return .init(.error(error), correlationId: context.correlationId())
        case .invalidUsername(let apiError):
            let error = SignUpStartError(
                type: .invalidUsername,
                message: apiError.errorDescription,
                correlationId: context.correlationId(),
                errorCodes: apiError.errorCodes ?? [],
                errorUri: apiError.errorURI
            )
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "InvalidUsername in signup/start request \(error.errorDescription ?? "No error description")")
            return .init(.error(error), correlationId: context.correlationId())
        case .unexpectedError(let apiError):
            let error = SignUpStartError(
                type: .generalError,
                message: apiError?.errorDescription,
                correlationId: context.correlationId(),
                errorCodes: apiError?.errorCodes ?? [],
                errorUri: apiError?.errorURI
            )
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Unexpected error in signup/start request \(error.errorDescription ?? "No error description")")
            return .init(.error(error), correlationId: context.correlationId())
        }
    }

    // MARK: - Challenge Request handling

    private func performAndValidateChallengeRequest(
        continuationToken: String,
        context: MSALNativeAuthRequestContext
    ) async -> MSALNativeAuthSignUpChallengeValidatedResponse {
        let request: MSIDHttpRequest

        do {
            request = try requestProvider.challenge(token: continuationToken, context: context)
        } catch {
            MSALLogger.log(level: .error, context: context, format: "Error while creating Challenge Request: \(error)")
            return .unexpectedError(nil)
        }

        MSALLogger.log(level: .info, context: context, format: "Performing signup/challenge request")

        let result: Result<MSALNativeAuthSignUpChallengeResponse, Error> = await performRequest(request, context: context)
        return responseValidator.validate(result, with: context)
    }

    // swiftlint:disable:next function_body_length
    private func handleSignUpChallengeResult(
        _ result: MSALNativeAuthSignUpChallengeValidatedResponse,
        username: String,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext
    ) -> SignUpStartControllerResponse {
        switch result {
        case .codeRequired(let sentTo, let challengeType, let codeLength, let continuationToken):
            MSALLogger.log(level: .info, context: context, format: "Successful signup/challenge request")
            let result: SignUpStartResult = .codeRequired(
                newState: SignUpCodeRequiredState(
                    controller: self,
                    username: username,
                    continuationToken: continuationToken,
                    correlationId: context.correlationId()
                ),
                sentTo: sentTo,
                channelTargetType: challengeType,
                codeLength: codeLength
            )
            return SignUpStartControllerResponse(result, correlationId: context.correlationId(), telemetryUpdate: { [weak self] result in
                    self?.stopTelemetryEvent(event, context: context, delegateDispatcherResult: result)
                }
            )
        case .error(let apiError):
            let error = apiError.toSignUpStartPublicError(correlationId: context.correlationId())
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error in signup/challenge request \(error.errorDescription ?? "No error description")")
            return .init(.error(error), correlationId: context.correlationId())
        case .redirect:
            let error = SignUpStartError(type: .browserRequired, correlationId: context.correlationId())
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Redirect error in signup/challenge request \(error.errorDescription ?? "No error description")")
            return .init(.error(error), correlationId: context.correlationId())
        case .passwordRequired:
            let error = SignUpStartError(type: .generalError, correlationId: context.correlationId())
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Unexpected error in signup/challenge request \(error.errorDescription ?? "No error description")")
            return .init(.error(error), correlationId: context.correlationId())
        case .unexpectedError(let apiError):
            let error = SignUpStartError(
                type: .generalError,
                message: apiError?.errorDescription,
                correlationId: context.correlationId(),
                errorCodes: apiError?.errorCodes ?? [],
                errorUri: apiError?.errorURI
            )
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Unexpected error in signup/challenge request \(error.errorDescription ?? "No error description")")
            return .init(.error(error), correlationId: context.correlationId())
        }
    }

    // swiftlint:disable:next function_body_length
    private func handleResendCodeResult(
        _ result: MSALNativeAuthSignUpChallengeValidatedResponse,
        username: String,
        event: MSIDTelemetryAPIEvent?,
        continuationToken: String,
        context: MSIDRequestContext
    ) -> SignUpResendCodeControllerResponse {
        switch result {
        case .codeRequired(let sentTo, let challengeType, let codeLength, let newContinuationToken):
            MSALLogger.log(level: .info, context: context, format: "Successful signup/challenge resendCode request")
            let newState = SignUpCodeRequiredState(
                controller: self,
                username: username,
                continuationToken: newContinuationToken,
                correlationId: context.correlationId()
            )
            let result: SignUpResendCodeResult = .codeRequired(
                newState: newState,
                sentTo: sentTo,
                channelTargetType: challengeType,
                codeLength: codeLength
            )
            return .init(result, correlationId: context.correlationId(), telemetryUpdate: { [weak self] result in
                self?.stopTelemetryEvent(event, context: context, delegateDispatcherResult: result)
            })
        case .error(let apiError):
            let error = apiError.toResendCodePublicError(correlationId: context.correlationId())
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error in signup/challenge resendCode request \(error.errorDescription ?? "No error description")")
            let newState = SignUpCodeRequiredState(
                controller: self,
                username: username,
                continuationToken: continuationToken,
                correlationId: context.correlationId()
            )
            return .init(.error(error: error, newState: newState), correlationId: context.correlationId())
        case .redirect:
            let error = ResendCodeError(correlationId: context.correlationId())
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Unexpected error in signup/challenge resendCode request \(error.errorDescription ?? "No error description")")
            return .init(.error(error: error, newState: nil), correlationId: context.correlationId())
        case .passwordRequired:
            let error = ResendCodeError(correlationId: context.correlationId())
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Unexpected error in signup/challenge resendCode request \(error.errorDescription ?? "No error description")")
            return .init(.error(error: error, newState: nil), correlationId: context.correlationId())
        case .unexpectedError(let apiError):
            let error = ResendCodeError(
                message: apiError?.errorDescription,
                correlationId: context.correlationId(),
                errorCodes: apiError?.errorCodes ?? [],
                errorUri: apiError?.errorURI
            )
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Unexpected error in signup/challenge resendCode request \(error.errorDescription ?? "No error description")")
            return .init(.error(error: error, newState: nil), correlationId: context.correlationId())
        }
    }

    /// This method handles the /challenge response after receiving a "credential_required" error
    private func handlePerformChallengeAfterContinueRequest(
        _ result: MSALNativeAuthSignUpChallengeValidatedResponse,
        username: String,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext
    ) -> SignUpSubmitCodeControllerResponse {
        switch result {
        case .passwordRequired(let continuationToken):
            MSALLogger.log(level: .info, context: context, format: "Successful signup/challenge request after credential_required")

            let state = SignUpPasswordRequiredState(controller: self,
                                                    username: username,
                                                    continuationToken: continuationToken,
                                                    correlationId: context.correlationId())

            return .init(.passwordRequired(state), correlationId: context.correlationId(), telemetryUpdate: { [weak self] result in
                self?.stopTelemetryEvent(event, context: context, delegateDispatcherResult: result)
            })
        case .redirect:
            let error = VerifyCodeError(type: .browserRequired, correlationId: context.correlationId())
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Redirect error in signup/challenge request \(error.errorDescription ?? "No error description")")
            return .init(.error(error: error, newState: nil), correlationId: context.correlationId())
        case .error(let apiError):
            let error = VerifyCodeError(
                type: .generalError,
                correlationId: context.correlationId(),
                errorCodes: apiError.errorCodes ?? [],
                errorUri: apiError.errorURI
            )
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Unexpected error in signup/challenge request \(error.errorDescription ?? "No error description")")
            return .init(.error(error: error, newState: nil), correlationId: context.correlationId())
        case .codeRequired:
            let error = VerifyCodeError(type: .generalError, correlationId: context.correlationId())
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Unexpected error in signup/challenge request \(error.errorDescription ?? "No error description")")
            return .init(.error(error: error, newState: nil), correlationId: context.correlationId())
        case .unexpectedError(let apiError):
            let error = VerifyCodeError(
                type: .generalError,
                message: apiError?.errorDescription,
                correlationId: context.correlationId(),
                errorCodes: apiError?.errorCodes ?? [],
                errorUri: apiError?.errorURI
            )
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Unexpected error in signup/challenge request \(error.errorDescription ?? "No error description")")
            return .init(.error(error: error, newState: nil), correlationId: context.correlationId())
        }
    }

    // MARK: - Continue Request handling

    private func performAndValidateContinueRequest(
        parameters: MSALNativeAuthSignUpContinueRequestProviderParams
    ) async -> MSALNativeAuthSignUpContinueValidatedResponse {
        let request: MSIDHttpRequest

        do {
            request = try requestProvider.continue(parameters: parameters)
        } catch {
            MSALLogger.log(level: .error, context: parameters.context, format: "Error while creating Continue Request: \(error)")
            return .unexpectedError(nil)
        }

        MSALLogger.log(level: .info, context: parameters.context, format: "Performing signup/continue request")

        let result: Result<MSALNativeAuthSignUpContinueResponse, Error> = await performRequest(request, context: parameters.context)
        return responseValidator.validate(result, with: parameters.context)
    }

    // swiftlint:disable:next function_body_length
    private func handleSubmitCodeResult(
        _ result: MSALNativeAuthSignUpContinueValidatedResponse,
        username: String,
        continuationToken: String,
        event: MSIDTelemetryAPIEvent?,
        context: MSALNativeAuthRequestContext
    ) async -> SignUpSubmitCodeControllerResponse {
        switch result {
        case .success(let newContinuationToken):
            let state = createSignInAfterSignUpStateUsingContinuationToken(newContinuationToken, username: username, event: event, context: context)
            return .init(.completed(state), correlationId: context.correlationId(), telemetryUpdate: { [weak self] result in
                self?.stopTelemetryEvent(event, context: context, delegateDispatcherResult: result)
            })
        case .invalidUserInput(let apiError):
            MSALLogger.log(level: .error, context: context, format: "invalid_user_input error in signup/continue request")

            let error = VerifyCodeError(
                type: .invalidCode,
                message: apiError.errorDescription,
                correlationId: context.correlationId(),
                errorCodes: apiError.errorCodes ?? [],
                errorUri: apiError.errorURI
            )
            stopTelemetryEvent(event, context: context, error: error)
            let state = SignUpCodeRequiredState(
                controller: self,
                username: username,
                continuationToken: continuationToken,
                correlationId: context.correlationId()
            )
            return .init(.error(error: error, newState: state), correlationId: context.correlationId())
        case .credentialRequired(let newContinuationToken, _):
            MSALLogger.log(level: .info, context: context, format: "credential_required received in signup/continue request")

            let result = await performAndValidateChallengeRequest(continuationToken: newContinuationToken, context: context)
            return handlePerformChallengeAfterContinueRequest(result, username: username, event: event, context: context)
        case .attributesRequired(let newContinuationToken, let attributes, _):
            MSALLogger.log(level: .info, context: context, format: "attributes_required received in signup/continue request: \(attributes)")

            let state = SignUpAttributesRequiredState(controller: self,
                                                      username: username,
                                                      continuationToken: newContinuationToken,
                                                      correlationId: context.correlationId())

            return .init(
                .attributesRequired(attributes: attributes, newState: state),
                correlationId: context.correlationId(),
                telemetryUpdate: { [weak self] result in
                self?.stopTelemetryEvent(event, context: context, delegateDispatcherResult: result)
            })
        case .error(let apiError),
             .attributeValidationFailed(let apiError, _):
            let error = apiError.toVerifyCodePublicError(correlationId: context.correlationId())
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error in signup/continue request \(error.errorDescription ?? "No error description")")
            return .init(.error(error: error, newState: nil), correlationId: context.correlationId())
        case .unexpectedError(let apiError):
            let error = VerifyCodeError(
                type: .generalError,
                message: apiError?.errorDescription,
                correlationId: context.correlationId(),
                errorCodes: apiError?.errorCodes ?? [],
                errorUri: apiError?.errorURI
            )
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Unexpected error in signup/continue request \(error.errorDescription ?? "No error description")")
            return .init(.error(error: error, newState: nil), correlationId: context.correlationId())
        }
    }

    // swiftlint:disable:next function_body_length
    private func handleSubmitPasswordResult(
        _ result: MSALNativeAuthSignUpContinueValidatedResponse,
        username: String,
        continuationToken: String,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext
    ) -> SignUpSubmitPasswordControllerResponse {
        switch result {
        case .success(let newContinuationToken):
            let state = createSignInAfterSignUpStateUsingContinuationToken(newContinuationToken, username: username, event: event, context: context)
            return .init(.completed(state), correlationId: context.correlationId(), telemetryUpdate: { [weak self] result in
                self?.stopTelemetryEvent(event, context: context, delegateDispatcherResult: result)
            })
        case .invalidUserInput(let apiError):
            let error = apiError.toPasswordRequiredPublicError(correlationId: context.correlationId())
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(
                level: .error,
                context: context,
                format: "invalid_user_input error in signup/continue submitPassword request \(error.errorDescription ?? "No error description")"
            )

            let state = SignUpPasswordRequiredState(controller: self,
                                                    username: username,
                                                    continuationToken: continuationToken,
                                                    correlationId: context.correlationId())

            return .init(.error(error: error, newState: state), correlationId: context.correlationId())
        case .attributesRequired(let newContinuationToken, let attributes, _):
            MSALLogger.log(level: .info, context: context, format: "attributes_required received in signup/continue request: \(attributes)")

            let state = SignUpAttributesRequiredState(controller: self,
                                                      username: username,
                                                      continuationToken: newContinuationToken,
                                                      correlationId: context.correlationId())

            return .init(
                .attributesRequired(attributes: attributes, newState: state),
                correlationId: context.correlationId(),
                telemetryUpdate: { [weak self] result in
                self?.stopTelemetryEvent(event, context: context, delegateDispatcherResult: result)
            })
        case .error(let apiError),
             .attributeValidationFailed(let apiError, _),
             .credentialRequired(_, let apiError):
            let error = apiError.toPasswordRequiredPublicError(correlationId: context.correlationId())
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Unexpected error in signup/continue submitPassword request \(error.errorDescription ?? "No error description")")
            return .init(.error(error: error, newState: nil), correlationId: context.correlationId())
        case .unexpectedError(let apiError):
            let error = PasswordRequiredError(
                type: .generalError,
                message: apiError?.errorDescription,
                correlationId: context.correlationId(),
                errorCodes: apiError?.errorCodes ?? [],
                errorUri: apiError?.errorURI
            )
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Unexpected error in signup/continue submitPassword request \(error.errorDescription ?? "No error description")")
            return .init(.error(error: error, newState: nil), correlationId: context.correlationId())
        }
    }

    // swiftlint:disable:next function_body_length
    private func handleSubmitAttributesResult(
        _ result: MSALNativeAuthSignUpContinueValidatedResponse,
        username: String,
        continuationToken: String,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext
    ) -> SignUpSubmitAttributesControllerResponse {
        switch result {
        case .success(let newContinuationToken):
            let state = createSignInAfterSignUpStateUsingContinuationToken(newContinuationToken, username: username, event: event, context: context)
            return .init(.completed(state), correlationId: context.correlationId(), telemetryUpdate: { [weak self] result in
                self?.stopTelemetryEvent(event, context: context, delegateDispatcherResult: result)
            })
        case .attributesRequired(let newContinuationToken, let attributes, let apiError):
            let error = apiError.toAttributesRequiredPublicError(correlationId: context.correlationId())
            MSALLogger.log(level: .error,
                           context: context,
                           format: "attributes_required received in signup/continue submitAttributes request: \(attributes)")
            let state = SignUpAttributesRequiredState(
                controller: self,
                username: username,
                continuationToken: newContinuationToken,
                correlationId: context.correlationId()
            )
            return .init(
                .attributesRequired(attributes: attributes, state: state),
                correlationId: context.correlationId(),
                telemetryUpdate: { [weak self] result in
                // The telemetry event always fails because more attributes are required (we consider this an error after having sent attributes)
                self?.stopTelemetryEvent(event, context: context, delegateDispatcherResult: result, controllerError: error)
            })
        case .attributeValidationFailed(let apiError, let invalidAttributes):
            let message = "attribute_validation_failed from signup/continue submitAttributes request. Make sure these attributes are correct: \(invalidAttributes)" // swiftlint:disable:this line_length
            MSALLogger.log(level: .error, context: context, format: message)

            let errorMessage = String(format: MSALNativeAuthErrorMessage.attributeValidationFailed, invalidAttributes.description)
            let error = apiError.toAttributesRequiredPublicError(correlationId: context.correlationId(), message: errorMessage)
            let state = SignUpAttributesRequiredState(
                controller: self,
                username: username,
                continuationToken: continuationToken,
                correlationId: context.correlationId()
            )
            return .init(
                .attributesInvalid(attributes: invalidAttributes, newState: state),
                correlationId: context.correlationId(),
                telemetryUpdate: { [weak self] result in
                // The telemetry event always fails because the attribute validation failed
                self?.stopTelemetryEvent(event, context: context, delegateDispatcherResult: result, controllerError: error)
            })
        case .error(let apiError),
             .invalidUserInput(let apiError),
             .credentialRequired(_, let apiError):
            let error = apiError.toAttributesRequiredPublicError(correlationId: context.correlationId())
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error in signup/continue submitAttributes request \(error.errorDescription ?? "No error description")")
            return .init(.error(error: error), correlationId: context.correlationId())
        case .unexpectedError(let apiError):
            let error = AttributesRequiredError(
                message: apiError?.errorDescription,
                correlationId: context.correlationId(),
                errorCodes: apiError?.errorCodes ?? [],
                errorUri: apiError?.errorURI
            )
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Unexpected error in signup/continue submitAttributes request \(error.errorDescription ?? "No error description")")
            return .init(.error(error: error), correlationId: context.correlationId())
        }
    }

    private func createSignInAfterSignUpStateUsingContinuationToken(
        _ continuationToken: String?,
        username: String,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext
    ) -> SignInAfterSignUpState {
        MSALLogger.log(level: .info, context: context, format: "SignUp completed successfully")
        stopTelemetryEvent(event, context: context)
        return SignInAfterSignUpState(
            controller: signInController,
            username: username,
            continuationToken: continuationToken,
            correlationId: context.correlationId()
        )
    }
}
