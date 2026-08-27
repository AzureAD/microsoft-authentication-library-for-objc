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

/// Per-request telemetry context for a single step of a server-driven flow
struct MSALNativeAuthFlowStepContext {
    let apiId: MSALNativeAuthTelemetryApiId
    let event: MSIDTelemetryAPIEvent?
    let context: MSALNativeAuthRequestContext
}

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
final class MSALNativeAuthFlowController: MSALNativeAuthBaseController, MSALNativeAuthFlowControlling, MSALNativeAuthTokenRequestHandling {

    private let config: MSALNativeAuthInternalConfiguration
    private let requestProvider: MSALNativeAuthV2RequestProviding
    private let responseParser: MSALNativeAuthV2ResponseParsing
    private let resultFactory: MSALNativeAuthResultBuildable
    private let cacheAccessor: MSALNativeAuthCacheInterface

    private let kNumberOfTimesToRetryPollCompletionCall = 5
    // TODO: Confirm this is needed and server doesn't send
    private let pollIntervalSeconds: Double = 1.5 // delay between poll attempts

    init(
        config: MSALNativeAuthInternalConfiguration,
        requestProvider: MSALNativeAuthV2RequestProviding,
        responseParser: MSALNativeAuthV2ResponseParsing,
        cacheAccessor: MSALNativeAuthCacheInterface,
        resultFactory: MSALNativeAuthResultBuildable
    ) {
        self.config = config
        self.requestProvider = requestProvider
        self.responseParser = responseParser
        self.resultFactory = resultFactory
        self.cacheAccessor = cacheAccessor
        super.init(clientId: config.clientId)
    }

    convenience init(config: MSALNativeAuthInternalConfiguration, cacheAccessor: MSALNativeAuthCacheInterface) {
        self.init(
            config: config,
            requestProvider: MSALNativeAuthV2RequestProvider(config: config),
            responseParser: MSALNativeAuthV2ResponseParser(),
            cacheAccessor: cacheAccessor,
            resultFactory: MSALNativeAuthResultFactory(config: config, cacheAccessor: cacheAccessor)
        )
    }

    // MARK: - Entry points

    func signUp(parameters: MSALNativeAuthSignUpParametersV2) async -> MSALNativeAuthFlowControllerResponse {
        let flowScenario: MSALNativeAuthFlowScenario = .signUp
        let context = MSALNativeAuthRequestContext(correlationId: parameters.correlationId)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2SignUpStart, context: context)

        // Authorization challenge (expects 401 + continuation token + sign_up link).
        let authorizationChallenge = await performAuthorizeChallengeStart(
            flowScenario: flowScenario,
            apiId: .telemetryApiIdV2SignUpStart,
            context: context
        )
        guard case .continuationToken(let continuationToken, let signUpLink) = authorizationChallenge else {
            return failure(authorizationChallenge, event: event, context: context, scenario: flowScenario)
        }

        let startResult = await performInteraction(context: context) {
            try self.requestProvider.signUpStart(
                username: parameters.username,
                continuationToken: continuationToken,
                href: signUpLink,
                apiId: .telemetryApiIdV2SignUpStart,
                context: context
            )
        }

