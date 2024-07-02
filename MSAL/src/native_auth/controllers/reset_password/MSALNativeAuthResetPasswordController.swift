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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

@_implementationOnly import MSAL_Private

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
final class MSALNativeAuthResetPasswordController: MSALNativeAuthBaseController, MSALNativeAuthResetPasswordControlling {
    private let kNumberOfTimesToRetryPollCompletionCall = 5

    private let requestProvider: MSALNativeAuthResetPasswordRequestProviding
    private let responseValidator: MSALNativeAuthResetPasswordResponseValidating
    private let signInController: MSALNativeAuthSignInControlling

    init(
        config: MSALNativeAuthConfiguration,
        requestProvider: MSALNativeAuthResetPasswordRequestProviding,
        responseValidator: MSALNativeAuthResetPasswordResponseValidating,
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
            requestProvider: MSALNativeAuthResetPasswordRequestProvider(
                requestConfigurator: MSALNativeAuthRequestConfigurator(config: config),
                telemetryProvider: MSALNativeAuthTelemetryProvider()
            ),
            responseValidator: MSALNativeAuthResetPasswordResponseValidator(),
            signInController: MSALNativeAuthSignInController(config: config, cacheAccessor: cacheAccessor)
        )
    }

    // MARK: - Internal interface methods

    func resetPassword(parameters: MSALNativeAuthResetPasswordStartRequestProviderParameters) async -> ResetPasswordStartControllerResponse {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdResetPasswordStart, context: parameters.context)
        let response = await performStartRequest(parameters: parameters)
        return await handleStartResponse(response, username: parameters.username, event: event, context: parameters.context)
    }

    func resendCode(
        username: String,
        continuationToken: String,
        context: MSALNativeAuthRequestContext
    ) async -> ResetPasswordResendCodeControllerResponse {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdResetPasswordResendCode, context: context)
        let response = await performChallengeRequest(continuationToken: continuationToken, context: context)
        return await handleResendCodeChallengeResponse(response, username: username, event: event, context: context)
    }

    func submitCode(
        code: String,
        username: String,
        continuationToken: String,
        context: MSALNativeAuthRequestContext
    ) async -> ResetPasswordSubmitCodeControllerResponse {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdResetPasswordSubmitCode, context: context)

        let params = MSALNativeAuthResetPasswordContinueRequestParameters(
            context: context,
            continuationToken: continuationToken,
            grantType: .oobCode,
            oobCode: code
        )

        let response = await performContinueRequest(parameters: params)
        return await handleSubmitCodeResponse(response, username: username, continuationToken: continuationToken, event: event, context: context)
    }

    func submitPassword(
        password: String,
        username: String,
        continuationToken: String,
        context: MSALNativeAuthRequestContext
    ) async -> ResetPasswordSubmitPasswordControllerResponse {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdResetPasswordSubmit, context: context)

        let params = MSALNativeAuthResetPasswordSubmitRequestParameters(
            context: context,
            continuationToken: continuationToken,
            newPassword: password
        )
        let submitRequestResponse = await performSubmitRequest(parameters: params)
        return await handleSubmitPasswordResponse(
            submitRequestResponse,
            username: username,
            continuationToken: continuationToken,
            event: event,
            context: context
        )
    }

    // MARK: - Start Request handling

    private func performStartRequest(
        parameters: MSALNativeAuthResetPasswordStartRequestProviderParameters
    ) async -> MSALNativeAuthResetPasswordStartValidatedResponse {
        let request: MSIDHttpRequest

        do {
            request = try requestProvider.start(parameters: parameters)
        } catch {
            MSALLogger.log(level: .error, context: parameters.context, format: "Error creating resetpassword/start request: \(error)")
            return .unexpectedError(nil)
        }

        MSALLogger.log(level: .info, context: parameters.context, format: "Performing resetpassword/start request")

        let result: Result<MSALNativeAuthResetPasswordStartResponse, Error> = await performRequest(request, context: parameters.context)
        return responseValidator.validate(result, with: parameters.context)
    }

    private func handleStartResponse(_ response: MSALNativeAuthResetPasswordStartValidatedResponse,
                                     username: String,
                                     event: MSIDTelemetryAPIEvent?,
                                     context: MSALNativeAuthRequestContext) async -> ResetPasswordStartControllerResponse {

        MSALLogger.log(level: .info, context: context, format: "Finished resetpassword/start request")

        switch response {
        case .success(let continuationToken):
            let challengeResponse = await performChallengeRequest(continuationToken: continuationToken, context: context)
            return await handleChallengeResponse(challengeResponse, username: username, event: event, context: context)
        case .redirect:
            let error = ResetPasswordStartError(
                type: .browserRequired,
                message: MSALNativeAuthErrorMessage.browserRequired,
                correlationId: context.correlationId()
            )
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Redirect error in resetpassword/start request \(error.errorDescription ?? "No error description")")
            return .init(.error(error), correlationId: context.correlationId())
        case .error(let validatedError):
            let error = validatedError.toResetPasswordStartPublicError(context: context)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error in resetpassword/start request \(error.errorDescription ?? "No error description")")
            return .init(.error(error), correlationId: context.correlationId())
        case .unexpectedError(let apiError):
            let error = ResetPasswordStartError(
                type: .generalError,
                message: apiError?.errorDescription,
                correlationId: context.correlationId(),
                errorCodes: apiError?.errorCodes ?? [],
                errorUri: apiError?.errorURI
            )
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Unexpected error in resetpassword/start request \(error.errorDescription ?? "No error description")")
            return .init(.error(error), correlationId: context.correlationId())
        }
    }

    // MARK: - Challenge Request handling

    private func performChallengeRequest(
        continuationToken: String,
        context: MSALNativeAuthRequestContext
    ) async -> MSALNativeAuthResetPasswordChallengeValidatedResponse {
        let request: MSIDHttpRequest

        do {
            request = try requestProvider.challenge(token: continuationToken, context: context)
        } catch {
            MSALLogger.log(level: .error, context: context, format: "Error creating Challenge Request: \(error)")
            return .unexpectedError(nil)
        }

        MSALLogger.log(level: .info, context: context, format: "Performing resetpassword/challenge request")

        let result: Result<MSALNativeAuthResetPasswordChallengeResponse, Error> = await performRequest(request, context: context)
        return responseValidator.validate(result, with: context)
    }

    private func handleChallengeResponse(
        _ response: MSALNativeAuthResetPasswordChallengeValidatedResponse,
        username: String,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext
    ) async -> ResetPasswordStartControllerResponse {
        switch response {
        case .success(let sentTo, let channelTargetType, let codeLength, let challengeToken):
            MSALLogger.log(level: .info, context: context, format: "Successful resetpassword/challenge request")
            let newState = ResetPasswordCodeRequiredState(
                controller: self,
                username: username,
                continuationToken: challengeToken,
                correlationId: context.correlationId()
            )
            let result: ResetPasswordStartResult = .codeRequired(
                newState: newState,
                sentTo: sentTo,
                channelTargetType: channelTargetType,
                codeLength: codeLength
            )
            return .init(result, correlationId: context.correlationId(), telemetryUpdate: { [weak self] result in
                self?.stopTelemetryEvent(event, context: context, delegateDispatcherResult: result)
            })
        case .error(let apiError):
            let error = apiError.toResetPasswordStartPublicError(correlationId: context.correlationId())
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error in resetpassword/challenge request \(error.errorDescription ?? "No error description")")
            return .init(.error(error), correlationId: context.correlationId())
        case .redirect:
            let error = ResetPasswordStartError(
                type: .browserRequired,
                message: MSALNativeAuthErrorMessage.browserRequired,
                correlationId: context.correlationId()
            )
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Redirect error in resetpassword/challenge request \(error.errorDescription ?? "No error description")")
            return .init(.error(error), correlationId: context.correlationId())
        case .unexpectedError(let apiError):
            let error = ResetPasswordStartError(
                type: .generalError,
                message: apiError?.errorDescription,
                correlationId: context.correlationId(),
                errorCodes: apiError?.errorCodes ?? [],
                errorUri: apiError?.errorURI
            )
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Unexpected error in resetpassword/challenge request \(error.errorDescription ?? "No error description")")
            return .init(.error(error), correlationId: context.correlationId())
        }
    }

    private func handleResendCodeChallengeResponse(
        _ response: MSALNativeAuthResetPasswordChallengeValidatedResponse,
        username: String,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext
    ) async -> ResetPasswordResendCodeControllerResponse {
        switch response {
        case .success(let sentTo, let channelTargetType, let codeLength, let challengeToken):
            MSALLogger.log(level: .info, context: context, format: "Successful resetpassword/challenge (resend code) request")
            return .init(.codeRequired(
                newState: ResetPasswordCodeRequiredState(
                    controller: self,
                    username: username,
                    continuationToken: challengeToken,
                    correlationId: context.correlationId()
                ),
                sentTo: sentTo,
                channelTargetType: channelTargetType,
                codeLength: codeLength
            ), correlationId: context.correlationId(), telemetryUpdate: { [weak self] result in
                self?.stopTelemetryEvent(event, context: context, delegateDispatcherResult: result)
            })
        case .error(let apiError):
            let error = apiError.toResendCodePublicError(correlationId: context.correlationId())
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error in resetpassword/challenge request (resend code) \(error.errorDescription ?? "No error description")")
            return .init(.error(error: error, newState: nil), correlationId: context.correlationId())
        case .redirect:
            let error = ResendCodeError(correlationId: context.correlationId())
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error in resetpassword/challenge request (resend code) \(error.errorDescription ?? "No error description")")
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
                           format: "Error in resetpassword/challenge request (resend code) \(error.errorDescription ?? "No error description")")
            return .init(.error(error: error, newState: nil), correlationId: context.correlationId())
        }
    }

    // MARK: - Continue Request handling

    private func performContinueRequest(
        parameters: MSALNativeAuthResetPasswordContinueRequestParameters
    ) async -> MSALNativeAuthResetPasswordContinueValidatedResponse {
        let request: MSIDHttpRequest

        do {
            request = try requestProvider.continue(parameters: parameters)
        } catch {
            MSALLogger.log(level: .error, context: parameters.context, format: "Error creating Continue Request: \(error)")
            return .unexpectedError(nil)
        }

        MSALLogger.log(level: .info, context: parameters.context, format: "Performing resetpassword/continue request")

        let result: Result<MSALNativeAuthResetPasswordContinueResponse, Error> = await performRequest(request, context: parameters.context)
        return responseValidator.validate(result, with: parameters.context)
    }

    // swiftlint:disable:next function_body_length
    private func handleSubmitCodeResponse(
        _ response: MSALNativeAuthResetPasswordContinueValidatedResponse,
        username: String,
        continuationToken: String,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext
    ) async -> ResetPasswordSubmitCodeControllerResponse {
        switch response {
        case .success(let newContinuationToken):
            MSALLogger.log(level: .info, context: context, format: "Successful resetpassword/continue request")
            let newState = ResetPasswordRequiredState(
                controller: self,
                username: username,
                continuationToken: newContinuationToken,
                correlationId: context.correlationId()
            )
            return .init(.passwordRequired(newState: newState), correlationId: context.correlationId(), telemetryUpdate: { [weak self] result in
                self?.stopTelemetryEvent(event, context: context, delegateDispatcherResult: result)
            })
        case .error(let apiError):
            let error = apiError.toVerifyCodePublicError(correlationId: context.correlationId())
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error in resetpassword/continue request \(error.errorDescription ?? "No error description")")
            return .init(.error(error: error, newState: nil), correlationId: context.correlationId())
        case .unexpectedError(let apiError):
            let error = VerifyCodeError(
                type: .generalError,
                message: apiError?.errorDescription,
                correlationId: context.correlationId(),
                errorCodes: apiError?.errorCodes ?? [],
                errorUri: apiError?.errorURI
            )
            self.stopTelemetryEvent(event, context: context, error: error)

            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error calling resetpassword/continue \(error.errorDescription ?? "No error description")")

            return .init(.error(error: error, newState: nil), correlationId: context.correlationId())
        case .invalidOOB(let apiError):
            let error = VerifyCodeError(
                type: .invalidCode,
                message: apiError.errorDescription,
                correlationId: context.correlationId(),
                errorCodes: apiError.errorCodes ?? [],
                errorUri: apiError.errorURI
            )
            self.stopTelemetryEvent(event, context: context, error: error)

            MSALLogger.log(level: .error,
                           context: context,
                           format: "Invalid code error calling resetpassword/continue \(error.errorDescription ?? "No error description")")

            let state = ResetPasswordCodeRequiredState(
                controller: self,
                username: username,
                continuationToken: continuationToken,
                correlationId: context.correlationId()
            )
            return .init(.error(error: error, newState: state), correlationId: context.correlationId())
        }
    }

    // MARK: - Submit Request handling

    private func performSubmitRequest(
        parameters: MSALNativeAuthResetPasswordSubmitRequestParameters
    ) async -> MSALNativeAuthResetPasswordSubmitValidatedResponse {
        let request: MSIDHttpRequest

        do {
            request = try requestProvider.submit(parameters: parameters)
        } catch {
            MSALLogger.log(level: .error, context: parameters.context, format: "Error creating Submit Request: \(error)")
            return .unexpectedError(nil)
        }

        MSALLogger.log(level: .info, context: parameters.context, format: "Performing resetpassword/submit request")

        let result: Result<MSALNativeAuthResetPasswordSubmitResponse, Error> = await performRequest(request, context: parameters.context)
        return responseValidator.validate(result, with: parameters.context)
    }

    private func handleSubmitPasswordResponse(
        _ response: MSALNativeAuthResetPasswordSubmitValidatedResponse,
        username: String,
        continuationToken: String,
        event: MSIDTelemetryAPIEvent?,
        context: MSALNativeAuthRequestContext
    ) async -> ResetPasswordSubmitPasswordControllerResponse {
        MSALLogger.log(level: .info, context: context, format: "Finished resetpassword/submit request")

        switch response {
        case .success(let newContinuationToken, let pollInterval):
            return await doPollCompletionLoop(
                username: username,
                continuationToken: newContinuationToken,
                pollInterval: pollInterval,
                retriesRemaining: kNumberOfTimesToRetryPollCompletionCall,
                event: event,
                context: context
            )
        case .passwordError(let apiError):
            let error = apiError.toPasswordRequiredPublicError(correlationId: context.correlationId())
            self.stopTelemetryEvent(event, context: context, error: error)

            MSALLogger.log(level: .error,
                           context: context,
                           format: "Password error calling resetpassword/submit \(error.errorDescription ?? "No error description")")
            let newState = ResetPasswordRequiredState(
                controller: self,
                username: username,
                continuationToken: continuationToken,
                correlationId: context.correlationId()
            )
            return .init(.error(error: error, newState: newState), correlationId: context.correlationId())
        case .error(let apiError):
            let error = apiError.toPasswordRequiredPublicError(correlationId: context.correlationId())
            self.stopTelemetryEvent(event, context: context, error: error)

            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error calling resetpassword/submit \(error.errorDescription ?? "No error description")")

            return .init(.error(error: error, newState: nil), correlationId: context.correlationId())
        case .unexpectedError(let apiError):
            let error = PasswordRequiredError(
                type: .generalError,
                message: apiError?.errorDescription,
                correlationId: context.correlationId(),
                errorCodes: apiError?.errorCodes ?? [],
                errorUri: apiError?.errorURI
            )
            self.stopTelemetryEvent(event, context: context, error: error)

            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error calling resetpassword/submit \(error.errorDescription ?? "No error description")")

            return .init(.error(error: error, newState: nil), correlationId: context.correlationId())
        }
    }

    // MARK: - Poll Completion Request handling

    private func doPollCompletionLoop(
        username: String,
        continuationToken: String,
        pollInterval: Int,
        retriesRemaining: Int,
        event: MSIDTelemetryAPIEvent?,
        context: MSALNativeAuthRequestContext
    ) async -> ResetPasswordSubmitPasswordControllerResponse {
        MSALLogger.log(level: .info, context: context, format: "Performing poll completion request")

        let pollCompletionResponse = await performPollCompletionRequest(
            continuationToken: continuationToken,
            context: context
        )

        MSALLogger.log(level: .info, context: context, format: "Handling poll completion response")

        return await handlePollCompletionResponse(
            pollCompletionResponse,
            username: username,
            pollInterval: pollInterval,
            retriesRemaining: retriesRemaining,
            continuationToken: continuationToken,
            event: event,
            context: context
        )
    }

    private func performPollCompletionRequest(
        continuationToken: String,
        context: MSALNativeAuthRequestContext
    ) async -> MSALNativeAuthResetPasswordPollCompletionValidatedResponse {
        let parameters = MSALNativeAuthResetPasswordPollCompletionRequestParameters(
            context: context,
            continuationToken: continuationToken
        )
        let request: MSIDHttpRequest

        do {
            request = try requestProvider.pollCompletion(parameters: parameters)
        } catch {
            MSALLogger.log(level: .error, context: parameters.context, format: "Error creating Poll Completion Request: \(error)")
            return .unexpectedError(nil)
        }

        MSALLogger.log(level: .info, context: parameters.context, format: "Performing resetpassword/poll_completion request")

        let result: Result<MSALNativeAuthResetPasswordPollCompletionResponse, Error> = await performRequest(
            request,
            context: parameters.context
        )
        return responseValidator.validate(result, with: parameters.context)
    }

    // swiftlint:disable function_body_length
    private func handlePollCompletionResponse(
        _ response: MSALNativeAuthResetPasswordPollCompletionValidatedResponse,
        username: String,
        pollInterval: Int,
        retriesRemaining: Int,
        continuationToken: String,
        event: MSIDTelemetryAPIEvent?,
        context: MSALNativeAuthRequestContext
    ) async -> ResetPasswordSubmitPasswordControllerResponse {
        MSALLogger.log(level: .info, context: context, format: "Finished resetpassword/poll_completion")

        switch response {
        case .success(let status, let newContinuationToken):
            switch status {
            case .inProgress,
                 .notStarted:

                return await retryPollCompletion(
                    continuationToken: continuationToken,
                    pollInterval: pollInterval,
                    retriesRemaining: retriesRemaining,
                    username: username,
                    event: event,
                    context: context
                )
            case .succeeded:
                let signInAfterResetPasswordState = SignInAfterResetPasswordState(
                    controller: signInController,
                    username: username,
                    continuationToken: newContinuationToken,
                    correlationId: context.correlationId()
                )
                return .init(
                    .completed(signInAfterResetPasswordState),
                    correlationId: context.correlationId(),
                    telemetryUpdate: { [weak self] result in
                    self?.stopTelemetryEvent(event, context: context, delegateDispatcherResult: result)
                })
            case .failed:
                let error = PasswordRequiredError(type: .generalError, correlationId: context.correlationId())
                self.stopTelemetryEvent(event, context: context, error: error)
                MSALLogger.log(level: .error, context: context, format: "Password poll completion returned status 'failed'")

                return .init(.error(error: error, newState: nil), correlationId: context.correlationId())
            }
        case .passwordError(let apiError):
            let error = apiError.toPasswordRequiredPublicError(correlationId: context.correlationId())
            self.stopTelemetryEvent(event, context: context, error: error)

            MSALLogger.log(level: .error,
                           context: context,
                           format: "Password error calling resetpassword/poll_completion \(error.errorDescription ?? "No error description")")
            let newState = ResetPasswordRequiredState(
                controller: self,
                username: username,
                continuationToken: continuationToken,
                correlationId: context.correlationId()
            )
            return .init(.error(error: error, newState: newState), correlationId: context.correlationId())
        case .error(let apiError):
            let error = apiError.toPasswordRequiredPublicError(correlationId: context.correlationId())
            self.stopTelemetryEvent(event, context: context, error: error)

            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error calling resetpassword/poll_completion \(error.errorDescription ?? "No error description")")

            return .init(.error(error: error, newState: nil), correlationId: context.correlationId())
        case .unexpectedError(let apiError):
            let error = PasswordRequiredError(
                type: .generalError,
                message: apiError?.errorDescription,
                correlationId: context.correlationId(),
                errorCodes: apiError?.errorCodes ?? [],
                errorUri: apiError?.errorURI
            )
            self.stopTelemetryEvent(event, context: context, error: error)

            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error calling resetpassword/poll_completion \(error.errorDescription ?? "No error description")")

            return .init(.error(error: error, newState: nil), correlationId: context.correlationId())
        }
    }
    // swiftlint:enable function_body_length

    private func retryPollCompletion(
        continuationToken: String,
        pollInterval: Int,
        retriesRemaining: Int,
        username: String,
        event: MSIDTelemetryAPIEvent?,
        context: MSALNativeAuthRequestContext
    ) async -> ResetPasswordSubmitPasswordControllerResponse {
        guard retriesRemaining > 0 else {
            let error = PasswordRequiredError(type: .generalError, correlationId: context.correlationId())
            self.stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "Password poll completion did not complete in time")

            return .init(.error(error: error, newState: nil), correlationId: context.correlationId())
        }

        MSALLogger.log(
            level: .info,
            context: context,
            format: "Reset password: waiting for \(pollInterval) seconds before retrying"
        )

        do {
            try await Task.sleep(nanoseconds: 1_000_000_000 * UInt64(pollInterval))
        } catch {
            // Task.sleep can throw a CancellationError if the Task is cancelled.
            // We don't expect that to ever happen here so we just log it and carry on

            MSALLogger.log(
                level: .error,
                context: context,
                format: "Reset Password: Task.sleep unexpectedly threw an error: \(error). Ignoring"
            )
        }

        return await doPollCompletionLoop(
            username: username,
            continuationToken: continuationToken,
            pollInterval: pollInterval,
            retriesRemaining: retriesRemaining - 1,
            event: event,
            context: context
        )
    }
}
// swiftlint:enable file_length
