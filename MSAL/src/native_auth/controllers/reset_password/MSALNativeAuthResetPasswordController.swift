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
    private let requestProvider: MSALNativeAuthResetPasswordRequestProviding
    private let responseValidator: MSALNativeAuthResetPasswordResponseValidating
    private let config: MSALNativeAuthConfiguration

    init(
        config: MSALNativeAuthConfiguration,
        requestProvider: MSALNativeAuthResetPasswordRequestProviding,
        responseValidator: MSALNativeAuthResetPasswordResponseValidating,
        cacheAccessor: MSALNativeAuthCacheInterface
    ) {
        self.requestProvider = requestProvider
        self.responseValidator = responseValidator
        self.config = config

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
                cacheAccessor: MSALNativeAuthCacheAccessor()
            )
        }

    // Internal interface methods

    func resetPassword(
        parameters: MSALNativeAuthResetPasswordStartRequestProviderParameters,
        delegate: ResetPasswordStartDelegate
    ) async {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdResetPasswordStart, context: parameters.context)
        let response = await performStartRequest(parameters: parameters)
        await handleStartResponse(response, event: event, context: parameters.context, delegate: delegate)
    }

    func resendCode(
        flowToken: String,
        context: MSIDRequestContext,
        delegate: ResetPasswordResendCodeDelegate
    ) async {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdResetPasswordResendCode, context: context)
        let response = await performChallengeRequest(flowToken: flowToken, context: context)
        await handleResendCodeChallengeResponse(response, event: event, context: context, delegate: delegate)
    }

    func submitCode(
        code: String,
        flowToken: String,
        context: MSIDRequestContext,
        delegate: ResetPasswordVerifyCodeDelegate
    ) async {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdResetPasswordVerifyCode, context: context)

        let params = MSALNativeAuthResetPasswordContinueRequestParameters(
            context: context,
            passwordResetToken: flowToken,
            grantType: .oobCode,
            oobCode: code
        )

        let response = await performContinueRequest(parameters: params)
        await handleSubmitCodeResponse(response, flowToken: flowToken, event: event, context: context, delegate: delegate)
    }

    func submitPassword(
        password: String,
        flowToken: String,
        context: MSIDRequestContext,
        delegate: ResetPasswordRequiredDelegate
    ) async {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdResetPasswordSubmit, context: context)

        let params = MSALNativeAuthResetPasswordSubmitRequestParameters(
            context: context,
            passwordSubmitToken: flowToken,
            newPassword: password
        )
        let submitRequestResponse = await performSubmitRequest(parameters: params)
        await handleSubmitPasswordResponse(submitRequestResponse, flowToken: flowToken, event: event, context: context, delegate: delegate)
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
                                     context: MSIDRequestContext,
                                     delegate: ResetPasswordStartDelegate) async {

        MSALLogger.log(level: .verbose, context: context, format: "Finished resetpassword/start request with result: \(response)")

        switch response {
        case .success(let flowToken):
            let challengeResponse = await performChallengeRequest(flowToken: flowToken, context: context)
            await handleChallengeResponse(challengeResponse, event: event, context: context, delegate: delegate)
        case .redirect:
            let error = ResetPasswordStartError(type: .browserRequired, message: MSALNativeAuthErrorMessage.browserRequired)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "redirect error in resetpassword/start request \(error)")
            await delegate.onResetPasswordError(error: error)
        case .error(let apiError):
            let error = apiError.toResetPasswordStartPublicError()
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "Error in resetpassword/start request \(error)")
            await delegate.onResetPasswordError(error: error)
        case .unexpectedError:
            let error = ResetPasswordStartError(type: .generalError)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "Unexpected error in resetpassword/start request \(error)")
            await delegate.onResetPasswordError(error: error)
        }
    }

    // MARK: - Challenge Request handling

    private func performChallengeRequest(
        flowToken: String,
        context: MSIDRequestContext
    ) async -> MSALNativeAuthResetPasswordChallengeValidatedResponse {
        let request: MSIDHttpRequest

        do {
            request = try requestProvider.challenge(token: flowToken, context: context)
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
        context: MSIDRequestContext,
        delegate: ResetPasswordStartDelegate
    ) async {
        switch response {
        case .success(let sentTo, let channelTargetType, let codeLength, let challengeToken):
            MSALLogger.log(level: .info, context: context, format: "Successful resetpassword/challenge request")
            stopTelemetryEvent(event, context: context)

            await delegate.onResetPasswordCodeRequired(
                newState: ResetPasswordCodeRequiredState(controller: self, flowToken: challengeToken),
                sentTo: sentTo,
                channelTargetType: channelTargetType,
                codeLength: codeLength
            )
        case .error(let apiError):
            let error = apiError.toResetPasswordStartPublicError()
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "Error in resetpassword/challenge request \(error)")
            await delegate.onResetPasswordError(error: error)
        case .redirect:
            let error = ResetPasswordStartError(type: .browserRequired, message: MSALNativeAuthErrorMessage.browserRequired)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "Redirect error in resetpassword/challenge request \(error)")
            await delegate.onResetPasswordError(error: error)
        case .unexpectedError:
            let error = ResetPasswordStartError(type: .generalError)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "Unexpected error in resetpassword/challenge request \(error)")
            await delegate.onResetPasswordError(error: error)
        }
    }

    private func handleResendCodeChallengeResponse(
        _ response: MSALNativeAuthResetPasswordChallengeValidatedResponse,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext,
        delegate: ResetPasswordResendCodeDelegate
    ) async {
        MSALLogger.log(level: .verbose, context: context, format: "Finished resetpassword/challenge request with response: \(response)")
        stopTelemetryEvent(event, context: context)

        switch response {
        case .success(let sentTo, let channelTargetType, let codeLength, let challengeToken):
            await delegate.onResetPasswordResendCodeRequired(
                newState: ResetPasswordCodeRequiredState(controller: self, flowToken: challengeToken),
                sentTo: sentTo,
                channelTargetType: channelTargetType,
                codeLength: codeLength
            )
        case .error(let error):
            let error = error.toResendCodePublicError()
            stopTelemetryEvent(event, context: context, error: error)
            await delegate.onResetPasswordResendCodeError(error: error, newState: nil)
        case .redirect,
                .unexpectedError:
            let error = ResendCodeError()
            stopTelemetryEvent(event, context: context, error: error)
            await delegate.onResetPasswordResendCodeError(error: error, newState: nil)
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
            flowToken: String,
            event: MSIDTelemetryAPIEvent?,
            context: MSIDRequestContext,
            delegate: ResetPasswordVerifyCodeDelegate
    ) async {
        MSALLogger.log(level: .info, context: context, format: "Finished resetpassword/continue request with response: \(response)")

        switch response {
        case .success(let passwordSubmitToken):
            stopTelemetryEvent(event, context: context)

            await delegate.onPasswordRequired(
                newState: ResetPasswordRequiredState(controller: self, flowToken: passwordSubmitToken)
            )
        case .error(let apiError):
            let error = apiError.toVerifyCodePublicError()
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "Error in resetpassword/continue request \(error)")
            await delegate.onResetPasswordVerifyCodeError(error: error, newState: nil)
        case .unexpectedError:
            let error = VerifyCodeError(type: .generalError)
            self.stopTelemetryEvent(event, context: context, error: error)

            MSALLogger.log(level: .error, context: context, format: "Error calling resetpassword/continue \(error)")

            await delegate.onResetPasswordVerifyCodeError(error: error, newState: nil)
        case .invalidOOB:
            let error = VerifyCodeError(type: .invalidCode)
            self.stopTelemetryEvent(event, context: context, error: error)

            await delegate.onResetPasswordVerifyCodeError(
                error: error,
                newState: ResetPasswordCodeRequiredState(
                    controller: self,
                    flowToken: flowToken
                )
            )
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
            flowToken: String,
            event: MSIDTelemetryAPIEvent?,
            context: MSIDRequestContext,
            delegate: ResetPasswordRequiredDelegate
    ) async {
        MSALLogger.log(level: .info, context: context, format: "Finished resetpassword/submit request with response: \(response)")

        switch response {
        case .success(let passwordResetToken, let pollInterval):
            await doPollCompletionLoop(
                passwordResetToken: passwordResetToken,
                pollInterval: pollInterval,
                event: event,
                context: context,
                delegate: delegate
            )
        case .passwordError(let apiError):
            let error = apiError.toPasswordRequiredPublicError()
            self.stopTelemetryEvent(event, context: context, error: error)

            await delegate.onResetPasswordRequiredError(
                error: error,
                newState: ResetPasswordRequiredState(controller: self, flowToken: flowToken)
            )
        case .error(let apiError):
            let error = apiError.toPasswordRequiredPublicError()
            self.stopTelemetryEvent(event, context: context, error: error)

            MSALLogger.log(level: .error, context: context, format: "Error calling resetpassword/submit \(error)")

            await delegate.onResetPasswordRequiredError(error: error, newState: nil)
        case .unexpectedError:
            let error = PasswordRequiredError(type: .generalError)
            self.stopTelemetryEvent(event, context: context, error: error)

            MSALLogger.log(level: .error, context: context, format: "Error calling resetpassword/submit \(error)")

            await delegate.onResetPasswordRequiredError(error: error, newState: nil)
        }
    }

    // MARK: - Poll Completion Request handling

    private func doPollCompletionLoop(
        passwordResetToken: String,
        pollInterval: Int,
        retriesRemaining: Int = 5,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext,
        delegate: ResetPasswordRequiredDelegate
    ) async {
            MSALLogger.log(level: .verbose, context: context, format: "performing poll completion request...")

            let pollCompletionResponse = await performPollCompletionRequest(
                passwordResetToken: passwordResetToken,
                context: context
            )

            MSALLogger.log(level: .verbose, context: context, format: "handling poll completion response...")

            await handlePollCompletionResponse(
                pollCompletionResponse,
                pollInterval: pollInterval,
                retriesRemaining: retriesRemaining,
                passwordResetToken: passwordResetToken,
                event: event,
                context: context,
                delegate: delegate
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
            context: MSIDRequestContext,
            delegate: ResetPasswordRequiredDelegate
    ) async {
        MSALLogger.log(level: .info, context: context, format: "Finished resetpassword/poll_completion with response: \(response)")

        switch response {
        case .success(let status):
            switch status {
            case .inProgress,
                 .notStarted:

                await retryPollCompletion(
                    passwordResetToken: passwordResetToken,
                    pollInterval: pollInterval,
                    retriesRemaining: retriesRemaining,
                    event: event,
                    context: context,
                    delegate: delegate
                )
            case .succeeded:
                stopTelemetryEvent(event, context: context)

                await delegate.onResetPasswordCompleted()
            case .failed:
                let error = PasswordRequiredError(type: .generalError)
                self.stopTelemetryEvent(event, context: context, error: error)
                MSALLogger.log(level: .error, context: context, format: "password poll success returned status 'failed'")

                await delegate.onResetPasswordRequiredError(error: error, newState: nil)
            }
        case .passwordError(let apiError):
            let error = apiError.toPasswordRequiredPublicError()
            self.stopTelemetryEvent(event, context: context, error: error)

            await delegate.onResetPasswordRequiredError(
                error: error,
                newState: ResetPasswordRequiredState(controller: self, flowToken: passwordResetToken)
            )
        case .error(let apiError):
            let error = apiError.toPasswordRequiredPublicError()
            self.stopTelemetryEvent(event, context: context, error: error)

            MSALLogger.log(level: .error, context: context, format: "Error calling resetpassword/poll_completion \(error)")

            await delegate.onResetPasswordRequiredError(error: error, newState: nil)
        case .unexpectedError:
            let error = PasswordRequiredError(type: .generalError)
            self.stopTelemetryEvent(event, context: context, error: error)

            MSALLogger.log(level: .error, context: context, format: "Error calling resetpassword/poll_completion \(error)")

            await delegate.onResetPasswordRequiredError(error: error, newState: nil)
        }
    }

    private func retryPollCompletion(
        passwordResetToken: String,
        pollInterval: Int,
        retriesRemaining: Int,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext,
        delegate: ResetPasswordRequiredDelegate
    ) async {
        guard retriesRemaining > 0 else {
            let error = PasswordRequiredError(type: .generalError)
            self.stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "password poll completion did not complete in time")

            await delegate.onResetPasswordRequiredError(error: error, newState: nil)

            return
        }

        MSALLogger.log(
            level: .info,
            context: context,
            format: "resetpassword: waiting for \(pollInterval) seconds before retrying"
        )

        try? await Task.sleep(nanoseconds: 1_000_000_000 * UInt64(pollInterval))

        await doPollCompletionLoop(
            passwordResetToken: passwordResetToken,
            pollInterval: pollInterval,
            retriesRemaining: retriesRemaining - 1,
            event: event,
            context: context,
            delegate: delegate)
    }
}
// swiftlint:enable file_length
