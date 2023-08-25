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

    convenience init(config: MSALNativeAuthConfiguration) {
        self.init(
            config: config,
            requestProvider: MSALNativeAuthSignUpRequestProvider(
                requestConfigurator: MSALNativeAuthRequestConfigurator(config: config),
                telemetryProvider: MSALNativeAuthTelemetryProvider()
            ),
            responseValidator: MSALNativeAuthSignUpResponseValidator(),
            signInController: MSALNativeAuthSignInController(config: config)
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
        await handleSubmitCodeResult(result, signUpToken: signUpToken, event: event, context: context, delegate: delegate)
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
        handleSubmitPasswordResult(continueRequestResult, signUpToken: signUpToken, event: event, context: context, delegate: delegate)
    }

    func submitAttributes(
        _ attributes: [String: Any],
        signUpToken: String,
        context: MSIDRequestContext,
        delegate: SignUpAttributesRequiredDelegate
    ) async {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdSignUpSubmitAttributes, context: context)
        let params = MSALNativeAuthSignUpContinueRequestProviderParams(
            grantType: .attributes,
            signUpToken: signUpToken,
            attributes: attributes,
            context: context
        )

        let result = await performAndValidateContinueRequest(parameters: params)
        handleSubmitAttributesResult(result, signUpToken: signUpToken, event: event, context: context, delegate: delegate)
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
        case .verificationRequired(let signUpToken, let attributes):
            MSALLogger.log(
                level: .info,
                context: context,
                format: "verification_required received from signup/start with password request for attributes: \(attributes)"
            )
            let challengeResult = await performAndValidateChallengeRequest(signUpToken: signUpToken, context: context)
            handleSignUpPasswordChallengeResult(challengeResult, event: event, context: context, delegate: delegate)
        case .attributeValidationFailed(let invalidAttributes):
            MSALLogger.log(
                level: .error,
                context: context,
                format: "attribute_validation_failed received from signup/start with password request for attributes: \(invalidAttributes)"
            )
            let message = String(format: MSALNativeAuthErrorMessage.attributeValidationFailedSignUpStart, invalidAttributes.description)
            let error = SignUpPasswordStartError(type: .invalidAttributes, message: message)
            stopTelemetryEvent(event, context: context, error: error)
            DispatchQueue.main.async { delegate.onSignUpPasswordError(error: error) }
        case .redirect:
            let error = SignUpPasswordStartError(type: .browserRequired)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "redirect error in signup/start with password request \(error.errorDescription ?? "No error description")")
            DispatchQueue.main.async { delegate.onSignUpPasswordError(error: error) }
        case .error(let apiError):
            let error = apiError.toSignUpStartPasswordPublicError()
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error in signup/start with password request \(error.errorDescription ?? "No error description")")
            DispatchQueue.main.async { delegate.onSignUpPasswordError(error: error) }
        case .unexpectedError:
            let error = SignUpPasswordStartError(type: .generalError)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Unexpected error in signup/start with password request \(error.errorDescription ?? "No error description")")
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
        case .verificationRequired(let signUpToken, let unverifiedAttributes):
            MSALLogger.log(
                level: .info,
                context: context,
                format: "verification_required received from signup/start request for attributes: \(unverifiedAttributes)"
            )
            let challengeResult = await performAndValidateChallengeRequest(signUpToken: signUpToken, context: context)
            handleSignUpCodeChallengeResult(challengeResult, event: event, context: context, delegate: delegate)
        case .attributeValidationFailed(let invalidAttributes):
            MSALLogger.log(
                level: .error,
                context: context,
                format: "attribute_validation_failed received from signup/start request for attributes: \(invalidAttributes)"
            )
            let message = String(format: MSALNativeAuthErrorMessage.attributeValidationFailedSignUpStart, invalidAttributes.description)
            let error = SignUpStartError(type: .invalidAttributes, message: message)
            stopTelemetryEvent(event, context: context, error: error)
            DispatchQueue.main.async { delegate.onSignUpError(error: error) }
        case .redirect:
            let error = SignUpStartError(type: .browserRequired)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Redirect error in signup/start request \(error.errorDescription ?? "No error description")")
            DispatchQueue.main.async { delegate.onSignUpError(error: error) }
        case .error(let apiError):
            let error = apiError.toSignUpStartPublicError()
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error in signup/start request \(error.errorDescription ?? "No error description")")
            DispatchQueue.main.async { delegate.onSignUpError(error: error) }
        case .unexpectedError:
            let error = SignUpStartError(type: .generalError)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Unexpected error in signup/start request \(error.errorDescription ?? "No error description")")
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
        case .codeRequired(let sentTo, let challengeType, let codeLength, let signUpToken):
            MSALLogger.log(level: .info, context: context, format: "Successful signup/challenge password request")
            stopTelemetryEvent(event, context: context)
            DispatchQueue.main.async {
                delegate.onSignUpCodeRequired(
                    newState: SignUpCodeRequiredState(controller: self, flowToken: signUpToken),
                    sentTo: sentTo,
                    channelTargetType: challengeType,
                    codeLength: codeLength
                )
            }
        case .error(let apiError):
            let error = apiError.toSignUpPasswordStartPublicError()
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error in signup/challenge password request \(error.errorDescription ?? "No error description")")
            DispatchQueue.main.async { delegate.onSignUpPasswordError(error: error) }
        case .redirect:
            let error = SignUpPasswordStartError(type: .browserRequired)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Redirect error in signup/challenge password request \(error.errorDescription ?? "No error description")")
            DispatchQueue.main.async { delegate.onSignUpPasswordError(error: error) }
        case .unexpectedError,
             .passwordRequired:
            let error = SignUpPasswordStartError(type: .generalError)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Unexpected error in signup/challenge password request \(error.errorDescription ?? "No error description")")
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
        case .codeRequired(let sentTo, let challengeType, let codeLength, let signUpToken):
            MSALLogger.log(level: .info, context: context, format: "Successful signup/challenge request")
            stopTelemetryEvent(event, context: context)
            DispatchQueue.main.async {
                delegate.onSignUpCodeRequired(
                    newState: SignUpCodeRequiredState(controller: self, flowToken: signUpToken),
                    sentTo: sentTo,
                    channelTargetType: challengeType,
                    codeLength: codeLength
                )
            }
        case .error(let apiError):
            let error = apiError.toSignUpStartPublicError()
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error in signup/challenge request \(error.errorDescription ?? "No error description")")
            DispatchQueue.main.async { delegate.onSignUpError(error: error) }
        case .redirect:
            let error = SignUpStartError(type: .browserRequired)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Redirect error in signup/challenge request \(error.errorDescription ?? "No error description")")
            DispatchQueue.main.async { delegate.onSignUpError(error: error) }
        case .unexpectedError,
             .passwordRequired:
            let error = SignUpStartError(type: .generalError)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Unexpected error in signup/challenge request \(error.errorDescription ?? "No error description")")
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
        case .codeRequired(let sentTo, let challengeType, let codeLength, let signUpToken):
            MSALLogger.log(level: .info, context: context, format: "Successful signup/challenge resendCode request")
            stopTelemetryEvent(event, context: context)
            DispatchQueue.main.async {
                delegate.onSignUpResendCodeCodeRequired(
                    newState: SignUpCodeRequiredState(controller: self, flowToken: signUpToken),
                    sentTo: sentTo,
                    channelTargetType: challengeType,
                    codeLength: codeLength
                )
            }
        case .error(let apiError):
            let error = apiError.toResendCodePublicError()
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error in signup/challenge resendCode request \(error.errorDescription ?? "No error description")")
            DispatchQueue.main.async { delegate.onSignUpResendCodeError(error: error) }
        case .redirect,
             .unexpectedError,
             .passwordRequired:
            let error = ResendCodeError()
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Unexpected error in signup/challenge resendCode request \(error.errorDescription ?? "No error description")")
            DispatchQueue.main.async { delegate.onSignUpResendCodeError(error: error) }
        }
    }

    /// This method handles the /challenge response after receiving a "credential_required" error
    private func handlePerformChallengeAfterContinueRequest(
        _ result: MSALNativeAuthSignUpChallengeValidatedResponse,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext,
        delegate: SignUpVerifyCodeDelegate
    ) {
        switch result {
        case .passwordRequired(let signUpToken):
            MSALLogger.log(level: .info, context: context, format: "Successful signup/challenge request after credential_required")

            if let function = delegate.onSignUpPasswordRequired {
                stopTelemetryEvent(event, context: context)
                DispatchQueue.main.async { function(SignUpPasswordRequiredState(controller: self, flowToken: signUpToken)) }
            } else {
                MSALLogger.log(level: .error, context: context, format: "onSignUpPasswordRequired() is not implemented by developer")
                let error = VerifyCodeError(type: .generalError, message: MSALNativeAuthErrorMessage.delegateNotImplemented)
                stopTelemetryEvent(event, context: context, error: error)
                DispatchQueue.main.async { delegate.onSignUpVerifyCodeError(error: error, newState: nil) }
            }
        case .redirect:
            let error = VerifyCodeError(type: .browserRequired)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Redirect error in signup/challenge request \(error.errorDescription ?? "No error description")")
            DispatchQueue.main.async { delegate.onSignUpVerifyCodeError(error: error, newState: nil) }
        case .error,
             .codeRequired,
             .unexpectedError:
            let error = VerifyCodeError(type: .generalError)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Unexpected error in signup/challenge request \(error.errorDescription ?? "No error description")")
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

    // swiftlint:disable:next function_body_length
    private func handleSubmitCodeResult(
        _ result: MSALNativeAuthSignUpContinueValidatedResponse,
        signUpToken: String,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext,
        delegate: SignUpVerifyCodeDelegate
    ) async {
        switch result {
        case .success(let slt):
            completeSignUpUsingSLT(slt, event: event, context: context, signUpCompleted: delegate.onSignUpCompleted)
        case .invalidUserInput:
            MSALLogger.log(level: .error, context: context, format: "invalid_user_input error in signup/continue request")

            let error = VerifyCodeError(type: .invalidCode)
            stopTelemetryEvent(event, context: context, error: error)
            DispatchQueue.main.async {
                delegate.onSignUpVerifyCodeError(error: error, newState: SignUpCodeRequiredState(controller: self, flowToken: signUpToken))
            }
        case .credentialRequired(let signUpToken):
            MSALLogger.log(level: .verbose, context: context, format: "credential_required received in signup/continue request")

            let result = await performAndValidateChallengeRequest(signUpToken: signUpToken, context: context)
            handlePerformChallengeAfterContinueRequest(result, event: event, context: context, delegate: delegate)
        case .attributesRequired(let signUpToken, let attributes):
            MSALLogger.log(level: .verbose, context: context, format: "attributes_required received in signup/continue request: \(attributes)")

            if let function = delegate.onSignUpAttributesRequired {
                stopTelemetryEvent(event, context: context)
                DispatchQueue.main.async { function(attributes, SignUpAttributesRequiredState(controller: self, flowToken: signUpToken)) }
            } else {
                MSALLogger.log(level: .error, context: context, format: "onSignUpAttributesRequired() is not implemented by developer")
                let error = VerifyCodeError(type: .generalError, message: MSALNativeAuthErrorMessage.delegateNotImplemented)
                stopTelemetryEvent(event, context: context, error: error)
                DispatchQueue.main.async { delegate.onSignUpVerifyCodeError(error: error, newState: nil) }
            }
        case .attributeValidationFailed(let signUpToken, let invalidAttributes):
            let message = "attribute_validation_failed from signup/continue. Make sure these attributes are correct: \(invalidAttributes)"
            MSALLogger.log(level: .error, context: context, format: message)

            if let function = delegate.onSignUpAttributesRequired {
                let errorMessage = String(format: MSALNativeAuthErrorMessage.attributeValidationFailed, invalidAttributes.description)
                let error = VerifyCodeError(type: .generalError, message: errorMessage)
                stopTelemetryEvent(event, context: context, error: error)
                DispatchQueue.main.async { function([], SignUpAttributesRequiredState(controller: self, flowToken: signUpToken)) }
            } else {
                MSALLogger.log(level: .error, context: context, format: "onSignUpAttributesRequired() is not implemented by developer")
                let error = VerifyCodeError(type: .generalError, message: MSALNativeAuthErrorMessage.delegateNotImplemented)
                stopTelemetryEvent(event, context: context, error: error)
                DispatchQueue.main.async { delegate.onSignUpVerifyCodeError(error: error, newState: nil) }
            }
        case .error(let apiError):
            let error = apiError.toVerifyCodePublicError()
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error in signup/continue request \(error.errorDescription ?? "No error description")")
            DispatchQueue.main.async { delegate.onSignUpVerifyCodeError(error: error, newState: nil) }
        case .unexpectedError:
            let error = VerifyCodeError(type: .generalError)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Unexpected error in signup/continue request \(error.errorDescription ?? "No error description")")
            DispatchQueue.main.async { delegate.onSignUpVerifyCodeError(error: error, newState: nil) }
        }
    }

    // swiftlint:disable:next function_body_length
    private func handleSubmitPasswordResult(
        _ result: MSALNativeAuthSignUpContinueValidatedResponse,
        signUpToken: String,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext,
        delegate: SignUpPasswordRequiredDelegate
    ) {
        switch result {
        case .success(let slt):
            completeSignUpUsingSLT(slt, event: event, context: context, signUpCompleted: delegate.onSignUpCompleted)
        case .invalidUserInput(let error):
            let error = error.toPasswordRequiredPublicError()
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "invalid_user_input error in signup/continue submitPassword request \(error.errorDescription ?? "No error description")") // swiftlint:disable:this line_length

            DispatchQueue.main.async {
                delegate.onSignUpPasswordRequiredError(
                    error: error,
                    newState: SignUpPasswordRequiredState(controller: self, flowToken: signUpToken)
                )
            }
        case .attributesRequired(let signUpToken, let attributes):
            MSALLogger.log(level: .verbose, context: context, format: "attributes_required received in signup/continue request: \(attributes)")

            if let function = delegate.onSignUpAttributesRequired {
                stopTelemetryEvent(event, context: context)
                DispatchQueue.main.async { function(attributes, SignUpAttributesRequiredState(controller: self, flowToken: signUpToken)) }
            } else {
                MSALLogger.log(level: .error, context: context, format: "onSignUpAttributesRequired() is not implemented by developer")
                let error = PasswordRequiredError(type: .generalError, message: MSALNativeAuthErrorMessage.delegateNotImplemented)
                stopTelemetryEvent(event, context: context, error: error)
                DispatchQueue.main.async { delegate.onSignUpPasswordRequiredError(error: error, newState: nil) }
            }
        case .attributeValidationFailed(let signUpToken, let invalidAttributes):
            let message = "attribute_validation_failed from signup/continue. Make sure these attributes are correct: \(invalidAttributes)"
            MSALLogger.log(level: .error, context: context, format: message)

            if let function = delegate.onSignUpAttributesRequired {
                let errorMessage = String(format: MSALNativeAuthErrorMessage.attributeValidationFailed, invalidAttributes.description)
                let error = PasswordRequiredError(type: .generalError, message: errorMessage)
                stopTelemetryEvent(event, context: context, error: error)
                DispatchQueue.main.async { function([], SignUpAttributesRequiredState(controller: self, flowToken: signUpToken)) }
            } else {
                MSALLogger.log(level: .error, context: context, format: "onSignUpAttributesRequired() is not implemented by developer")
                let error = PasswordRequiredError(type: .generalError, message: MSALNativeAuthErrorMessage.delegateNotImplemented)
                stopTelemetryEvent(event, context: context, error: error)
                DispatchQueue.main.async { delegate.onSignUpPasswordRequiredError(error: error, newState: nil) }
            }
        case .error(let apiError):
            let error = apiError.toPasswordRequiredPublicError()
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error in signup/continue submitPassword request \(error.errorDescription ?? "No error description")")
            DispatchQueue.main.async { delegate.onSignUpPasswordRequiredError(error: error, newState: nil) }
        case .credentialRequired,
             .unexpectedError:
            let error = PasswordRequiredError(type: .generalError)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Unexpected error in signup/continue submitPassword request \(error.errorDescription ?? "No error description")")
            DispatchQueue.main.async { delegate.onSignUpPasswordRequiredError(error: error, newState: nil) }
        }
    }

    // swiftlint:disable:next function_body_length
    private func handleSubmitAttributesResult(
        _ result: MSALNativeAuthSignUpContinueValidatedResponse,
        signUpToken: String,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext,
        delegate: SignUpAttributesRequiredDelegate
    ) {
        switch result {
        case .success(let slt):
            completeSignUpUsingSLT(slt, event: event, context: context, signUpCompleted: delegate.onSignUpCompleted)
        case .invalidUserInput:
            let error = AttributesRequiredError(type: .invalidAttributes)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(
                level: .error,
                context: context,
                format: "invalid_user_input error in signup/continue submitAttributes request \(error.errorDescription ?? "No error description")"
            )

            DispatchQueue.main.async {
                delegate.onSignUpAttributesRequiredError(
                    error: error,
                    newState: SignUpAttributesRequiredState(controller: self, flowToken: signUpToken)
                )
            }
        case .attributesRequired(let signUpToken, let attributes):
            let error = AttributesRequiredError(type: .missingRequiredAttributes)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "attributes_required received in signup/continue submitAttributes request: \(attributes)")

            DispatchQueue.main.async {
                delegate.onSignUpAttributesRequired(
                    attributes: attributes,
                    newState: SignUpAttributesRequiredState(controller: self, flowToken: signUpToken))
            }
        case .attributeValidationFailed(let signUpToken, let invalidAttributes):
            let message = "attribute_validation_failed from signup/continue submitAttributes request. Make sure these attributes are correct: \(invalidAttributes)" // swiftlint:disable:this line_length
            MSALLogger.log(level: .error, context: context, format: message)

            let errorMessage = String(format: MSALNativeAuthErrorMessage.attributeValidationFailed, invalidAttributes.description)
            let error = AttributesRequiredError(type: .invalidAttributes, message: errorMessage)
            stopTelemetryEvent(event, context: context, error: error)

            DispatchQueue.main.async {
                delegate.onSignUpAttributesInvalid(
                    attributeNames: invalidAttributes,
                    newState: SignUpAttributesRequiredState(controller: self, flowToken: signUpToken)
                )
            }
        case .error(let apiError):
            let error = apiError.toAttributesRequiredPublicError()
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Error in signup/continue submitAttributes request \(error.errorDescription ?? "No error description")")
            DispatchQueue.main.async { delegate.onSignUpAttributesRequiredError(error: apiError.toAttributesRequiredPublicError(), newState: nil) }
        case .credentialRequired,
             .unexpectedError:
            let error = AttributesRequiredError(type: .generalError)
            stopTelemetryEvent(event, context: context, error: error)
            MSALLogger.log(level: .error,
                           context: context,
                           format: "Unexpected error in signup/continue submitAttributes request \(error.errorDescription ?? "No error description")")
            DispatchQueue.main.async { delegate.onSignUpAttributesRequiredError(error: error, newState: nil) }
        }
    }

    private func completeSignUpUsingSLT(
        _ slt: String?,
        event: MSIDTelemetryAPIEvent?,
        context: MSIDRequestContext,
        signUpCompleted: @escaping (SignInAfterSignUpState) -> Void
    ) {
        MSALLogger.log(level: .info, context: context, format: "SignUp completed successfully")
        let newState = SignInAfterSignUpState(controller: signInController, slt: slt)
        stopTelemetryEvent(event, context: context)
        DispatchQueue.main.async { signUpCompleted(newState) }
    }
}
