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

    // 1. Called from Public Interface. Entry Point

    func resetPassword(
        parameters: MSALNativeAuthResetPasswordStartRequestProviderParameters,
        delegate: ResetPasswordStartDelegate
    ) {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdResetPasswordStart, context: parameters.context)

        Task {
            let response = await performStartRequest(parameters: parameters)
            await handleStartResponse(response, event: event, context: parameters.context, delegate: delegate)
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
            delegate.onResetPasswordError(error: .init(type: .browserRequired))
        case .error(let apiError):
            stopTelemetryEvent(event, context: context, error: apiError)
            delegate.onResetPasswordError(error: apiError.error.toResetPasswordStartPublicError())
        case .unexpectedError:
            stopTelemetryEvent(event, context: context)
            delegate.onResetPasswordError(error: .init(type: .generalError))
        }
    }

    // MARK: - Challenge Request handling

    private func performChallengeRequest(flowToken: String, context: MSIDRequestContext) async -> MSALNativeAuthResetPasswordChallengeValidatedResponse {
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
            delegate.onResetPasswordCodeSent(
                newState: ResetPasswordCodeSentState(controller: self, flowToken: challengeToken),
                displayName: displayName,
                codeLength: codeLength
            )
        case .error(let apiError):
            delegate.onResetPasswordError(error: apiError.error.toResetPasswordStartPublicError())
        case .redirect:
            delegate.onResetPasswordError(error: .init(type: .browserRequired))
        case .unexpectedError:
            delegate.onResetPasswordError(error: .init(type: .generalError))
        }
    }

    // 2. Called from ResetPasswordCodeSentState
    func resendCode(context: MSIDRequestContext, delegate: ResetPasswordResendCodeDelegate) {
        delegate.onResetPasswordResendCodeSent(newState: .init(controller: self, flowToken: "password_reset_token"),
                                               displayName: "email@contoso.com",
                                               codeLength: 4)
    }

    // 3. Called from ResetPasswordCodeSentState
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

    // 4. Called from ResetPasswordRequiredState
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
}
