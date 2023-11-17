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

    init(
        config: MSALNativeAuthConfiguration,
        requestProvider: MSALNativeAuthResetPasswordRequestProviding,
        responseValidator: MSALNativeAuthResetPasswordResponseValidating
    ) {
        self.requestProvider = requestProvider
        self.responseValidator = responseValidator

        super.init(clientId: config.clientId)
    }

    convenience init(config: MSALNativeAuthConfiguration) {
        self.init(
            config: config,
            requestProvider: MSALNativeAuthResetPasswordRequestProvider(
                requestConfigurator: MSALNativeAuthRequestConfigurator(config: config),
                telemetryProvider: MSALNativeAuthTelemetryProvider()
            ),
            responseValidator: MSALNativeAuthResetPasswordResponseValidator()
        )
    }

    // MARK: - Internal interface methods

    func resetPassword(parameters: MSALNativeAuthResetPasswordStartRequestProviderParameters) async -> ResetPasswordStartResult {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdResetPasswordStart, context: parameters.context)
        let response = await performStartRequest(parameters: parameters)
        return await handleStartResponse(response, event: event, context: parameters.context)
    }

    func resendCode(passwordResetToken: String, context: MSIDRequestContext) async -> ResetPasswordResendCodeResult {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdResetPasswordResendCode, context: context)
        let response = await performChallengeRequest(passwordResetToken: passwordResetToken, context: context)
        return await handleResendCodeChallengeResponse(response, event: event, context: context)
    }

    func submitCode(code: String, passwordResetToken: String, context: MSIDRequestContext) async -> ResetPasswordVerifyCodeResult {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdResetPasswordSubmitCode, context: context)

        let params = MSALNativeAuthResetPasswordContinueRequestParameters(
            context: context,
            passwordResetToken: passwordResetToken,
            grantType: .oobCode,
            oobCode: code
        )

        let response = await performContinueRequest(parameters: params)
        return await handleSubmitCodeResponse(response, passwordResetToken: passwordResetToken, event: event, context: context)
    }

    func submitPassword(
        password: String,
        passwordSubmitToken: String,
        context: MSIDRequestContext
    ) async -> ResetPasswordRequiredResult {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdResetPasswordSubmit, context: context)

        let params = MSALNativeAuthResetPasswordSubmitRequestParameters(
            context: context,
            passwordSubmitToken: passwordSubmitToken,
            newPassword: password
        )
        let submitRequestResponse = await performSubmitRequest(parameters: params)
        return await handleSubmitPasswordResponse(submitRequestResponse, passwordSubmitToken: passwordSubmitToken, event: event, context: context)
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
                                     event: MSIDTelemetryAPIEvent?,
                                     context: MSIDRequestContext) async -> ResetPasswordStartResult {

        MSALLogger.log(level: .verbose, context: context, format: "Finished resetpassword/start request")

        switch response {
        case .success(let passwordResetToken):
            let challengeResponse = await performChallengeRequest(passwordResetToken: passwordResetToken, context: context)
            return await handleChallengeResponse(challengeResponse, event: event, context: context)
        case .redirect:
            let error = ResetPasswordStartError(type: .browserRequired, message: MSALNativeAuthErrorMessage.browserRequired)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "redirect error in resetpassword/start request \(error.errorDescription ?? "No error description")")
            return .error(error)
        case .error(let apiError):
            let error = apiError.toResetPasswordStartPublicError()
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error in resetpassword/start request \(error.errorDescription ?? "No error description")")
            return .error(error)
        case .unexpectedError:
            let error = ResetPasswordStartError(type: .generalError)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Unexpected error in resetpassword/start request \(error.errorDescription ?? "No error description")")
            return .error(error)
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
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext
    ) async -> ResetPasswordStartResult {
        switch response {
        case .success(let sentTo, let channelTargetType, let codeLength, let challengeToken):
            MSALLogger.log(level: .info, context: context, format: "Successful resetpassword/challenge request")
            stopTelemetryEvent(event, context: context)

            return .codeRequired(
                newState: ResetPasswordCodeRequiredState(controller: self, flowToken: challengeToken, correlationId: context.correlationId()),
                sentTo: sentTo,
                channelTargetType: channelTargetType,
                codeLength: codeLength
            )
        case .error(let apiError):
            let error = apiError.toResetPasswordStartPublicError()
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error in resetpassword/challenge request \(error.errorDescription ?? "No error description")")
            return .error(error)
        case .redirect:
            let error = ResetPasswordStartError(type: .browserRequired, message: MSALNativeAuthErrorMessage.browserRequired)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Redirect error in resetpassword/challenge request \(error.errorDescription ?? "No error description")")
            return .error(error)
        case .unexpectedError:
            let error = ResetPasswordStartError(type: .generalError)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Unexpected error in resetpassword/challenge request \(error.errorDescription ?? "No error description")")
            return .error(error)
        }
    }

    private func handleResendCodeChallengeResponse(
        _ response: MSALNativeAuthResetPasswordChallengeValidatedResponse,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext
    ) async -> ResetPasswordResendCodeResult {
        switch response {
        case .success(let sentTo, let channelTargetType, let codeLength, let challengeToken):
            stopTelemetryEvent(event, context: context)
            MSALLogger.log(level: .info, context: context, format: "Successful resetpassword/challenge (resend code) request")
            return .codeRequired(
                newState: ResetPasswordCodeRequiredState(controller: self, flowToken: challengeToken, correlationId: context.correlationId()),
                sentTo: sentTo,
                channelTargetType: channelTargetType,
                codeLength: codeLength
            )
        case .error(let apiError):
            let error = apiError.toResendCodePublicError()
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error in resetpassword/challenge request (resend code) \(error.errorDescription ?? "No error description")")
            return .error(error: error, newState: nil)
        case .redirect,
                .unexpectedError:
            let error = ResendCodeError()
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error in resetpassword/challenge request (resend code) \(error.errorDescription ?? "No error description")")
            return .error(error: error, newState: nil)
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
        passwordResetToken: String,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext
    ) async -> ResetPasswordVerifyCodeResult {
        switch response {
        case .success(let passwordSubmitToken):
            stopTelemetryEvent(event, context: context)
            MSALLogger.log(level: .info, context: context, format: "Successful resetpassword/continue request")
            return .passwordRequired(newState: ResetPasswordRequiredState(controller: self, flowToken: passwordSubmitToken, correlationId: context.correlationId()))
        case .error(let apiError):
            let error = apiError.toVerifyCodePublicError()
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error in resetpassword/continue request \(error.errorDescription ?? "No error description")")
            return .error(error: error, newState: nil)
        case .unexpectedError:
            let error = VerifyCodeError(type: .generalError)
            self.stopTelemetryEvent(event, context: context, error: error)

            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error calling resetpassword/continue \(error.errorDescription ?? "No error description")")

            return .error(error: error, newState: nil)
        case .invalidOOB:
            let error = VerifyCodeError(type: .invalidCode)
            self.stopTelemetryEvent(event, context: context, error: error)

            MSALLogger.log(level: .error,
                           context: context,
                           format: "Invalid code error calling resetpassword/continue \(error.errorDescription ?? "No error description")")

            let state = ResetPasswordCodeRequiredState(controller: self, flowToken: passwordResetToken, correlationId: context.correlationId())
            return .error(error: error, newState: state)
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
        passwordSubmitToken: String,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext
    ) async -> ResetPasswordRequiredResult {
        MSALLogger.log(level: .info, context: context, format: "Finished resetpassword/submit request")

        switch response {
        case .success(let passwordResetToken, let pollInterval):
            return await doPollCompletionLoop(
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

            return .error(error: error, newState: ResetPasswordRequiredState(controller: self, flowToken: passwordSubmitToken, correlationId: context.correlationId()))
        case .error(let apiError):
            let error = apiError.toPasswordRequiredPublicError()
            self.stopTelemetryEvent(event, context: context, error: error)

            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error calling resetpassword/submit \(error.errorDescription ?? "No error description")")

            return .error(error: error, newState: nil)
        case .unexpectedError:
            let error = PasswordRequiredError(type: .generalError)
            self.stopTelemetryEvent(event, context: context, error: error)

            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error calling resetpassword/submit \(error.errorDescription ?? "No error description")")

            return .error(error: error, newState: nil)
        }
    }

    // MARK: - Poll Completion Request handling

    private func doPollCompletionLoop(
        passwordResetToken: String,
        pollInterval: Int,
        retriesRemaining: Int,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext
    ) async -> ResetPasswordRequiredResult {
        MSALLogger.log(level: .verbose, context: context, format: "performing poll completion request...")

        let pollCompletionResponse = await performPollCompletionRequest(
            passwordResetToken: passwordResetToken,
            context: context
        )

        MSALLogger.log(level: .verbose, context: context, format: "handling poll completion response...")

        return await handlePollCompletionResponse(
            pollCompletionResponse,
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

    private func handlePollCompletionResponse(
        _ response: MSALNativeAuthResetPasswordPollCompletionValidatedResponse,
        pollInterval: Int,
        retriesRemaining: Int,
        passwordResetToken: String,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext
    ) async -> ResetPasswordRequiredResult {
        MSALLogger.log(level: .info, context: context, format: "Finished resetpassword/poll_completion")

        switch response {
        case .success(let status):
            switch status {
            case .inProgress,
                 .notStarted:

                return await retryPollCompletion(
                    passwordResetToken: passwordResetToken,
                    pollInterval: pollInterval,
                    retriesRemaining: retriesRemaining,
                    event: event,
                    context: context
                )
            case .succeeded:
                stopTelemetryEvent(event, context: context)

                return .completed
            case .failed:
                let error = PasswordRequiredError(type: .generalError)
                self.stopTelemetryEvent(event, context: context, error: error)
                MSALLogger.log(level: .error, context: context, format: "password poll success returned status 'failed'")

                return .error(error: error, newState: nil)
            }
        case .passwordError(let apiError):
            let error = apiError.toPasswordRequiredPublicError()
            self.stopTelemetryEvent(event, context: context, error: error)

            MSALLogger.log(level: .error,
                           context: context,
                           format: "Password error calling resetpassword/poll_completion \(error.errorDescription ?? "No error description")")

            return .error(error: error, newState: ResetPasswordRequiredState(controller: self, flowToken: passwordResetToken, correlationId: context.correlationId()))
        case .error(let apiError):
            let error = apiError.toPasswordRequiredPublicError()
            self.stopTelemetryEvent(event, context: context, error: error)

            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error calling resetpassword/poll_completion \(error.errorDescription ?? "No error description")")

            return .error(error: error, newState: nil)
        case .unexpectedError:
            let error = PasswordRequiredError(type: .generalError)
            self.stopTelemetryEvent(event, context: context, error: error)

            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error calling resetpassword/poll_completion \(error.errorDescription ?? "No error description")")

            return .error(error: error, newState: nil)
        }
    }

    private func retryPollCompletion(
        passwordResetToken: String,
        pollInterval: Int,
        retriesRemaining: Int,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext
    ) async -> ResetPasswordRequiredResult {
        guard retriesRemaining > 0 else {
            let error = PasswordRequiredError(type: .generalError)
            self.stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "password poll completion did not complete in time")

            return .error(error: error, newState: nil)
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
            passwordResetToken: passwordResetToken,
            pollInterval: pollInterval,
            retriesRemaining: retriesRemaining - 1,
            event: event,
            context: context
        )
    }
}
// swiftlint:enable file_length
