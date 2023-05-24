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
                    config: config,
                    requestConfigurator: MSALNativeAuthRequestConfigurator(),
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

    func resendCode(context: MSIDRequestContext, flowToken: String, delegate: ResetPasswordResendCodeDelegate) async {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdResetPasswordStart, context: context)
        let response = await performChallengeRequest(flowToken: flowToken, context: context)
        handleResendCodeChallengeResponse(response, event: event, context: context, delegate: delegate)
    }

    func submitCode(code: String, context: MSIDRequestContext, delegate: ResetPasswordVerifyCodeDelegate) {
        switch code {
        case "0000":
            delegate.onResetPasswordVerifyCodeError(error: VerifyCodeError(type: .invalidCode),
                                                    newState: .init(controller: self, flowToken: "password_reset_token"))
        case "2222":
            delegate.onResetPasswordVerifyCodeError(error: VerifyCodeError(type: .generalError),
                                                    newState: .init(controller: self, flowToken: "password_reset_token"))
        case "3333":
            delegate.onResetPasswordVerifyCodeError(error: VerifyCodeError(type: .browserRequired),
                                                    newState: .init(controller: self, flowToken: "password_reset_token"))
        default:
            delegate.onPasswordRequired(newState: ResetPasswordRequiredState(controller: self, flowToken: "password_reset_token"))
        }
    }

    func submitPassword(password: String, context: MSIDRequestContext, delegate: ResetPasswordRequiredDelegate) {
        switch password {
        case "redirect":
            delegate.onResetPasswordRequiredError(error: PasswordRequiredError(type: .browserRequired),
                                                  newState: .init(controller: self, flowToken: "password_reset_token"))
        case "generalerror":
            delegate.onResetPasswordRequiredError(error: PasswordRequiredError(type: .generalError),
                                                  newState: .init(controller: self, flowToken: "password_reset_token"))
        case "invalid":
            delegate.onResetPasswordRequiredError(error: PasswordRequiredError(type: .invalidPassword),
                                                  newState: .init(controller: self, flowToken: "password_reset_token"))
        default:
            delegate.onResetPasswordCompleted()
        }

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
            handleChallengeResponse(challengeResponse, event: event, context: context, delegate: delegate)
        case .redirect:
            stopTelemetryEvent(event, context: context)
            DispatchQueue.main.async {
                delegate.onResetPasswordError(error: .init(type: .browserRequired))
            }
        case .error(let apiError):
            stopTelemetryEvent(event, context: context, error: apiError)
            DispatchQueue.main.async {
                delegate.onResetPasswordError(error: apiError.error.toResetPasswordStartPublicError())
            }
        case .unexpectedError:
            stopTelemetryEvent(event, context: context)
            DispatchQueue.main.async {
                delegate.onResetPasswordError(error: .init(type: .generalError))
            }
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
    ) {
        MSALLogger.log(level: .verbose, context: context, format: "Finished resetpassword/challenge request with response: \(response)")
        stopTelemetryEvent(event, context: context)

        switch response {
        case .success(let displayName, let displayType, let codeLength, let challengeToken):
            DispatchQueue.main.async {
                delegate.onResetPasswordCodeSent(
                    newState: ResetPasswordCodeSentState(controller: self, flowToken: challengeToken),
                    displayName: displayName,
                    codeLength: codeLength
                )
            }
        case .error(let error):
            DispatchQueue.main.async {
                delegate.onResetPasswordError(error: error.toResetPasswordStartPublicError())
            }
        case .redirect:
            DispatchQueue.main.async {
                delegate.onResetPasswordError(error: .init(type: .browserRequired, message: "Browser required"))
            }
        case .unexpectedError:
            DispatchQueue.main.async {
                delegate.onResetPasswordError(error: .init(type: .generalError))
            }
        }
    }

    private func handleResendCodeChallengeResponse(
        _ response: MSALNativeAuthResetPasswordChallengeValidatedResponse,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext,
        delegate: ResetPasswordResendCodeDelegate
    ) {
        MSALLogger.log(level: .verbose, context: context, format: "Finished resetpassword/challenge request with response: \(response)")
        stopTelemetryEvent(event, context: context)

        switch response {
        case .success(let displayName, let displayType, let codeLength, let challengeToken):
            DispatchQueue.main.async {
                delegate.onResetPasswordResendCodeSent(
                    newState: ResetPasswordCodeSentState(controller: self, flowToken: challengeToken),
                    displayName: displayName,
                    codeLength: codeLength
                )
            }
        case .error(let error):
            let error = error.toResendCodePublicError()
            stopTelemetryEvent(event, context: context, error: error)
            DispatchQueue.main.async {
                delegate.onResetPasswordResendCodeError(error: error, newState: nil)
            }
        case .redirect,
             .unexpectedError:
            let error = ResendCodeError(type: .generalError)
            DispatchQueue.main.async {
                delegate.onResetPasswordResendCodeError(error: error, newState: nil)
            }
        }
    }

}
