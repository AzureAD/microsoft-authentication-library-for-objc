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

    convenience init(config: MSALNativeAuthConfiguration) {
        self.init(
            config: config,
            requestProvider: MSALNativeAuthResetPasswordRequestProvider(
                requestConfigurator: MSALNativeAuthRequestConfigurator(config: config),
                telemetryProvider: MSALNativeAuthTelemetryProvider()
            ),
            responseValidator: MSALNativeAuthResetPasswordResponseValidator(),
            signInController: MSALNativeAuthSignInController(config: config)
        )
    }

    // MARK: - Internal interface methods

    func resetPassword(parameters: MSALNativeAuthResetPasswordStartRequestProviderParameters) async -> ResetPasswordStartControllerResponse {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdResetPasswordStart, context: parameters.context)
        let response = await performStartRequest(parameters: parameters)
        return await handleStartResponse(response, username: parameters.username, event: event, context: parameters.context)
    }

    func resendCode(username: String, passwordResetToken: String, context: MSIDRequestContext) async -> ResetPasswordResendCodeControllerResponse {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdResetPasswordResendCode, context: context)
        let response = await performChallengeRequest(passwordResetToken: passwordResetToken, context: context)
        return await handleResendCodeChallengeResponse(response, username: username, event: event, context: context)
    }

    func submitCode(
        code: String,
        username: String,
        passwordResetToken: String,
        context: MSIDRequestContext
    ) async -> ResetPasswordSubmitCodeControllerResponse {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdResetPasswordSubmitCode, context: context)

        let params = MSALNativeAuthResetPasswordContinueRequestParameters(
            context: context,
            passwordResetToken: passwordResetToken,
            grantType: .oobCode,
            oobCode: code
        )

        let response = await performContinueRequest(parameters: params)
        return await handleSubmitCodeResponse(response, username: username, passwordResetToken: passwordResetToken, event: event, context: context)
    }

    func submitPassword(
        password: String,
        username: String,
        passwordSubmitToken: String,
        context: MSIDRequestContext
    ) async -> ResetPasswordSubmitPasswordControllerResponse {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdResetPasswordSubmit, context: context)

        let params = MSALNativeAuthResetPasswordSubmitRequestParameters(
            context: context,
            passwordSubmitToken: passwordSubmitToken,
            newPassword: password
        )
        let submitRequestResponse = await performSubmitRequest(parameters: params)
        return await handleSubmitPasswordResponse(
            submitRequestResponse,
            username: username,
            passwordSubmitToken: passwordSubmitToken,
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
            return .unexpectedError
        }

        MSALLogger.log(level: .info, context: parameters.context, format: "Performing resetpassword/start request")

        let result: Result<MSALNativeAuthResetPasswordStartResponse, Error> = await performRequest(request, context: parameters.context)
        return responseValidator.validate(result, with: parameters.context)
    }

    private func handleStartResponse(_ response: MSALNativeAuthResetPasswordStartValidatedResponse,
                                     username: String,
                                     event: MSIDTelemetryAPIEvent?,
                                     context: MSIDRequestContext) async -> ResetPasswordStartControllerResponse {

        MSALLogger.log(level: .verbose, context: context, format: "Finished resetpassword/start request")

        switch response {
        case .success(let passwordResetToken):
            let challengeResponse = await performChallengeRequest(passwordResetToken: passwordResetToken, context: context)
            return await handleChallengeResponse(challengeResponse, username: username, event: event, context: context)
        case .redirect:
            let error = ResetPasswordStartError(type: .browserRequired, message: MSALNativeAuthErrorMessage.browserRequired)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "redirect error in resetpassword/start request \(error.errorDescription ?? "No error description")")
            return .init(.error(error))
        case .error(let apiError):
            let error = apiError.toResetPasswordStartPublicError()
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error in resetpassword/start request \(error.errorDescription ?? "No error description")")
            return .init(.error(error))
        case .unexpectedError:
            let error = ResetPasswordStartError(type: .generalError)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Unexpected error in resetpassword/start request \(error.errorDescription ?? "No error description")")
            return .init(.error(error))
        }
    }

    // MARK: - Challenge Request handling

    private func performChallengeRequest(
        passwordResetToken: String,
        context: MSIDRequestContext
    ) async -> MSALNativeAuthResetPasswordChallengeValidatedResponse {
        let request: MSIDHttpRequest

        do {
            request = try requestProvider.challenge(token: passwordResetToken, context: context)
        } catch {
            MSALLogger.log(level: .error, context: context, format: "Error creating Challenge Request: \(error)")
            return .unexpectedError
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

            return .init(.codeRequired(
                newState: ResetPasswordCodeRequiredState(
                    controller: self,
                    username: username,
                    flowToken: challengeToken,
                    correlationId: context.correlationId()
                ),
                sentTo: sentTo,
                channelTargetType: channelTargetType,
                codeLength: codeLength
            ), telemetryUpdate: { [weak self] result in
                self?.stopTelemetryEvent(event, context: context, delegateDispatcherResult: result)
            })
        case .error(let apiError):
            let error = apiError.toResetPasswordStartPublicError()
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error in resetpassword/challenge request \(error.errorDescription ?? "No error description")")
            return .init(.error(error))
        case .redirect:
            let error = ResetPasswordStartError(type: .browserRequired, message: MSALNativeAuthErrorMessage.browserRequired)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Redirect error in resetpassword/challenge request \(error.errorDescription ?? "No error description")")
            return .init(.error(error))
        case .unexpectedError:
            let error = ResetPasswordStartError(type: .generalError)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Unexpected error in resetpassword/challenge request \(error.errorDescription ?? "No error description")")
            return .init(.error(error))
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
                    flowToken: challengeToken,
                    correlationId: context.correlationId()
                ),
                sentTo: sentTo,
                channelTargetType: channelTargetType,
                codeLength: codeLength
            ), telemetryUpdate: { [weak self] result in
                self?.stopTelemetryEvent(event, context: context, delegateDispatcherResult: result)
            })
        case .error(let apiError):
            let error = apiError.toResendCodePublicError()
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error in resetpassword/challenge request (resend code) \(error.errorDescription ?? "No error description")")
            return .init(.error(error: error, newState: nil))
        case .redirect,
                .unexpectedError:
            let error = ResendCodeError()
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error in resetpassword/challenge request (resend code) \(error.errorDescription ?? "No error description")")
            return .init(.error(error: error, newState: nil))
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
            return .unexpectedError
        }

        MSALLogger.log(level: .info, context: parameters.context, format: "Performing resetpassword/continue request")

        let result: Result<MSALNativeAuthResetPasswordContinueResponse, Error> = await performRequest(request, context: parameters.context)
        return responseValidator.validate(result, with: parameters.context)
    }

    private func handleSubmitCodeResponse(
        _ response: MSALNativeAuthResetPasswordContinueValidatedResponse,
        username: String,
        passwordResetToken: String,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext
    ) async -> ResetPasswordSubmitCodeControllerResponse {
        switch response {
        case .success(let passwordSubmitToken):
            MSALLogger.log(level: .info, context: context, format: "Successful resetpassword/continue request")
            let newState = ResetPasswordRequiredState(
                controller: self,
                username: username,
                flowToken: passwordSubmitToken,
                correlationId: context.correlationId()
            )
            return .init(.passwordRequired(newState: newState),
                         telemetryUpdate: { [weak self] result in
                self?.stopTelemetryEvent(event, context: context, delegateDispatcherResult: result)
            })
        case .error(let apiError):
            let error = apiError.toVerifyCodePublicError()
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error in resetpassword/continue request \(error.errorDescription ?? "No error description")")
            return .init(.error(error: error, newState: nil))
        case .unexpectedError:
            let error = VerifyCodeError(type: .generalError)
            self.stopTelemetryEvent(event, context: context, error: error)

            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error calling resetpassword/continue \(error.errorDescription ?? "No error description")")

            return .init(.error(error: error, newState: nil))
        case .invalidOOB:
            let error = VerifyCodeError(type: .invalidCode)
            self.stopTelemetryEvent(event, context: context, error: error)

            MSALLogger.log(level: .error,
                           context: context,
                           format: "Invalid code error calling resetpassword/continue \(error.errorDescription ?? "No error description")")

            let state = ResetPasswordCodeRequiredState(
                controller: self,
                username: username,
                flowToken: passwordResetToken,
                correlationId: context.correlationId()
            )
            return .init(.error(error: error, newState: state))
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
            return .unexpectedError
        }

        MSALLogger.log(level: .info, context: parameters.context, format: "Performing resetpassword/submit request")

        let result: Result<MSALNativeAuthResetPasswordSubmitResponse, Error> = await performRequest(request, context: parameters.context)
        return responseValidator.validate(result, with: parameters.context)
    }

    private func handleSubmitPasswordResponse(
        _ response: MSALNativeAuthResetPasswordSubmitValidatedResponse,
        username: String,
        passwordSubmitToken: String,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext
    ) async -> ResetPasswordSubmitPasswordControllerResponse {
        MSALLogger.log(level: .info, context: context, format: "Finished resetpassword/submit request")

        switch response {
        case .success(let passwordResetToken, let pollInterval):
            return await doPollCompletionLoop(
                username: username,
                passwordResetToken: passwordResetToken,
                pollInterval: pollInterval,
                retriesRemaining: kNumberOfTimesToRetryPollCompletionCall,
                event: event,
                context: context
            )
        case .passwordError(let apiError):
            let error = apiError.toPasswordRequiredPublicError()
            self.stopTelemetryEvent(event, context: context, error: error)

            MSALLogger.log(level: .error,
                           context: context,
                           format: "Password error calling resetpassword/submit \(error.errorDescription ?? "No error description")")
            let newState = ResetPasswordRequiredState(
                controller: self,
                username: username,
                flowToken: passwordSubmitToken,
                correlationId: context.correlationId()
            )
            return .init(.error(error: error, newState: newState))
        case .error(let apiError):
            let error = apiError.toPasswordRequiredPublicError()
            self.stopTelemetryEvent(event, context: context, error: error)

            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error calling resetpassword/submit \(error.errorDescription ?? "No error description")")

            return .init(.error(error: error, newState: nil))
        case .unexpectedError:
            let error = PasswordRequiredError(type: .generalError)
            self.stopTelemetryEvent(event, context: context, error: error)

            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error calling resetpassword/submit \(error.errorDescription ?? "No error description")")

            return .init(.error(error: error, newState: nil))
        }
    }

    // MARK: - Poll Completion Request handling

    private func doPollCompletionLoop(
        username: String,
        passwordResetToken: String,
        pollInterval: Int,
        retriesRemaining: Int,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext
    ) async -> ResetPasswordSubmitPasswordControllerResponse {
        MSALLogger.log(level: .verbose, context: context, format: "performing poll completion request...")

        let pollCompletionResponse = await performPollCompletionRequest(
            passwordResetToken: passwordResetToken,
            context: context
        )

        MSALLogger.log(level: .verbose, context: context, format: "handling poll completion response...")

        return await handlePollCompletionResponse(
            pollCompletionResponse,
            username: username,
            pollInterval: pollInterval,
            retriesRemaining: retriesRemaining,
            passwordResetToken: passwordResetToken,
            event: event,
            context: context
        )
    }

    private func performPollCompletionRequest(
        passwordResetToken: String,
        context: MSIDRequestContext
    ) async -> MSALNativeAuthResetPasswordPollCompletionValidatedResponse {
        let parameters = MSALNativeAuthResetPasswordPollCompletionRequestParameters(
            context: context,
            passwordResetToken: passwordResetToken
        )
        let request: MSIDHttpRequest

        do {
            request = try requestProvider.pollCompletion(parameters: parameters)
        } catch {
            MSALLogger.log(level: .error, context: parameters.context, format: "Error creating Poll Completion Request: \(error)")
            return .unexpectedError
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
        passwordResetToken: String,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext
    ) async -> ResetPasswordSubmitPasswordControllerResponse {
        MSALLogger.log(level: .info, context: context, format: "Finished resetpassword/poll_completion")

        switch response {
        case .success(let status, let continuationToken):
            switch status {
            case .inProgress,
                 .notStarted:

                return await retryPollCompletion(
                    passwordResetToken: passwordResetToken,
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
                    slt: continuationToken,
                    correlationId: context.correlationId()
                )
                return .init(.completed(signInAfterResetPasswordState), telemetryUpdate: { [weak self] result in
                    self?.stopTelemetryEvent(event, context: context, delegateDispatcherResult: result)
                })
            case .failed:
                let error = PasswordRequiredError(type: .generalError)
                self.stopTelemetryEvent(event, context: context, error: error)
                MSALLogger.log(level: .error, context: context, format: "password poll success returned status 'failed'")

                return .init(.error(error: error, newState: nil))
            }
        case .passwordError(let apiError):
            let error = apiError.toPasswordRequiredPublicError()
            self.stopTelemetryEvent(event, context: context, error: error)

            MSALLogger.log(level: .error,
                           context: context,
                           format: "Password error calling resetpassword/poll_completion \(error.errorDescription ?? "No error description")")
            let newState = ResetPasswordRequiredState(
                controller: self,
                username: username,
                flowToken: passwordResetToken,
                correlationId: context.correlationId()
            )
            return .init(.error(error: error, newState: newState))
        case .error(let apiError):
            let error = apiError.toPasswordRequiredPublicError()
            self.stopTelemetryEvent(event, context: context, error: error)

            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error calling resetpassword/poll_completion \(error.errorDescription ?? "No error description")")

            return .init(.error(error: error, newState: nil))
        case .unexpectedError:
            let error = PasswordRequiredError(type: .generalError)
            self.stopTelemetryEvent(event, context: context, error: error)

            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error calling resetpassword/poll_completion \(error.errorDescription ?? "No error description")")

            return .init(.error(error: error, newState: nil))
        }
    }
    // swiftlint:enable function_body_length

    private func retryPollCompletion(
        passwordResetToken: String,
        pollInterval: Int,
        retriesRemaining: Int,
        username: String,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext
    ) async -> ResetPasswordSubmitPasswordControllerResponse {
        guard retriesRemaining > 0 else {
            let error = PasswordRequiredError(type: .generalError)
            self.stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "password poll completion did not complete in time")

            return .init(.error(error: error, newState: nil))
        }

        MSALLogger.log(
            level: .info,
            context: context,
            format: "resetpassword: waiting for \(pollInterval) seconds before retrying"
        )

        do {
            try await Task.sleep(nanoseconds: 1_000_000_000 * UInt64(pollInterval))
        } catch {
            // Task.sleep can throw a CancellationError if the Task is cancelled.
            // We don't expect that to ever happen here so we just log it and carry on

            MSALLogger.log(
                level: .error,
                context: context,
                format: "resetpassword: Task.sleep unexpectedly threw an error: \(error). Ignoring..."
            )
        }

        return await doPollCompletionLoop(
            username: username,
            passwordResetToken: passwordResetToken,
            pollInterval: pollInterval,
            retriesRemaining: retriesRemaining - 1,
            event: event,
            context: context
        )
    }
}
// swiftlint:enable file_length
