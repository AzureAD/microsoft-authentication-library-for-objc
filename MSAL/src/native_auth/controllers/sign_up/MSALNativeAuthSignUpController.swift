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

    // MARK: - Init

    init(
        config: MSALNativeAuthConfiguration,
        requestProvider: MSALNativeAuthSignUpRequestProviding,
        responseValidator: MSALNativeAuthSignUpResponseValidating
    ) {
        self.requestProvider = requestProvider
        self.responseValidator = responseValidator
        super.init(clientId: config.clientId)
    }

    convenience init(config: MSALNativeAuthConfiguration) {
        self.init(
            config: config,
            requestProvider: MSALNativeAuthSignUpRequestProvider(
                requestConfigurator: MSALNativeAuthRequestConfigurator(config: config),
                telemetryProvider: MSALNativeAuthTelemetryProvider()
            ),
            responseValidator: MSALNativeAuthSignUpResponseValidator()
        )
    }

    // MARK: - Internal

    func signUpStartPassword(parameters: MSALNativeAuthSignUpStartRequestProviderParameters, delegate: SignUpPasswordStartDelegate) async {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdSignUpPasswordStart, context: parameters.context)
        let result = await performAndValidateStartRequest(parameters: parameters)
        await handleSignUpStartPasswordResult(result, event: event, context: parameters.context, delegate: delegate)
    }

    func signUpStartCode(parameters: MSALNativeAuthSignUpStartRequestProviderParameters, delegate: SignUpStartDelegate) async {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdSignUpCodeStart, context: parameters.context)
        let result = await performAndValidateStartRequest(parameters: parameters)
        await handleSignUpStartCodeResult(result, event: event, context: parameters.context, delegate: delegate)
    }

    func resendCode(context: MSIDRequestContext, signUpToken: String, delegate: SignUpResendCodeDelegate) async {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdSignUpResendCode, context: context)
        let challengeResult = await performAndValidateChallengeRequest(signUpToken: signUpToken, context: context)
        handleResendCodeResult(challengeResult, event: event, context: context, delegate: delegate)
    }

    func submitCode(
        _ code: String,
        signUpToken: String,
        context: MSIDRequestContext,
        delegate: SignUpVerifyCodeDelegate
    ) async {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdSignUpSubmitCode, context: context)
        let params = MSALNativeAuthSignUpContinueRequestProviderParams(grantType: .oobCode, signUpToken: signUpToken, oobCode: code, context: context)

        let result = await performAndValidateContinueRequest(parameters: params)
        await handleSubmitCodeResult(result, event: event, context: context, delegate: delegate)
    }

    func submitPassword(
        _ password: String,
        signUpToken: String,
        context: MSIDRequestContext,
        delegate: SignUpPasswordRequiredDelegate
    ) async {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdSignUpSubmitPassword, context: context)

        let params = MSALNativeAuthSignUpContinueRequestProviderParams(
            grantType: .password,
            signUpToken: signUpToken,
            password: password,
            context: context
        )
        let continueRequestResult = await performAndValidateContinueRequest(parameters: params)
        handleSubmitPasswordResult(continueRequestResult, event: event, context: context, delegate: delegate)
    }

    func submitAttributes(
        _ attributes: [String: Any],
        signUpToken: String,
        context: MSIDRequestContext,
        delegate: SignUpAttributesRequiredDelegate
    ) async {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdSignUpSubmitAttributes, context: context)
        let params = MSALNativeAuthSignUpContinueRequestProviderParams(grantType: .attributes, signUpToken: signUpToken, context: context)

        let result = await performAndValidateContinueRequest(parameters: params)
        handleSubmitAttributesResult(result, event: event, context: context, delegate: delegate)
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
            return .unexpectedError
        }

        MSALLogger.log(level: .info, context: parameters.context, format: "Performing signup/start request")

        let response: Result<MSALNativeAuthSignUpStartResponse, Error> = await performRequest(request, context: parameters.context)
        return responseValidator.validate(response, with: parameters.context)
    }

    private func handleSignUpStartPasswordResult(
        _ result: MSALNativeAuthSignUpStartValidatedResponse,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext,
        delegate: SignUpPasswordStartDelegate
    ) async {
        switch result {
        case .verificationRequired(let signUpToken):
            MSALLogger.log(
                level: .info,
                context: context,
                format: "verification_required received from signup/start with password request"
            )
            let challengeResult = await performAndValidateChallengeRequest(signUpToken: signUpToken, context: context)
            handleSignUpPasswordChallengeResult(challengeResult, event: event, context: context, delegate: delegate)
        case .redirect:
            let error = SignUpPasswordStartError(type: .browserRequired)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "redirect error in signup/start with password request \(error)")
            DispatchQueue.main.async { delegate.onSignUpPasswordError(error: error) }
        case .error(let apiError):
            let error = apiError.toSignUpStartPasswordPublicError()
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "Error in signup/start with password request \(error)")
            DispatchQueue.main.async { delegate.onSignUpPasswordError(error: error) }
        case .unexpectedError:
            let error = SignUpPasswordStartError(type: .generalError)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "Unexpected error in signup/start with password request \(error)")
            DispatchQueue.main.async { delegate.onSignUpPasswordError(error: error) }
        }
    }

    private func handleSignUpStartCodeResult(
        _ result: MSALNativeAuthSignUpStartValidatedResponse,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext,
        delegate: SignUpStartDelegate
    ) async {
        switch result {
        case .verificationRequired(let signUpToken):
            MSALLogger.log(
                level: .info,
                context: context,
                format: "verification_required received from signup/start with code request"
            )
            let challengeResult = await performAndValidateChallengeRequest(signUpToken: signUpToken, context: context)
            handleSignUpCodeChallengeResult(challengeResult, event: event, context: context, delegate: delegate)
        case .redirect:
            let error = SignUpStartError(type: .browserRequired)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "Redirect error in signup/start with code request \(error)")
            DispatchQueue.main.async { delegate.onSignUpError(error: error) }
        case .error(let apiError):
            let error = apiError.toSignUpStartPublicError()
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "Error in signup/start with code request \(error)")
            DispatchQueue.main.async { delegate.onSignUpError(error: error) }
        case .unexpectedError:
            let error = SignUpStartError(type: .generalError)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "Unexpected error in signup/start with code request \(error)")
            DispatchQueue.main.async { delegate.onSignUpError(error: error) }
        }
    }

    // MARK: - Challenge Request handling

    private func performAndValidateChallengeRequest(
        signUpToken: String,
        context: MSIDRequestContext
    ) async -> MSALNativeAuthSignUpChallengeValidatedResponse {
        let request: MSIDHttpRequest

        do {
            request = try requestProvider.challenge(token: signUpToken, context: context)
        } catch {
            MSALLogger.log(level: .error, context: context, format: "Error while creating Challenge Request: \(error)")
            return .unexpectedError
        }

        MSALLogger.log(level: .info, context: context, format: "Performing signup/challenge request")

        let result: Result<MSALNativeAuthSignUpChallengeResponse, Error> = await performRequest(request, context: context)
        return responseValidator.validate(result, with: context)
    }

    private func handleSignUpPasswordChallengeResult(
        _ result: MSALNativeAuthSignUpChallengeValidatedResponse,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext,
        delegate: SignUpPasswordStartDelegate
    ) {
        switch result {
        case .successOOB(let sentTo, let challengeType, let codeLength, let challengeToken):
            MSALLogger.log(level: .info, context: context, format: "Successful signup/challenge password request")
            stopTelemetryEvent(event, context: context)
            DispatchQueue.main.async {
                delegate.onSignUpCodeRequired(
                    newState: SignUpCodeRequiredState(controller: self, flowToken: challengeToken),
                    sentTo: sentTo,
                    channelTargetType: challengeType,
                    codeLength: codeLength
                )
            }
        case .error(let apiError):
            let error = apiError.toSignUpPasswordStartPublicError()
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "Error in signup/challenge password request \(error)")
            DispatchQueue.main.async { delegate.onSignUpPasswordError(error: error) }
        case .redirect:
            let error = SignUpPasswordStartError(type: .browserRequired)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "Redirect error in signup/challenge password request \(error)")
            DispatchQueue.main.async { delegate.onSignUpPasswordError(error: error) }
        case .unexpectedError,
             .successPassword:
            let error = SignUpPasswordStartError(type: .generalError)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "Unexpected error in signup/challenge password request \(error)")
            DispatchQueue.main.async { delegate.onSignUpPasswordError(error: error) }
        }
    }

    private func handleSignUpCodeChallengeResult(
        _ result: MSALNativeAuthSignUpChallengeValidatedResponse,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext,
        delegate: SignUpStartDelegate
    ) {
        switch result {
        case .successOOB(let sentTo, let challengeType, let codeLength, let challengeToken):
            MSALLogger.log(level: .info, context: context, format: "Successful signup/challenge code request")
            stopTelemetryEvent(event, context: context)
            DispatchQueue.main.async {
                delegate.onSignUpCodeRequired(
                    newState: SignUpCodeRequiredState(controller: self, flowToken: challengeToken),
                    sentTo: sentTo,
                    channelTargetType: challengeType,
                    codeLength: codeLength
                )
            }
        case .error(let apiError):
            let error = apiError.toSignUpStartPublicError()
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "Error in signup/challenge code request \(error)")
            DispatchQueue.main.async { delegate.onSignUpError(error: error) }
        case .redirect:
            let error = SignUpStartError(type: .browserRequired)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "Redirect error in signup/challenge code request \(error)")
            DispatchQueue.main.async { delegate.onSignUpError(error: error) }
        case .unexpectedError,
             .successPassword:
            let error = SignUpStartError(type: .generalError)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "Unexpected error in signup/challenge code request \(error)")
            DispatchQueue.main.async { delegate.onSignUpError(error: error) }
        }
    }

    private func handleResendCodeResult(
        _ result: MSALNativeAuthSignUpChallengeValidatedResponse,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext,
        delegate: SignUpResendCodeDelegate
    ) {
        switch result {
        case .successOOB(let sentTo, let challengeType, let codeLength, let challengeToken):
            MSALLogger.log(level: .info, context: context, format: "Successful signup/challenge resendCode request")
            stopTelemetryEvent(event, context: context)
            DispatchQueue.main.async {
                delegate.onSignUpResendCodeCodeRequired(
                    newState: SignUpCodeRequiredState(controller: self, flowToken: challengeToken),
                    sentTo: sentTo,
                    channelTargetType: challengeType,
                    codeLength: codeLength
                )
            }
        case .error(let apiError):
            let error = apiError.toResendCodePublicError()
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "Error in signup/challenge resendCode request \(error)")
            DispatchQueue.main.async { delegate.onSignUpResendCodeError(error: error) }
        case .redirect,
             .unexpectedError,
             .successPassword:
            let error = ResendCodeError()
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "Unexpected error in signup/challenge resendCode request \(error)")
            DispatchQueue.main.async { delegate.onSignUpResendCodeError(error: error) }
        }
    }

    private func handlePerformChallengeAfterCredentialRequiredError(
        _ result: MSALNativeAuthSignUpChallengeValidatedResponse,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext,
        delegate: SignUpVerifyCodeDelegate
    ) {
        switch result {
        case .successPassword(let token):
            MSALLogger.log(level: .info, context: context, format: "Successful signup/challenge request after credential_required")
            DispatchQueue.main.async {
                if let function = delegate.onSignUpPasswordRequired {
                    self.stopTelemetryEvent(event, context: context)
                    function(SignUpPasswordRequiredState(controller: self, flowToken: token))
                } else {
                    MSALLogger.log(level: .error, context: context, format: "onSignUpPasswordRequired() is not implemented by developer")
                    let error = VerifyCodeError(type: .generalError, message: MSALNativeAuthErrorMessage.delegateNotImplemented)
                    self.stopTelemetryEvent(event, context: context, error: error)
                    delegate.onSignUpVerifyCodeError(error: error, newState: nil)
                }
            }
        case .redirect:
            let error = VerifyCodeError(type: .browserRequired)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "Redirect error in signup/challenge request after credential_required \(error)")
            DispatchQueue.main.async { delegate.onSignUpVerifyCodeError(error: error, newState: nil) }
        case .error,
             .unexpectedError,
             .successOOB:
            let error = VerifyCodeError(type: .generalError)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "Unexpected error in signup/challenge request after credential_required \(error)")
            DispatchQueue.main.async { delegate.onSignUpVerifyCodeError(error: error, newState: nil) }
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
            return .unexpectedError
        }

        MSALLogger.log(level: .info, context: parameters.context, format: "Performing signup/continue request")

        let result: Result<MSALNativeAuthSignUpContinueResponse, Error> = await performRequest(request, context: parameters.context)
        return responseValidator.validate(result, with: parameters.context)
    }

    private func handleSubmitCodeResult(
        _ result: MSALNativeAuthSignUpContinueValidatedResponse,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext,
        delegate: SignUpVerifyCodeDelegate
    ) async {
        switch result {
        case .success(let slt):
            // TODO: Handle slt
            MSALLogger.log(level: .info, context: context, format: "Successful signup/continue request")
            stopTelemetryEvent(event, context: context)
            DispatchQueue.main.async { delegate.onSignUpCompleted() }
        case .invalidUserInput(_, let token):
            MSALLogger.log(level: .error, context: context, format: "invalid_user_input error in signup/continue request")

            let error = VerifyCodeError(type: .invalidCode)
            stopTelemetryEvent(event, context: context, error: error)
            DispatchQueue.main.async {
                delegate.onSignUpVerifyCodeError(error: error, newState: SignUpCodeRequiredState(controller: self, flowToken: token))
            }
        case .credentialRequired(let token):
            MSALLogger.log(level: .verbose, context: context, format: "credential_required received in signup/continue request")

            let result = await performAndValidateChallengeRequest(signUpToken: token, context: context)
            handlePerformChallengeAfterCredentialRequiredError(result, event: event, context: context, delegate: delegate)
        case .attributesRequired(let token):
            MSALLogger.log(level: .verbose, context: context, format: "attributes_required received in signup/continue request")

            DispatchQueue.main.async {
                if let function = delegate.onSignUpAttributesRequired {
                    self.stopTelemetryEvent(event, context: context)
                    function(SignUpAttributesRequiredState(controller: self, flowToken: token))
                } else {
                    MSALLogger.log(level: .error, context: context, format: "onSignUpAttributesRequired() is not implemented by developer")
                    let error = VerifyCodeError(type: .generalError, message: MSALNativeAuthErrorMessage.delegateNotImplemented)
                    self.stopTelemetryEvent(event, context: context, error: error)
                    delegate.onSignUpVerifyCodeError(error: error, newState: nil)
                }
            }
        case .error(let apiError):
            let error = apiError.toVerifyCodePublicError()
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "Error in signup/continue request \(error)")
            DispatchQueue.main.async { delegate.onSignUpVerifyCodeError(error: error, newState: nil) }
        case .unexpectedError:
            let error = VerifyCodeError(type: .generalError)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "Unexpected error in signup/continue request \(error)")
            DispatchQueue.main.async { delegate.onSignUpVerifyCodeError(error: error, newState: nil) }
        }
    }

    private func handleSubmitPasswordResult(
        _ result: MSALNativeAuthSignUpContinueValidatedResponse,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext,
        delegate: SignUpPasswordRequiredDelegate
    ) {
        switch result {
        case .success(let slt):
            // TODO: Handle slt
            MSALLogger.log(level: .info, context: context, format: "Successful signup/continue submitPassword request")
            stopTelemetryEvent(event, context: context)
            DispatchQueue.main.async { delegate.onSignUpCompleted() }
        case .invalidUserInput(let error, let token):
            let error = error.toPasswordRequiredPublicError()
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "invalid_user_input error in signup/continue submitPassword request \(error)")
            DispatchQueue.main.async {
                delegate.onSignUpPasswordRequiredError(error: error, newState: SignUpPasswordRequiredState(controller: self, flowToken: token))
            }
        case .attributesRequired(let token):
            MSALLogger.log(level: .verbose, context: context, format: "attributes_required received in signup/continue submitPassword request")
            DispatchQueue.main.async {
                if let function = delegate.onSignUpAttributesRequired {
                    self.stopTelemetryEvent(event, context: context)
                    function(SignUpAttributesRequiredState(controller: self, flowToken: token))
                } else {
                    MSALLogger.log(level: .error, context: context, format: "onSignUpAttributesRequired() is not implemented by developer")
                    let error = PasswordRequiredError(type: .generalError, message: MSALNativeAuthErrorMessage.delegateNotImplemented)
                    self.stopTelemetryEvent(event, context: context, error: error)
                    delegate.onSignUpPasswordRequiredError(error: error, newState: nil)
                }
            }
        case .error(let apiError):
            let error = apiError.toPasswordRequiredPublicError()
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "Error in signup/continue submitPassword request \(error)")
            DispatchQueue.main.async { delegate.onSignUpPasswordRequiredError(error: error, newState: nil) }
        case .credentialRequired,
             .unexpectedError:
            let error = PasswordRequiredError(type: .generalError)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "Unexpected error in signup/continue submitPassword request \(error)")
            DispatchQueue.main.async { delegate.onSignUpPasswordRequiredError(error: error, newState: nil) }
        }
    }

    private func handleSubmitAttributesResult(
        _ result: MSALNativeAuthSignUpContinueValidatedResponse,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext,
        delegate: SignUpAttributesRequiredDelegate
    ) {
        switch result {
        case .success(let slt):
            // TODO: Handle slt
            MSALLogger.log(level: .info, context: context, format: "Successful signup/continue submitAttributes request")
            stopTelemetryEvent(event, context: context)
            DispatchQueue.main.async { delegate.onSignUpCompleted() }
        case .invalidUserInput(_, let token):
            let error = AttributesRequiredError(type: .invalidAttributes)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "invalid_user_input error in signup/continue submitAttributes request \(error)")
            DispatchQueue.main.async {
                delegate.onSignUpAttributesRequiredError(error: error, newState: SignUpAttributesRequiredState(controller: self, flowToken: token))
            }
        case .error(let apiError):
            let error = apiError.toAttributesRequiredPublicError()
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "Error in signup/continue submitAttributes request \(error)")
            DispatchQueue.main.async { delegate.onSignUpAttributesRequiredError(error: apiError.toAttributesRequiredPublicError(), newState: nil) }
        case .attributesRequired,
             .credentialRequired,
             .unexpectedError:
            let error = AttributesRequiredError(type: .generalError)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error, context: context, format: "Unexpected error in signup/continue submitAttributes request \(error)")
            DispatchQueue.main.async { delegate.onSignUpAttributesRequiredError(error: error, newState: nil) }
        }
    }
}