        let continuation = MSALNativeAuthFlowContinuationState(
            flowScenario: flowScenario,
            correlationId: context.correlationId(),
            continuationToken: nil,
            links: [:],
            scopes: joinScopes(parameters.scopes)
        )
        let step = MSALNativeAuthFlowStepContext(apiId: .telemetryApiIdV2SignUpStart, event: event, context: context)
        return await handleSignUpInteractionResult(startResult, flowContinuationState: continuation, step: step, upfront: parameters)
    }

    func signIn(parameters: MSALNativeAuthSignInParameters) async -> MSALNativeAuthFlowControllerResponse {
        let flowScenario: MSALNativeAuthFlowScenario = .signIn
        let context = MSALNativeAuthRequestContext(correlationId: parameters.correlationId)
        let apiId: MSALNativeAuthTelemetryApiId = parameters.password == nil
            ? .telemetryApiIdV2SignInWithCodeStart
            : .telemetryApiIdV2SignInWithPasswordStart
        let event = makeAndStartTelemetryEvent(id: apiId, context: context)

        // Authorization challenge (expects 401 + continuation token + sign_in link).
        let authorizationChallenge = await performAuthorizeChallengeStart(
            flowScenario: flowScenario,
            apiId: apiId,
            context: context
        )
        guard case .continuationToken(let continuationToken, let signInLink) = authorizationChallenge else {
            return failure(authorizationChallenge, event: event, context: context, scenario: flowScenario)
        }

        let startResult = await performInteraction(context: context) {
            try self.requestProvider.signInStart(
                username: parameters.username,
                continuationToken: continuationToken,
                href: signInLink,
                apiId: apiId,
                context: context
            )
        }

        guard case .challengeRequired(let challengeContinuationToken, let methods) = startResult else {
            return interactionFailure(startResult, event: event, context: context, scenario: flowScenario, newState: nil)
        }

        let preferredMethod = parameters.password == nil
            ? methods.first(where: { $0.channelType.isEmailType })
            : methods.first(where: { $0.channelType.isPasswordType })
        let fallbackMethod = parameters.password == nil
            ? methods.first(where: { $0.channelType.isPasswordType })
            : methods.first(where: { $0.channelType.isEmailType })
        guard let method = preferredMethod ?? fallbackMethod else {
            let error = MSALNativeAuthFlowError(type: .generalError, errorDescription: MSALNativeAuthErrorMessage.generalError)
            return interactionFailure(.error(error), event: event, context: context, scenario: flowScenario, newState: nil)
        }

        let challengeResult = await performInteraction(context: context) {
            try self.requestProvider.challenge(
                href: method.challengeHref,
                continuationToken: challengeContinuationToken,
                apiId: apiId,
                context: context
            )
        }

        let continuation = MSALNativeAuthFlowContinuationState(
            flowScenario: flowScenario,
            correlationId: context.correlationId(),
            continuationToken: challengeContinuationToken,
            links: [:],
            scopes: joinScopes(parameters.scopes),
            claimsRequestJson: parameters.claimsRequest?.jsonString()
        )
        let step = MSALNativeAuthFlowStepContext(apiId: apiId, event: event, context: context)
        return await handleSignInChallengeResult(challengeResult, flowContinuationState: continuation, step: step, password: parameters.password)
    }

    func resetPassword(parameters: MSALNativeAuthResetPasswordParameters) async -> MSALNativeAuthFlowControllerResponse {
        let flowScenario: MSALNativeAuthFlowScenario = .passwordReset
        let context = MSALNativeAuthRequestContext(correlationId: parameters.correlationId)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2ResetPasswordStart, context: context)

        // Authorization challenge (expects 401 + continuation token + reset_password link).
        let authorizationChallenge = await performAuthorizeChallengeStart(
            flowScenario: flowScenario,
            apiId: .telemetryApiIdV2ResetPasswordStart,
            context: context
        )
        guard case .continuationToken(let continuationToken, let resetPasswordLink) = authorizationChallenge else {
            return failure(authorizationChallenge, event: event, context: context, scenario: flowScenario)
        }

        let startResult = await performInteraction(context: context) {
            try self.requestProvider.resetPasswordStart(
                username: parameters.username,
                continuationToken: continuationToken,
                href: resetPasswordLink,
                apiId: .telemetryApiIdV2ResetPasswordStart,
                context: context
            )
        }

        guard case .challengeRequired(let challengeContinuationToken, let methods) = startResult else {
            return interactionFailure(startResult, event: event, context: context, scenario: flowScenario, newState: nil)
        }

        // Password reset is a code-first flow: select the email code method from the offered first-factor methods.
        guard let method = methods.first(where: { $0.channelType.isEmailType }) else {
            let error = MSALNativeAuthFlowError(type: .generalError, errorDescription: MSALNativeAuthErrorMessage.generalError)
            return interactionFailure(.error(error), event: event, context: context, scenario: flowScenario, newState: nil)
        }

        let challengeResult = await performInteraction(context: context) {
            try self.requestProvider.challenge(
                href: method.challengeHref,
                continuationToken: challengeContinuationToken,
                apiId: .telemetryApiIdV2ResetPasswordStart,
                context: context
            )
        }

        let continuation = MSALNativeAuthFlowContinuationState(
            flowScenario: flowScenario,
            correlationId: context.correlationId(),
            continuationToken: challengeContinuationToken,
            links: [:]
        )
        let step = MSALNativeAuthFlowStepContext(apiId: .telemetryApiIdV2ResetPasswordStart, event: event, context: context)
        return await handlePasswordResetChallengeResult(challengeResult, flowContinuationState: continuation, step: step)
    }

    // MARK: - Continuation

    func submitCode(_ code: String, state: MSALNativeAuthFlowInternalState) async -> MSALNativeAuthFlowControllerResponse {
        let flowContinuationState = state.continuation
        let context = MSALNativeAuthRequestContext(correlationId: flowContinuationState.correlationId)
        let apiId: MSALNativeAuthTelemetryApiId
        switch flowContinuationState.flowScenario {
        case .signUp:
            apiId = .telemetryApiIdV2SignUpSubmitCode
        case .signIn:
            apiId = .telemetryApiIdV2SignInSubmitCode
        case .passwordReset:
            apiId = .telemetryApiIdV2ResetPasswordSubmitCode
        default:
            return invalidFlowMethodCalled(
                stateName: "MSALNativeAuthCodeRequiredState",
                scenario: flowContinuationState.flowScenario,
                correlationId: flowContinuationState.correlationId
            )
        }
        let event = makeAndStartTelemetryEvent(id: apiId, context: context)

        guard let verifyHref = flowContinuationState.link(.verify)?.absoluteString else {
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing verify link")),
                event: event,
                context: context, scenario: flowContinuationState.flowScenario
            )
        }

        guard let continuationToken = flowContinuationState.continuationToken else {
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing continuation token")),
                event: event,
                context: context, scenario: flowContinuationState.flowScenario
            )
        }

        let result = await performInteraction(context: context) {
            try self.requestProvider.verify(
                href: verifyHref,
                otp: code,
                continuationToken: continuationToken,
                apiId: apiId,
                context: context
            )
        }
        let step = MSALNativeAuthFlowStepContext(apiId: apiId, event: event, context: context)
        switch flowContinuationState.flowScenario {
        case .signUp:
            return await handleSignUpInteractionResult(result, flowContinuationState: flowContinuationState, step: step)
        case .signIn, .passwordReset:
            return await handleSubmitCodeResult(result, flowContinuationState: flowContinuationState, step: step)
        default:
            return notImplementedResponse(scenario: flowContinuationState.flowScenario)
        }
    }

    func submitPassword(_ password: String, state: MSALNativeAuthFlowInternalState) async -> MSALNativeAuthFlowControllerResponse {
        let flowContinuationState = state.continuation

        switch flowContinuationState.flowScenario {
        case .signUp:
            return await submitSignUpPassword(password, flowContinuationState: flowContinuationState)
        case .signIn:
            return await submitSignInPassword(password, flowContinuationState: flowContinuationState)
        default:
            return invalidFlowMethodCalled(
                stateName: "MSALNativeAuthPasswordRequiredState",
                scenario: flowContinuationState.flowScenario,
                correlationId: flowContinuationState.correlationId
            )
        }
    }

    // swiftlint:disable:next function_body_length
    func submitNewPassword(_ password: String, state: MSALNativeAuthFlowInternalState) async -> MSALNativeAuthFlowControllerResponse {
        let flowContinuationState = state.continuation
        let context = MSALNativeAuthRequestContext(correlationId: flowContinuationState.correlationId)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2ResetPasswordSubmit, context: context)

        guard let updateHref = flowContinuationState.link(.update)?.absoluteString else {
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing update link")),
                event: event,
                context: context, scenario: flowContinuationState.flowScenario
            )
        }

        guard let continuationToken = flowContinuationState.continuationToken else {
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing continuation token")),
                event: event,
                context: context, scenario: flowContinuationState.flowScenario
            )
        }

        let updateResult = await performInteraction(context: context) {
            try self.requestProvider.updatePassword(
                href: updateHref,
                newPassword: password,
                continuationToken: continuationToken,
                apiId: .telemetryApiIdV2ResetPasswordSubmit,
                context: context
            )
        }

        if case .error(let error) = updateResult {
            return interactionFailure(
                updateResult,
                event: event,
                context: context,
                scenario: flowContinuationState.flowScenario,
                newState: error.type == .invalidPassword ? state : nil
            )
        }

        guard case .pollInProgress(var pollToken, var pollHref) = updateResult else {
            return interactionFailure(
                updateResult,
                event: event,
                context: context,
                scenario: flowContinuationState.flowScenario,
                newState: nil
            )
        }

        let retryExecutor = MSALNativeAuthRetryExecutor(delays: [pollIntervalSeconds])
        let terminalPollResult = await retryExecutor.execute(
            maxAttempts: kNumberOfTimesToRetryPollCompletionCall
        ) { () -> MSALNativeAuthV2InteractionParsedResponse? in
            let pollResult = await performInteraction(context: context) {
                try self.requestProvider.poll(
                    href: pollHref,
                    continuationToken: pollToken,
                    apiId: .telemetryApiIdV2ResetPasswordSubmit,
                    context: context
                )
            }

            if case .pollInProgress(let token, let href) = pollResult {
                pollToken = token
                pollHref = href
                return nil
            }

            return pollResult
        }

        guard let terminalPollResult = terminalPollResult else {
            return failure(
                .error(
                    MSALNativeAuthFlowError(
                        type: .generalError,
                        errorDescription: "Password reset did not complete in time"
                    )
                ),
                event: event,
                context: context, scenario: flowContinuationState.flowScenario
            )
        }

        guard case .readyToComplete(let completionToken) = terminalPollResult else {
            return interactionFailure(
                terminalPollResult,
                event: event,
                context: context,
                scenario: flowContinuationState.flowScenario,
                newState: nil
            )
        }

        let step = MSALNativeAuthFlowStepContext(apiId: .telemetryApiIdV2ResetPasswordSubmit, event: event, context: context)
        return signInAfterResetPasswordResponse(flowContinuationState: flowContinuationState, continuationToken: completionToken, step: step)
    }

    func submitAttributes(_ attributes: [String: Any], state: MSALNativeAuthFlowInternalState) async -> MSALNativeAuthFlowControllerResponse {
        let flowContinuationState = state.continuation
        guard flowContinuationState.flowScenario == .signUp else {
            return invalidFlowMethodCalled(
                stateName: "MSALNativeAuthAttributesRequiredState",
                scenario: flowContinuationState.flowScenario,
                correlationId: flowContinuationState.correlationId
            )
        }
        let context = MSALNativeAuthRequestContext(correlationId: flowContinuationState.correlationId)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2SignUpSubmitAttributes, context: context)
        let step = MSALNativeAuthFlowStepContext(apiId: .telemetryApiIdV2SignUpSubmitAttributes, event: event, context: context)
        return await performSubmitAttributes(attributes, flowContinuationState: flowContinuationState, step: step)
    }

    func selectAuthMethod(
        _ method: MSALAuthMethod,
        verificationContact: String?,
        state: MSALNativeAuthFlowInternalState
    ) async -> MSALNativeAuthFlowControllerResponse {
        let flowContinuationState = state.continuation
        guard flowContinuationState.flowScenario == .signIn else {
            return invalidFlowMethodCalled(
                stateName: "MSALNativeAuthMFARequiredState",
                scenario: flowContinuationState.flowScenario,
                correlationId: flowContinuationState.correlationId
            )
        }
        let context = MSALNativeAuthRequestContext(correlationId: flowContinuationState.correlationId)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2MFAGetAuthMethods, context: context)

        guard let challengeHref = flowContinuationState.methodLink(for: method.id)?.absoluteString else {
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing challenge link for selected auth method")),
                event: event,
                context: context, scenario: flowContinuationState.flowScenario
            )
        }

        guard let continuationToken = flowContinuationState.continuationToken else {
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing continuation token")),
                event: event,
                context: context, scenario: flowContinuationState.flowScenario
            )
        }

        let result = await performInteraction(context: context) {
            try self.requestProvider.challenge(
                href: challengeHref,
                continuationToken: continuationToken,
                apiId: .telemetryApiIdV2MFAGetAuthMethods,
                context: context
            )
        }
        let step = MSALNativeAuthFlowStepContext(apiId: .telemetryApiIdV2MFAGetAuthMethods, event: event, context: context)
        return handleMFASelectAuthMethodResult(result, flowContinuationState: flowContinuationState, step: step)
    }

    func submitChallenge(_ challenge: String, state: MSALNativeAuthFlowInternalState) async -> MSALNativeAuthFlowControllerResponse {
        let flowContinuationState = state.continuation
        guard flowContinuationState.flowScenario == .signIn else {
            return invalidFlowMethodCalled(
                stateName: "MSALNativeAuthMFAVerificationRequiredState",
                scenario: flowContinuationState.flowScenario,
                correlationId: flowContinuationState.correlationId
            )
        }
        let context = MSALNativeAuthRequestContext(correlationId: flowContinuationState.correlationId)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2MFASubmitChallenge, context: context)

        guard let verifyHref = flowContinuationState.link(.verify)?.absoluteString else {
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing verify link")),
                event: event,
                context: context, scenario: flowContinuationState.flowScenario
            )
        }

        guard let continuationToken = flowContinuationState.continuationToken else {
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing continuation token")),
                event: event,
                context: context, scenario: flowContinuationState.flowScenario
            )
        }

        let result = await performInteraction(context: context) {
            try self.requestProvider.verify(
                href: verifyHref,
                otp: challenge,
                continuationToken: continuationToken,
                apiId: .telemetryApiIdV2MFASubmitChallenge,
                context: context
            )
        }
        let step = MSALNativeAuthFlowStepContext(apiId: .telemetryApiIdV2MFASubmitChallenge, event: event, context: context)
        return await handleSignInSubmitChallengeResult(result, flowContinuationState: flowContinuationState, step: step)
    }

    func resendCode(state: MSALNativeAuthFlowInternalState) async -> MSALNativeAuthFlowControllerResponse {
        let flowContinuationState = state.continuation
        let context = MSALNativeAuthRequestContext(correlationId: flowContinuationState.correlationId)
        let apiId: MSALNativeAuthTelemetryApiId
        switch flowContinuationState.flowScenario {
        case .signUp:
            apiId = .telemetryApiIdV2SignUpResendCode
        case .signIn:
            apiId = .telemetryApiIdV2SignInResendCode
        case .passwordReset:
            apiId = .telemetryApiIdV2ResetPasswordResendCode
        default:
            return invalidFlowMethodCalled(
                stateName: "MSALNativeAuthCodeRequiredState",
                scenario: flowContinuationState.flowScenario,
                correlationId: flowContinuationState.correlationId
            )
        }
        let event = makeAndStartTelemetryEvent(id: apiId, context: context)

        guard let resendHref = flowContinuationState.link(.resend)?.absoluteString else {
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing resend link")),
                event: event,
                context: context, scenario: flowContinuationState.flowScenario
            )
        }

        guard let continuationToken = flowContinuationState.continuationToken else {
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing continuation token")),
                event: event,
                context: context, scenario: flowContinuationState.flowScenario
            )
        }

        let result = await performInteraction(context: context) {
            try self.requestProvider.challenge(
                href: resendHref,
                continuationToken: continuationToken,
                apiId: apiId,
                context: context
            )
        }

        let step = MSALNativeAuthFlowStepContext(apiId: apiId, event: event, context: context)
        switch flowContinuationState.flowScenario {
        case .signUp:
            return await handleSignUpInteractionResult(result, flowContinuationState: flowContinuationState, step: step)
        case .signIn, .passwordReset:
            return handleResendCodeResult(result, flowContinuationState: flowContinuationState, step: step)
        default:
            return notImplementedResponse(scenario: flowContinuationState.flowScenario)
        }
    }

    func signInAfterSignUp(
        scopes: [String]?,
        claimsRequestJson: String?,
        state: MSALNativeAuthFlowInternalState
    ) async -> MSALNativeAuthFlowControllerResponse {
        let flowContinuationState = state.continuation
        let context = MSALNativeAuthRequestContext(correlationId: flowContinuationState.correlationId)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdSignInAfterSignUp, context: context)

        guard let continuationToken = flowContinuationState.continuationToken else {
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing continuation token")),
                event: event,
                context: context,
                scenario: flowContinuationState.flowScenario
            )
        }

        let step = MSALNativeAuthFlowStepContext(apiId: .telemetryApiIdSignInAfterSignUp, event: event, context: context)
        return await completeWithToken(
            flowContinuationState: flowContinuationState,
            continuationToken: continuationToken,
            scopes: joinScopes(scopes),
            claimsRequestJson: claimsRequestJson,
            step: step
        )
    }

    func signInAfterResetPassword(
        scopes: [String]?,
        claimsRequestJson: String?,
        state: MSALNativeAuthFlowInternalState
    ) async -> MSALNativeAuthFlowControllerResponse {
        let flowContinuationState = state.continuation
        let context = MSALNativeAuthRequestContext(correlationId: flowContinuationState.correlationId)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdSignInAfterPasswordReset, context: context)

        guard let continuationToken = flowContinuationState.continuationToken else {
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing continuation token")),
                event: event,
                context: context,
                scenario: flowContinuationState.flowScenario
            )
        }

        let step = MSALNativeAuthFlowStepContext(apiId: .telemetryApiIdSignInAfterPasswordReset, event: event, context: context)
        return await completeWithToken(
            flowContinuationState: flowContinuationState,
            continuationToken: continuationToken,
            scopes: joinScopes(scopes),
            claimsRequestJson: claimsRequestJson,
            step: step
        )
    }

    // MARK: - Private

    private func submitSignInPassword(
        _ password: String,
        flowContinuationState: MSALNativeAuthFlowContinuationState
    ) async -> MSALNativeAuthFlowControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: flowContinuationState.correlationId)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2SignInSubmitPassword, context: context)
        let step = MSALNativeAuthFlowStepContext(apiId: .telemetryApiIdV2SignInSubmitPassword, event: event, context: context)
        return await submitPassword(password, flowContinuationState: flowContinuationState, step: step)
    }

    private func submitSignUpPassword(
        _ password: String,
        flowContinuationState: MSALNativeAuthFlowContinuationState
    ) async -> MSALNativeAuthFlowControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: flowContinuationState.correlationId)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2SignUpSubmitAttributes, context: context)
        let step = MSALNativeAuthFlowStepContext(apiId: .telemetryApiIdV2SignUpSubmitAttributes, event: event, context: context)
        return await performSubmitAttributes(["password": password], flowContinuationState: flowContinuationState, step: step)
    }

    private func submitPassword(
        _ password: String,
        flowContinuationState: MSALNativeAuthFlowContinuationState,
        step: MSALNativeAuthFlowStepContext
    ) async -> MSALNativeAuthFlowControllerResponse {
        guard let verifyHref = flowContinuationState.link(.verify)?.absoluteString else {
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing verify link")),
                event: step.event,
                context: step.context, scenario: flowContinuationState.flowScenario
            )
        }

        guard let continuationToken = flowContinuationState.continuationToken else {
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing continuation token")),
                event: step.event,
                context: step.context, scenario: flowContinuationState.flowScenario
            )
        }

        let result = await performInteraction(context: step.context) {
            try self.requestProvider.submitPassword(
                href: verifyHref,
                password: password,
                continuationToken: continuationToken,
                apiId: step.apiId,
                context: step.context
            )
        }
        return await handleSignInSubmitPasswordResult(result, flowContinuationState: flowContinuationState, step: step)
    }

    // MARK: - Sign-up result mapping

    /// Drives the server-directed sign-up sequence forward.
    private func handleSignUpInteractionResult(
        _ result: MSALNativeAuthV2InteractionParsedResponse,
        flowContinuationState: MSALNativeAuthFlowContinuationState,
        step: MSALNativeAuthFlowStepContext,
        upfront: MSALNativeAuthSignUpParametersV2? = nil
    ) async -> MSALNativeAuthFlowControllerResponse {
        switch result {
        case .attributesRequired(let token, let submitHref, let attributes):
            return await handleSignUpAttributesRequired(
                continuationToken: token,
                submitHref: submitHref,
                attributes: attributes,
                flowContinuationState: flowContinuationState,
                step: step,
                signUpParameters: upfront
            )
        case .verificationRequired(let token, let verifyHref, let resendHref, let sentTo, let channelType, let codeLength):
            // Sign up currently supports email one-time-code verification only.
            guard channelType.isEmailType else {
                let error = MSALNativeAuthFlowError(type: .generalError, errorDescription: MSALNativeAuthErrorMessage.generalError)
                stopTelemetryEvent(step.event, context: step.context, error: error)
                return response(.error(error: error), context: step.context, scenario: flowContinuationState.flowScenario)
            }
            let next = makeSignUpContinuation(
                from: flowContinuationState,
                continuationToken: token,
                links: [.verify: verifyHref, .resend: resendHref]
            )
            return codeRequiredResponse(flowContinuationState: next, sentTo: sentTo, channelType: channelType, codeLength: codeLength, step: step)
        case .readyToComplete(let token):
            return signInAfterSignUpResponse(flowContinuationState: flowContinuationState, continuationToken: token, step: step)
        case .browserRequired:
            stopTelemetryEvent(step.event, context: step.context)
            return response(.browserRequired, context: step.context, scenario: flowContinuationState.flowScenario)
        case .error(let error):
            stopTelemetryEvent(step.event, context: step.context, error: error)
            return response(.error(error: error), context: step.context, scenario: flowContinuationState.flowScenario)
        default:
            return interactionFailure(result, event: step.event, context: step.context, scenario: flowContinuationState.flowScenario, newState: nil)
        }
    }

    /// Handles a `collectAttributes` step.
    ///
    /// On the first step (`signUpParameters` is non-nil, right after sign-up start) every value supplied up front -
    /// `email` (the username), `password` if provided, and any user attributes - is submitted in a single
    /// request, regardless of which attributes the server actually asked for. The names of the submitted
    /// attributes are then recorded on the continuation state.
    ///
    /// On any later step (`signUpParameters` is nil) the server is asking for something the app did not provide up
    /// front. If it re-requests `email`, `password`, or an attribute already submitted, that is treated as
    /// an error; otherwise the requested attributes are surfaced via ``MSALNativeAuthAttributesRequiredState``.
    private func handleSignUpAttributesRequired(
        continuationToken: String,
        submitHref: String,
        attributes: [MSALNativeAuthRequiredAttributeInternal],
        flowContinuationState: MSALNativeAuthFlowContinuationState,
        step: MSALNativeAuthFlowStepContext,
        signUpParameters: MSALNativeAuthSignUpParametersV2? = nil
    ) async -> MSALNativeAuthFlowControllerResponse {
        let next = makeSignUpContinuation(
            from: flowContinuationState,
            continuationToken: continuationToken,
            links: [.submitAttributes: submitHref]
        )

        if let signUpParameters = signUpParameters {
            return await performSubmitAttributes(upfrontAttributeValues(signUpParameters), flowContinuationState: next, step: step)
        }

        if let invalid = attributes.first(where: { isReservedOrAlreadySubmitted($0, flowContinuationState: flowContinuationState) }) {
            let error = MSALNativeAuthFlowError(
                type: .generalError,
                errorDescription: "The server requested attribute '\(invalid.name)' that was already submitted or cannot be collected."
            )
            stopTelemetryEvent(step.event, context: step.context, error: error)
            return response(.error(error: error), context: step.context, scenario: flowContinuationState.flowScenario)
        }

        return attributesRequiredResponse(flowContinuationState: next, attributes: attributes, step: step)
    }

    /// Posts collected attributes to the `submitAttributes` href, records their names on the continuation
    /// state, and continues the flow.
    private func performSubmitAttributes(
        _ attributes: [String: Any],
        flowContinuationState: MSALNativeAuthFlowContinuationState,
        step: MSALNativeAuthFlowStepContext
    ) async -> MSALNativeAuthFlowControllerResponse {
        guard let submitHref = flowContinuationState.link(.submitAttributes)?.absoluteString else {
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing submit attributes link")),
                event: step.event,
                context: step.context, scenario: flowContinuationState.flowScenario
            )
        }

        guard let continuationToken = flowContinuationState.continuationToken else {
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing continuation token")),
                event: step.event,
                context: step.context, scenario: flowContinuationState.flowScenario
            )
        }

        let result = await performInteraction(context: step.context) {
            try self.requestProvider.submitAttributes(
                href: submitHref,
                attributes: attributes,
                continuationToken: continuationToken,
                apiId: .telemetryApiIdV2SignUpSubmitAttributes,
                context: step.context
            )
        }
        let submitted = flowContinuationState.addingSubmittedAttributes(Array(attributes.keys))
        return await handleSignUpInteractionResult(result, flowContinuationState: submitted, step: step)
    }

    /// Builds the attribute dictionary submitted up front: `email` (the username) plus any password and
    /// user attributes supplied to `signUp`.
    private func upfrontAttributeValues(_ parameters: MSALNativeAuthSignUpParametersV2) -> [String: Any] {
        var values: [String: Any] = ["email": parameters.username]
        if let password = parameters.password, !password.isEmpty {
            values["password"] = password
        }
        if let attributes = parameters.attributes {
            for (name, value) in attributes {
                values[name] = value
            }
        }
        return values
    }

    /// A requested attribute is invalid when it is `email`, `password`, or one the SDK has already submitted.
    private func isReservedOrAlreadySubmitted(
        _ attribute: MSALNativeAuthRequiredAttributeInternal,
        flowContinuationState: MSALNativeAuthFlowContinuationState
    ) -> Bool {
        if attribute.name.caseInsensitiveCompare("password") == .orderedSame || attribute.name.caseInsensitiveCompare("email") == .orderedSame {
            return true
        }
        return flowContinuationState.submittedAttributes.contains { $0.caseInsensitiveCompare(attribute.name) == .orderedSame }
    }

    /// Derives the next sign-up continuation, preserving the names of the attributes already submitted.
    private func makeSignUpContinuation(
        from flowContinuationState: MSALNativeAuthFlowContinuationState,
        continuationToken: String,
        links: [MSALNativeAuthV2LinkRelation: String?]
    ) -> MSALNativeAuthFlowContinuationState {
        return MSALNativeAuthFlowContinuationState(
            flowScenario: flowContinuationState.flowScenario,
            correlationId: flowContinuationState.correlationId,
            continuationToken: continuationToken,
            links: resolveLinks(links),
            scopes: flowContinuationState.scopes,
            claimsRequestJson: flowContinuationState.claimsRequestJson,
            submittedAttributes: flowContinuationState.submittedAttributes
        )
    }

    private func attributesRequiredResponse(
        flowContinuationState: MSALNativeAuthFlowContinuationState,
        attributes: [MSALNativeAuthRequiredAttributeInternal],
        step: MSALNativeAuthFlowStepContext
    ) -> MSALNativeAuthFlowControllerResponse {
        let internalState = MSALNativeAuthFlowInternalState(continuation: flowContinuationState, controller: self)
        let publicAttributes = attributes.map { $0.toRequiredAttributePublic() }
        let state = MSALNativeAuthAttributesRequiredState(internalState: internalState, attributes: publicAttributes)
        stopTelemetryEvent(step.event, context: step.context)
        return response(.actionRequired(state: state), context: step.context)
    }

    private func signInAfterSignUpResponse(
        flowContinuationState: MSALNativeAuthFlowContinuationState,
        continuationToken: String,
        step: MSALNativeAuthFlowStepContext
    ) -> MSALNativeAuthFlowControllerResponse {
        let continuation = makeSignUpContinuation(from: flowContinuationState, continuationToken: continuationToken, links: [:])
        let internalState = MSALNativeAuthFlowInternalState(continuation: continuation, controller: self)
        stopTelemetryEvent(step.event, context: step.context)
        return response(
            .actionRequired(state: MSALNativeAuthSignInAfterSignUpState(internalState: internalState)),
            context: step.context
        )
    }

    // MARK: - Sign-in result mapping

    /// Maps the challenge response from the sign in flow.
    private func handleSignInChallengeResult(
        _ result: MSALNativeAuthV2InteractionParsedResponse,
        flowContinuationState: MSALNativeAuthFlowContinuationState,
        step: MSALNativeAuthFlowStepContext,
        password: String? = nil
    ) async -> MSALNativeAuthFlowControllerResponse {
        switch result {
        case .verificationRequired(let token, let verifyHref, let resendHref, let sentTo, let channelType, let codeLength):
            let next = makeSignInContinuation(
                from: flowContinuationState,
                continuationToken: token,
                links: [.verify: verifyHref, .resend: resendHref]
            )
            if channelType.isPasswordType {
                if let password = password, !password.isEmpty {
                    return await submitPassword(password, flowContinuationState: next, step: step)
                }
                return passwordRequiredResponse(flowContinuationState: next, step: step)
            }
            if channelType.isEmailType {
                return codeRequiredResponse(
                    flowContinuationState: next,
                    sentTo: sentTo,
                    channelType: channelType,
                    codeLength: codeLength,
                    step: step
                )
            }
            let error = MSALNativeAuthFlowError(type: .generalError, errorDescription: MSALNativeAuthErrorMessage.generalError)
            stopTelemetryEvent(step.event, context: step.context, error: error)
            return response(.error(error: error), context: step.context, scenario: flowContinuationState.flowScenario)
        case .readyToComplete(let token):
            return await completeSignIn(flowContinuationState: flowContinuationState, continuationToken: token, step: step)
        case .browserRequired:
            stopTelemetryEvent(step.event, context: step.context)
            return response(.browserRequired, context: step.context, scenario: flowContinuationState.flowScenario)
        case .error(let error):
            stopTelemetryEvent(step.event, context: step.context, error: error)
            return response(.error(error: error), context: step.context, scenario: flowContinuationState.flowScenario)
        default:
            return interactionFailure(result, event: step.event, context: step.context, scenario: flowContinuationState.flowScenario, newState: nil)
        }
    }

    /// Maps the verify response from submitting a password.
    private func handleSignInSubmitPasswordResult(
        _ result: MSALNativeAuthV2InteractionParsedResponse,
        flowContinuationState: MSALNativeAuthFlowContinuationState,
        step: MSALNativeAuthFlowStepContext
    ) async -> MSALNativeAuthFlowControllerResponse {
        switch result {
        case .readyToComplete(let token):
            return await completeSignIn(flowContinuationState: flowContinuationState, continuationToken: token, step: step)
        case .mfaRequired(let token, let methods):
            let next = makeMFAContinuation(from: flowContinuationState, continuationToken: token, methods: methods)
            return mfaRequiredResponse(flowContinuationState: next, methods: methods, step: step)
        case .browserRequired:
            stopTelemetryEvent(step.event, context: step.context)
            return response(.browserRequired, context: step.context, scenario: flowContinuationState.flowScenario)
        case .error(let error):
            // If we get back invalidCredentials error, because the email was already validated before,
            // it can only be .invalidPassword so we surface that.
            let surfacedError = error.type == .invalidCredentials
                ? MSALNativeAuthFlowError(
                    type: .invalidPassword,
                    errorDescription: error.errorDescription,
                    errorCodes: error.errorCodes,
                    correlationId: error.correlationId,
                    errorUri: error.errorUri)
                : error
            stopTelemetryEvent(step.event, context: step.context, error: surfacedError)
            return response(
                .error(error: surfacedError),
                context: step.context, scenario: flowContinuationState.flowScenario
            )
        default:
            return interactionFailure(result, event: step.event, context: step.context, scenario: flowContinuationState.flowScenario, newState: nil)
        }
    }

    /// Maps the verify response from submitting an MFA challenge (one-time code) during sign-in.
    private func handleSignInSubmitChallengeResult(
        _ result: MSALNativeAuthV2InteractionParsedResponse,
        flowContinuationState: MSALNativeAuthFlowContinuationState,
        step: MSALNativeAuthFlowStepContext
    ) async -> MSALNativeAuthFlowControllerResponse {
        switch result {
        case .readyToComplete(let token):
            return await completeSignIn(flowContinuationState: flowContinuationState, continuationToken: token, step: step)
        case .browserRequired:
            stopTelemetryEvent(step.event, context: step.context)
            return response(.browserRequired, context: step.context, scenario: flowContinuationState.flowScenario)
        case .error(let error):
            stopTelemetryEvent(step.event, context: step.context, error: error)
            return response(
                .error(error: error),
                context: step.context, scenario: flowContinuationState.flowScenario
            )
        default:
            return interactionFailure(result, event: step.event, context: step.context, scenario: flowContinuationState.flowScenario, newState: nil)
        }
    }

    /// Derives the next sign-in continuation.
    private func makeSignInContinuation(
        from flowContinuationState: MSALNativeAuthFlowContinuationState,
        continuationToken: String,
        links: [MSALNativeAuthV2LinkRelation: String?]
    ) -> MSALNativeAuthFlowContinuationState {
        return MSALNativeAuthFlowContinuationState(
            flowScenario: flowContinuationState.flowScenario,
            correlationId: flowContinuationState.correlationId,
            continuationToken: continuationToken,
            links: resolveLinks(links),
            scopes: flowContinuationState.scopes,
            claimsRequestJson: flowContinuationState.claimsRequestJson
        )
    }

    private func passwordRequiredResponse(
        flowContinuationState: MSALNativeAuthFlowContinuationState,
        step: MSALNativeAuthFlowStepContext
    ) -> MSALNativeAuthFlowControllerResponse {
        let internalState = MSALNativeAuthFlowInternalState(continuation: flowContinuationState, controller: self)
        stopTelemetryEvent(step.event, context: step.context)
        return response(
            .actionRequired(state: MSALNativeAuthPasswordRequiredState(internalState: internalState)),
            context: step.context
        )
    }

    /// Derives the next continuation for an MFA method-selection step
    private func makeMFAContinuation(
        from flowContinuationState: MSALNativeAuthFlowContinuationState,
        continuationToken: String,
        methods: [MSALNativeAuthV2ChallengeMethod]
    ) -> MSALNativeAuthFlowContinuationState {
        let resolver = MSALNativeAuthV2HrefURLResolver(config: config)
        var resolvedLinks: [MSALNativeAuthV2LinkKey: URL] = [:]
        for method in methods {
            if let url = try? resolver.url(forHref: method.challengeHref) {
                resolvedLinks[.method(id: method.id)] = url
            }
        }
        return MSALNativeAuthFlowContinuationState(
            flowScenario: flowContinuationState.flowScenario,
            correlationId: flowContinuationState.correlationId,
            continuationToken: continuationToken,
            links: resolvedLinks,
            scopes: flowContinuationState.scopes,
            claimsRequestJson: flowContinuationState.claimsRequestJson
        )
    }

    private func mfaRequiredResponse(
        flowContinuationState: MSALNativeAuthFlowContinuationState,
        methods: [MSALNativeAuthV2ChallengeMethod],
        step: MSALNativeAuthFlowStepContext
    ) -> MSALNativeAuthFlowControllerResponse {
        let internalState = MSALNativeAuthFlowInternalState(continuation: flowContinuationState, controller: self)
        let authMethods = methods.map { method in
            MSALAuthMethod(
                id: method.id,
                challengeType: method.channelType.rawValue,
                channelTargetType: MSALNativeAuthChannelType(value: method.channelType.rawValue),
                loginHint: method.hint
            )
        }
        stopTelemetryEvent(step.event, context: step.context)
        return response(
            .actionRequired(state: MSALNativeAuthMFARequiredState(internalState: internalState, authMethods: authMethods)),
            context: step.context
        )
    }

    /// Maps the challenge response produced after the user selects an MFA method.
    private func handleMFASelectAuthMethodResult(
        _ result: MSALNativeAuthV2InteractionParsedResponse,
        flowContinuationState: MSALNativeAuthFlowContinuationState,
        step: MSALNativeAuthFlowStepContext
    ) -> MSALNativeAuthFlowControllerResponse {
        switch result {
        case .verificationRequired(let token, let verifyHref, let resendHref, let sentTo, let channelType, let codeLength):
            let next = makeSignInContinuation(
                from: flowContinuationState,
                continuationToken: token,
                links: [.verify: verifyHref, .resend: resendHref]
            )
            return mfaVerificationRequiredResponse(
                flowContinuationState: next,
                sentTo: sentTo,
                channelType: channelType,
                codeLength: codeLength,
                step: step
            )
        case .browserRequired:
            stopTelemetryEvent(step.event, context: step.context)
            return response(.browserRequired, context: step.context, scenario: flowContinuationState.flowScenario)
        case .error(let error):
            stopTelemetryEvent(step.event, context: step.context, error: error)
            return response(.error(error: error), context: step.context, scenario: flowContinuationState.flowScenario)
        default:
            return interactionFailure(result, event: step.event, context: step.context, scenario: flowContinuationState.flowScenario, newState: nil)
        }
    }

    private func mfaVerificationRequiredResponse(
        flowContinuationState: MSALNativeAuthFlowContinuationState,
        sentTo: String,
        channelType: MSALNativeAuthChannelType,
        codeLength: Int,
        step: MSALNativeAuthFlowStepContext
    ) -> MSALNativeAuthFlowControllerResponse {
        let internalState = MSALNativeAuthFlowInternalState(continuation: flowContinuationState, controller: self)
        let state = MSALNativeAuthMFAVerificationRequiredState(
            internalState: internalState,
            sentTo: sentTo,
            channel: channelType,
            codeLength: codeLength
        )
        stopTelemetryEvent(step.event, context: step.context)
        return response(.actionRequired(state: state), context: step.context)
    }

    private func completeSignIn(
        flowContinuationState: MSALNativeAuthFlowContinuationState,
        continuationToken: String,
        step: MSALNativeAuthFlowStepContext
    ) async -> MSALNativeAuthFlowControllerResponse {
        return await completeWithToken(
            flowContinuationState: flowContinuationState,
            continuationToken: continuationToken,
            scopes: flowContinuationState.scopes,
            claimsRequestJson: flowContinuationState.claimsRequestJson,
            step: step
        )
    }

    // MARK: - Password Reset Result mapping

    /// Maps the challenge response from the reset-password start sequence.
    func handlePasswordResetChallengeResult(
        _ result: MSALNativeAuthV2InteractionParsedResponse,
        flowContinuationState: MSALNativeAuthFlowContinuationState,
        step: MSALNativeAuthFlowStepContext
    ) async -> MSALNativeAuthFlowControllerResponse {
        switch result {
        case .verificationRequired(let token, let verifyHref, let resendHref, let sentTo, let channelType, let codeLength):
            // Password reset is a code-first flow: the server must select a code-based method, only email supported for now
            // Any other method type cannot be verified in this flow, so it is an error.
            guard channelType.isEmailType else {
                let error = MSALNativeAuthFlowError(type: .generalError, errorDescription: MSALNativeAuthErrorMessage.generalError)
                stopTelemetryEvent(step.event, context: step.context, error: error)
                return response(.error(error: error), context: step.context, scenario: flowContinuationState.flowScenario)
            }
            let next = makeContinuation(from: flowContinuationState, continuationToken: token, links: [.verify: verifyHref, .resend: resendHref])
            return codeRequiredResponse(flowContinuationState: next, sentTo: sentTo, channelType: channelType, codeLength: codeLength, step: step)
        case .readyToComplete(let token):
            return signInAfterResetPasswordResponse(flowContinuationState: flowContinuationState, continuationToken: token, step: step)
        case .browserRequired:
            stopTelemetryEvent(step.event, context: step.context)
            return response(.browserRequired, context: step.context, scenario: flowContinuationState.flowScenario)
        case .error(let error):
            stopTelemetryEvent(step.event, context: step.context, error: error)
            return response(.error(error: error), context: step.context, scenario: flowContinuationState.flowScenario)
        default:
            return interactionFailure(result, event: step.event, context: step.context, scenario: flowContinuationState.flowScenario, newState: nil)
        }
    }

    /// Maps the challenge response produced when the user asks to resend the one-time code.
    func handleResendCodeResult(
        _ result: MSALNativeAuthV2InteractionParsedResponse,
        flowContinuationState: MSALNativeAuthFlowContinuationState,
        step: MSALNativeAuthFlowStepContext
    ) -> MSALNativeAuthFlowControllerResponse {
        switch result {
        case .verificationRequired(let token, let verifyHref, let resendHref, let sentTo, let channelType, let codeLength):
            guard channelType.isEmailType else {
                let error = MSALNativeAuthFlowError(type: .generalError, errorDescription: MSALNativeAuthErrorMessage.generalError)
                stopTelemetryEvent(step.event, context: step.context, error: error)
                return response(.error(error: error), context: step.context, scenario: flowContinuationState.flowScenario)
            }
            let next = flowContinuationState.flowScenario == .signIn
                ? makeSignInContinuation(
                    from: flowContinuationState,
                    continuationToken: token,
                    links: [.verify: verifyHref, .resend: resendHref]
                )
                : makeContinuation(
                    from: flowContinuationState,
                    continuationToken: token,
                    links: [.verify: verifyHref, .resend: resendHref]
                )
            return codeRequiredResponse(flowContinuationState: next, sentTo: sentTo, channelType: channelType, codeLength: codeLength, step: step)
        case .browserRequired:
            stopTelemetryEvent(step.event, context: step.context)
            return response(.browserRequired, context: step.context, scenario: flowContinuationState.flowScenario)
        case .error(let error):
            stopTelemetryEvent(step.event, context: step.context, error: error)
            return response(.error(error: error), context: step.context, scenario: flowContinuationState.flowScenario)
        default:
            return interactionFailure(result, event: step.event, context: step.context, scenario: flowContinuationState.flowScenario, newState: nil)
        }
    }

    /// Maps the verify response from submitting a one-time code.
    func handleSubmitCodeResult(
        _ result: MSALNativeAuthV2InteractionParsedResponse,
        flowContinuationState: MSALNativeAuthFlowContinuationState,
        step: MSALNativeAuthFlowStepContext
    ) async -> MSALNativeAuthFlowControllerResponse {
        switch result {
        case .updateRequired(let token, let updateHref):
            guard flowContinuationState.flowScenario == .passwordReset else {
                return interactionFailure(
                    result,
                    event: step.event,
                    context: step.context,
                    scenario: flowContinuationState.flowScenario,
                    newState: nil
                )
            }
            let next = makeContinuation(from: flowContinuationState, continuationToken: token, links: [.update: updateHref])
            return newPasswordRequiredResponse(flowContinuationState: next, step: step)
        case .readyToComplete(let token):
            switch flowContinuationState.flowScenario {
            case .signIn:
                return await completeSignIn(flowContinuationState: flowContinuationState, continuationToken: token, step: step)
            case .passwordReset:
                return signInAfterResetPasswordResponse(
                    flowContinuationState: flowContinuationState,
                    continuationToken: token,
                    step: step
                )
            default:
                return interactionFailure(
                    result,
                    event: step.event,
                    context: step.context,
                    scenario: flowContinuationState.flowScenario,
                    newState: nil
                )
            }
        case .browserRequired:
            stopTelemetryEvent(step.event, context: step.context)
            return response(.browserRequired, context: step.context, scenario: flowContinuationState.flowScenario)
        case .error(let error):
            stopTelemetryEvent(step.event, context: step.context, error: error)
            return response(
                .error(error: error),
                context: step.context, scenario: flowContinuationState.flowScenario
            )
        default:
            return interactionFailure(result, event: step.event, context: step.context, scenario: flowContinuationState.flowScenario, newState: nil)
        }
    }

    // MARK: - Response builders

    /// Derives the next continuation for a flow step..
    private func makeContinuation(
        from flowContinuationState: MSALNativeAuthFlowContinuationState,
        continuationToken: String,
        links: [MSALNativeAuthV2LinkRelation: String?]
    ) -> MSALNativeAuthFlowContinuationState {
        return MSALNativeAuthFlowContinuationState(
            flowScenario: flowContinuationState.flowScenario,
            correlationId: flowContinuationState.correlationId,
            continuationToken: continuationToken,
            links: resolveLinks(links)
        )
    }

    private func codeRequiredResponse(
        flowContinuationState: MSALNativeAuthFlowContinuationState,
        sentTo: String,
        channelType: MSALNativeAuthChannelType,
        codeLength: Int,
        step: MSALNativeAuthFlowStepContext
    ) -> MSALNativeAuthFlowControllerResponse {
        let internalState = MSALNativeAuthFlowInternalState(continuation: flowContinuationState, controller: self)
        let state = MSALNativeAuthCodeRequiredState(
            internalState: internalState,
            sentTo: sentTo,
            channel: channelType,
            codeLength: codeLength
        )
        stopTelemetryEvent(step.event, context: step.context)
        return response(.actionRequired(state: state), context: step.context)
    }

    private func newPasswordRequiredResponse(
        flowContinuationState: MSALNativeAuthFlowContinuationState,
        step: MSALNativeAuthFlowStepContext
    ) -> MSALNativeAuthFlowControllerResponse {
        let internalState = MSALNativeAuthFlowInternalState(continuation: flowContinuationState, controller: self)
        stopTelemetryEvent(step.event, context: step.context)
        return response(
            .actionRequired(state: MSALNativeAuthNewPasswordRequiredState(internalState: internalState)),
            context: step.context
        )
    }

    private func signInAfterResetPasswordResponse(
        flowContinuationState: MSALNativeAuthFlowContinuationState,
        continuationToken: String,
        step: MSALNativeAuthFlowStepContext
    ) -> MSALNativeAuthFlowControllerResponse {
        let continuation = makeContinuation(from: flowContinuationState, continuationToken: continuationToken, links: [:])
        let internalState = MSALNativeAuthFlowInternalState(continuation: continuation, controller: self)
        stopTelemetryEvent(step.event, context: step.context)
        return response(
            .actionRequired(state: MSALNativeAuthSignInAfterResetPasswordState(internalState: internalState)),
            context: step.context
        )
    }

    private func completeWithToken(
        flowContinuationState: MSALNativeAuthFlowContinuationState,
        continuationToken: String,
        scopes: [String],
        claimsRequestJson: String?,
        step: MSALNativeAuthFlowStepContext
    ) async -> MSALNativeAuthFlowControllerResponse {
        let codeResult = await performAuthorizeChallengeContinue(
            flowScenario: flowContinuationState.flowScenario,
            continuationToken: continuationToken,
            apiId: step.apiId,
            context: step.context
        )
        guard case .authorizationCode(let code) = codeResult else {
            return failure(codeResult, event: step.event, context: step.context, scenario: flowContinuationState.flowScenario)
        }

        let tokenResponseResult = await performTokenExchange(code: code,
                                                             scopes: scopes,
                                                             claimsRequestJson: claimsRequestJson,
                                                             apiId: step.apiId,
                                                             context: step.context)
        switch tokenResponseResult {
        case .success(let tokenResponse):
            do {
                let msidConfiguration = resultFactory.makeMSIDConfiguration(scopes: retrieveScopes(from: tokenResponse))
                let tokenResult = try cacheTokenResponse(tokenResponse, context: step.context, msidConfiguration: msidConfiguration)

                guard let accountResult = resultFactory.makeUserAccountResult(tokenResult: tokenResult, context: step.context) else {
                    let error = MSALNativeAuthFlowError(type: .generalError, errorDescription: "Unable to construct account result")
                    stopTelemetryEvent(step.event, context: step.context, error: error)
                    return response(.error(error: error), context: step.context, scenario: flowContinuationState.flowScenario)
                }
                stopTelemetryEvent(step.event, context: step.context)
                return response(.completed(accountResult), context: step.context, scenario: flowContinuationState.flowScenario)
            } catch {
                let flowError = MSALNativeAuthFlowError(type: .generalError, errorDescription: "Unable to save tokens to the cache")
                stopTelemetryEvent(step.event, context: step.context, error: flowError)
                return response(.error(error: flowError), context: step.context, scenario: flowContinuationState.flowScenario)
            }
        case .error(let flowError):
            stopTelemetryEvent(step.event, context: step.context, error: flowError)
            return response(.error(error: flowError), context: step.context, scenario: flowContinuationState.flowScenario)
        }
    }

    /// Builds the `/token` request, delegates the send/parse to the shared token-request handler, and
    /// hands the outcome to the parser for classification, so an embedded server error is surfaced as
    /// `.error` rather than a "successful" token response with no tokens.
    private func performTokenExchange(
        code: String,
        scopes: [String],
        claimsRequestJson: String?,
        apiId: MSALNativeAuthTelemetryApiId,
        context: MSALNativeAuthRequestContext
    ) async -> MSALNativeAuthV2TokenParsedResponse {
        let request: MSIDHttpRequest
        do {
            request = try requestProvider.token(
                code: code,
                scopes: scopes,
                claimsRequestJson: claimsRequestJson,
                apiId: apiId,
                context: context
            )
        } catch {
            return responseParser.parseToken(context: context, .failure(error))
        }

        return responseParser.parseToken(context: context, await performTokenRequest(request, context: context))
    }

    private func cacheTokenResponse(
        _ tokenResponse: MSIDTokenResponse,
        context: MSALNativeAuthRequestContext,
        msidConfiguration: MSIDConfiguration
    ) throws -> MSIDTokenResult {
        return try cacheAccessor.cache(
            tokenResponse,
            context: context,
            msidConfiguration: msidConfiguration
        ) { tokenResult, accountIdentifier in
            try self.validateAccount(tokenResult, accountIdentifier: accountIdentifier, context: context)
        }
    }

    private func validateAccount(
        _ tokenResult: MSIDTokenResult,
        accountIdentifier: MSIDAccountIdentifier,
        context: MSALNativeAuthRequestContext
    ) throws -> Bool {
        var error: NSError?
        let validAccount = MSIDTokenResponseValidator().validateAccount(
            accountIdentifier,
            tokenResult: tokenResult,
            correlationID: context.correlationId(),
            error: &error
        )
        if let error = error {
            throw error
        }
        return validAccount
    }

    /// Extracts the granted scopes from a token response so the cache target matches what was issued.
    private func retrieveScopes(from tokenResponse: MSIDTokenResponse) -> [String] {
        guard let scope = tokenResponse.scope, !scope.isEmpty else {
            return []
        }
        return scope.components(separatedBy: " ").filter { !$0.isEmpty }
    }

    /// Resolves server-provided `_links` hrefs into absolute URLs, dropping any that are missing
    /// or cannot be resolved.
    private func resolveLinks(_ links: [MSALNativeAuthV2LinkRelation: String?]) -> [MSALNativeAuthV2LinkKey: URL] {
        let resolver = MSALNativeAuthV2HrefURLResolver(config: config)
        var resolvedLinks: [MSALNativeAuthV2LinkKey: URL] = [:]
        for (relation, href) in links {
            if let href = href, let url = try? resolver.url(forHref: href) {
                resolvedLinks[.relation(relation)] = url
            }
        }
        return resolvedLinks
    }

    // MARK: - Shared step helpers

    private func performAuthorizeChallengeStart(
        flowScenario: MSALNativeAuthFlowScenario,
        apiId: MSALNativeAuthTelemetryApiId,
        context: MSALNativeAuthRequestContext
    ) async -> MSALNativeAuthV2AuthorizeChallengeParsedResponse {
        let result: Result<MSALNativeAuthHALResponse, Error> = await send(context: context) {
            try self.requestProvider.authorizeChallengeStart(apiId: apiId, context: context)
        }
        return responseParser.parseAuthorizeChallenge(context: context, result, flowScenario: flowScenario)
    }

    private func performAuthorizeChallengeContinue(
        flowScenario: MSALNativeAuthFlowScenario,
        continuationToken: String,
        apiId: MSALNativeAuthTelemetryApiId,
        context: MSALNativeAuthRequestContext
    ) async -> MSALNativeAuthV2AuthorizeChallengeParsedResponse {
        let result: Result<MSALNativeAuthHALResponse, Error> = await send(context: context) {
            try self.requestProvider.authorizeChallengeContinue(continuationToken: continuationToken, apiId: apiId, context: context)
        }
        return responseParser.parseAuthorizeChallenge(context: context, result, flowScenario: flowScenario)
    }

    private func performInteraction(
        context: MSALNativeAuthRequestContext,
        requestBuilder: @escaping () throws -> MSIDHttpRequest
    ) async -> MSALNativeAuthV2InteractionParsedResponse {
        let result: Result<MSALNativeAuthHALResponse, Error> = await send(context: context, requestBuilder)
        return responseParser.parseInteraction(context: context, result)
    }

    private func send(
        context: MSALNativeAuthRequestContext,
        _ requestBuilder: @escaping () throws -> MSIDHttpRequest
    ) async -> Result<MSALNativeAuthHALResponse, Error> {
        do {
            let request = try requestBuilder()
            return await performRequest(request, context: context)
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Response construction

    private func response(
        _ result: MSALNativeAuthFlowResult,
        context: MSALNativeAuthRequestContext,
        scenario: MSALNativeAuthFlowScenario
    ) -> MSALNativeAuthFlowControllerResponse {
        return MSALNativeAuthFlowControllerResponse(
            result,
            correlationId: context.correlationId(),
            scenario: scenario
        )
    }

    /// Builds a response for `.actionRequired` results, whose scenario the dispatcher reads from the
    /// state's continuation rather than the wrapper.
    private func response(
        _ result: MSALNativeAuthFlowResult,
        context: MSALNativeAuthRequestContext
    ) -> MSALNativeAuthFlowControllerResponse {
        return MSALNativeAuthFlowControllerResponse(
            result,
            correlationId: context.correlationId()
        )
    }

    /// Response for the case where, after performing a step, no handler is available to process the
    /// result for the current flow scenario.
    private func notImplementedResponse(scenario: MSALNativeAuthFlowScenario) -> MSALNativeAuthFlowControllerResponse {
        return MSALNativeAuthFlowControllerResponse(
            .error(error: MSALNativeAuthFlowError(type: .notImplemented)),
            correlationId: UUID(),
            scenario: scenario
        )
    }

    /// Response for when a continuation method is invoked on a flow scenario that does not support it.
    private func invalidFlowMethodCalled(
        stateName: String,
        scenario: MSALNativeAuthFlowScenario,
        correlationId: UUID
    ) -> MSALNativeAuthFlowControllerResponse {
        let message = String(format: MSALNativeAuthErrorMessage.methodNotAllowedForFlow, stateName, scenario.name)
        return MSALNativeAuthFlowControllerResponse(
            .error(error: MSALNativeAuthFlowError(type: .generalError, errorDescription: message, correlationId: correlationId)),
            correlationId: correlationId,
            scenario: scenario
        )
    }

    private func failure(
        _ parsed: MSALNativeAuthV2AuthorizeChallengeParsedResponse,
        event: MSIDTelemetryAPIEvent?,
        context: MSALNativeAuthRequestContext,
        scenario: MSALNativeAuthFlowScenario
    ) -> MSALNativeAuthFlowControllerResponse {
        let error: MSALNativeAuthFlowError
        if case .error(let flowError) = parsed {
            error = flowError
        } else {
            error = MSALNativeAuthFlowError(type: .generalError, errorDescription: "Unexpected authorize-challenge response")
        }
        stopTelemetryEvent(event, context: context, error: error)
        return response(.error(error: error), context: context, scenario: scenario)
    }

    private func interactionFailure(
        _ parsed: MSALNativeAuthV2InteractionParsedResponse,
        event: MSIDTelemetryAPIEvent?,
        context: MSALNativeAuthRequestContext,
        scenario: MSALNativeAuthFlowScenario,
        newState: MSALNativeAuthFlowInternalState?
    ) -> MSALNativeAuthFlowControllerResponse {
        let error: MSALNativeAuthFlowError
        if case .error(let flowError) = parsed {
            error = flowError
        } else {
            error = MSALNativeAuthFlowError(type: .generalError, errorDescription: "Unexpected server response")
        }
        stopTelemetryEvent(event, context: context, error: error)
        return response(.error(error: error), context: context, scenario: scenario)
    }
}
