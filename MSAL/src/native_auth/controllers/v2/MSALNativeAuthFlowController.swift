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

/// The latest server instruction, used to choose the request when a public method supports multiple operations.
enum MSALNativeAuthNextAction {
    case challenge
    case enroll
    case verify
    case activate
    case submitAttributes
}

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
        let scopes = joinScopes(parameters.scopes)
        let context = MSALNativeAuthRequestContext(correlationId: parameters.correlationId)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2SignUpStart, context: context)

        let invalidAttributes = (parameters.attributes ?? [:]).keys.filter {
            $0.caseInsensitiveCompare("email") == .orderedSame || $0.caseInsensitiveCompare("password") == .orderedSame
        }.sorted()
        guard invalidAttributes.isEmpty else {
            return failure(
                .error(MSALNativeAuthFlowError(
                    type: .invalidAttributes,
                    errorDescription: "The attribute names 'email' and 'password' are reserved by the SDK. " +
                        "Invalid attributes: \(invalidAttributes.joined(separator: ", ")).",
                    correlationId: context.correlationId()
                )),
                event: event, context: context, scenario: flowScenario
            )
        }

        // Authorization challenge (expects 401 + continuation token + sign_up link).
        let authorizationChallenge = await performAuthorizeChallengeStart(
            flowScenario: flowScenario,
            scopes: scopes,
            claimsRequestJson: parameters.claimsRequest?.jsonString(),
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
            scopes: scopes,
            claimsRequestJson: parameters.claimsRequest?.jsonString(),
            pendingSignUpAttributes: parameters.attributes ?? [:]
        )
        let step = MSALNativeAuthFlowStepContext(apiId: .telemetryApiIdV2SignUpStart, event: event, context: context)
        return await handleInteractionResult(startResult, flowContinuationState: continuation, step: step)
    }

    func signIn(parameters: MSALNativeAuthSignInParametersV2) async -> MSALNativeAuthFlowControllerResponse {
        let flowScenario: MSALNativeAuthFlowScenario = .signIn
        let scopes = joinScopes(parameters.scopes)
        let context = MSALNativeAuthRequestContext(correlationId: parameters.correlationId)
        let apiId: MSALNativeAuthTelemetryApiId = .telemetryApiIdV2SignInStart
        let event = makeAndStartTelemetryEvent(id: apiId, context: context)

        // Authorization challenge (expects 401 + continuation token + sign_in link).
        let authorizationChallenge = await performAuthorizeChallengeStart(
            flowScenario: flowScenario,
            scopes: scopes,
            claimsRequestJson: parameters.claimsRequest?.jsonString(),
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

        let continuation = MSALNativeAuthFlowContinuationState(
            flowScenario: flowScenario,
            correlationId: context.correlationId(),
            continuationToken: continuationToken,
            links: [:],
            scopes: scopes,
            claimsRequestJson: parameters.claimsRequest?.jsonString()
        )
        let step = MSALNativeAuthFlowStepContext(apiId: apiId, event: event, context: context)
        return await handleInteractionResult(startResult, flowContinuationState: continuation, step: step)
    }

    func resetPassword(parameters: MSALNativeAuthResetPasswordParametersV2) async -> MSALNativeAuthFlowControllerResponse {
        let flowScenario: MSALNativeAuthFlowScenario = .passwordReset
        let scopes = joinScopes(parameters.scopes)
        let context = MSALNativeAuthRequestContext(correlationId: parameters.correlationId)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2ResetPasswordStart, context: context)

        // Authorization challenge (expects 401 + continuation token + reset_password link).
        let authorizationChallenge = await performAuthorizeChallengeStart(
            flowScenario: flowScenario,
            scopes: scopes,
            claimsRequestJson: parameters.claimsRequest?.jsonString(),
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

        let continuation = MSALNativeAuthFlowContinuationState(
            flowScenario: flowScenario,
            correlationId: context.correlationId(),
            continuationToken: continuationToken,
            links: [:],
            scopes: scopes,
            claimsRequestJson: parameters.claimsRequest?.jsonString()
        )
        let step = MSALNativeAuthFlowStepContext(apiId: .telemetryApiIdV2ResetPasswordStart, event: event, context: context)
        return await handleInteractionResult(startResult, flowContinuationState: continuation, step: step)
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
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: MSALNativeAuthErrorMessage.missingContinuationToken)),
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
        return await handleInteractionResult(result, flowContinuationState: flowContinuationState, step: step)
    }

    func submitPassword(_ password: String, state: MSALNativeAuthFlowInternalState) async -> MSALNativeAuthFlowControllerResponse {
        let flowContinuationState = state.continuation
        let context = MSALNativeAuthRequestContext(correlationId: flowContinuationState.correlationId)
        switch flowContinuationState.nextAction {
        case .submitAttributes:
            return await submitAttributes(["password": password], state: state)
        case .verify:
            let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2SignInSubmitPassword, context: context)
            let step = MSALNativeAuthFlowStepContext(apiId: .telemetryApiIdV2SignInSubmitPassword, event: event, context: context)
            return await submitPassword(password, flowContinuationState: flowContinuationState, step: step)
        default:
            let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2SignInSubmitPassword, context: context)
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: MSALNativeAuthErrorMessage.generalError)),
                event: event, context: context, scenario: flowContinuationState.flowScenario
            )
        }
    }

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
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: MSALNativeAuthErrorMessage.missingContinuationToken)),
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

        let step = MSALNativeAuthFlowStepContext(apiId: .telemetryApiIdV2ResetPasswordSubmit, event: event, context: context)
        return await handleInteractionResult(updateResult, flowContinuationState: flowContinuationState, step: step)
    }

    func submitAttributes(_ attributes: [String: Any], state: MSALNativeAuthFlowInternalState) async -> MSALNativeAuthFlowControllerResponse {
        let flowContinuationState = state.continuation
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
        let scenario = flowContinuationState.flowScenario
        let challengeApiId: MSALNativeAuthTelemetryApiId
        if flowContinuationState.isMFAChallenge {
            challengeApiId = .telemetryApiIdV2MFAGetAuthMethods
        } else if scenario == .passwordReset {
            challengeApiId = .telemetryApiIdV2ResetPasswordSelectAuthMethod
        } else {
            challengeApiId = .telemetryApiIdV2SignInSelectAuthMethod
        }

        let context = MSALNativeAuthRequestContext(correlationId: flowContinuationState.correlationId)
        switch flowContinuationState.nextAction {
        case .enroll:
            let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2JITChallenge, context: context)
            let step = MSALNativeAuthFlowStepContext(apiId: .telemetryApiIdV2JITChallenge, event: event, context: context)
            guard case .registrationRequired(_, let methods)? = flowContinuationState.challengeResponse else {
                return failure(
                    .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing offered enrollment methods")),
                    event: event, context: context, scenario: scenario
                )
            }
            return await enrollAuthMethod(
                method,
                offeredMethods: methods,
                verificationContact: verificationContact,
                flowContinuationState: flowContinuationState,
                step: step
            )
        case .challenge:
            let event = makeAndStartTelemetryEvent(id: challengeApiId, context: context)
            let step = MSALNativeAuthFlowStepContext(apiId: challengeApiId, event: event, context: context)
            let result = await performAuthMethodChallenge(method, flowContinuationState: flowContinuationState, step: step)
            return await handleInteractionResult(result, flowContinuationState: flowContinuationState, step: step)
        default:
            let event = makeAndStartTelemetryEvent(id: challengeApiId, context: context)
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: MSALNativeAuthErrorMessage.generalError)),
                event: event, context: context, scenario: scenario
            )
        }
    }

    func submitChallenge(
        _ challenge: String,
        state: MSALNativeAuthFlowInternalState
    ) async -> MSALNativeAuthFlowControllerResponse {
        switch state.continuation.nextAction {
        case .activate:
            return await activateAuthMethod(challenge, state: state)
        case .verify:
            return await submitMFAChallenge(challenge, state: state)
        default:
            let continuation = state.continuation
            let context = MSALNativeAuthRequestContext(correlationId: continuation.correlationId)
            let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2MFASubmitChallenge, context: context)
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: MSALNativeAuthErrorMessage.generalError)),
                event: event, context: context, scenario: continuation.flowScenario
            )
        }
    }

    private func submitMFAChallenge(
        _ challenge: String,
        state: MSALNativeAuthFlowInternalState
    ) async -> MSALNativeAuthFlowControllerResponse {
        let flowContinuationState = state.continuation
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
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: MSALNativeAuthErrorMessage.missingContinuationToken)),
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
        return await handleInteractionResult(
            mapChallengeVerificationError(result),
            flowContinuationState: flowContinuationState,
            step: step
        )
    }

    private func mapChallengeVerificationError(
        _ result: MSALNativeAuthV2InteractionParsedResponse
    ) -> MSALNativeAuthV2InteractionParsedResponse {
        guard case .error(let error) = result, error.isInvalidCode else {
            return result
        }
        return .error(MSALNativeAuthFlowError(
            type: .invalidChallenge,
            errorDescription: error.errorDescription,
            errorCodes: error.errorCodes,
            correlationId: error.correlationId,
            errorUri: error.errorUri
        ))
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
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: MSALNativeAuthErrorMessage.missingContinuationToken)),
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
        return await handleInteractionResult(result, flowContinuationState: flowContinuationState, step: step)
    }

    func resendMFAChallenge(
        state: MSALNativeAuthFlowInternalState
    ) async -> MSALNativeAuthFlowControllerResponse {
        let continuation = state.continuation
        let apiId: MSALNativeAuthTelemetryApiId = .telemetryApiIdV2MFAResendChallenge
        let context = MSALNativeAuthRequestContext(correlationId: continuation.correlationId)
        let event = makeAndStartTelemetryEvent(id: apiId, context: context)
        let step = MSALNativeAuthFlowStepContext(apiId: apiId, event: event, context: context)
        let result = await performResend(state: state, step: step)
        return await handleInteractionResult(
            result,
            flowContinuationState: continuation,
            step: step
        )
    }

    func resendStrongAuthChallenge(
        state: MSALNativeAuthFlowInternalState
    ) async -> MSALNativeAuthFlowControllerResponse {
        let continuation = state.continuation
        guard continuation.flowScenario == .signUp ||
                continuation.flowScenario == .signIn ||
                continuation.flowScenario == .passwordReset else {
            return invalidFlowMethodCalled(
                stateName: "MSALNativeAuthStrongAuthVerificationRequiredState",
                scenario: continuation.flowScenario,
                correlationId: continuation.correlationId
            )
        }

        let apiId: MSALNativeAuthTelemetryApiId = .telemetryApiIdV2JITResendChallenge
        let context = MSALNativeAuthRequestContext(correlationId: continuation.correlationId)
        let event = makeAndStartTelemetryEvent(id: apiId, context: context)
        let step = MSALNativeAuthFlowStepContext(apiId: apiId, event: event, context: context)
        let result = await performResend(state: state, step: step)
        return await handleInteractionResult(
            result,
            flowContinuationState: continuation,
            step: step
        )
    }

    private func performResend(
        state: MSALNativeAuthFlowInternalState,
        step: MSALNativeAuthFlowStepContext
    ) async -> MSALNativeAuthV2InteractionParsedResponse {
        let flowContinuationState = state.continuation
        guard let resendHref = flowContinuationState.link(.resend)?.absoluteString else {
            return .error(MSALNativeAuthFlowError(
                type: .generalError,
                errorDescription: "Missing resend link",
                correlationId: flowContinuationState.correlationId
            ))
        }

        guard let continuationToken = flowContinuationState.continuationToken else {
            return .error(MSALNativeAuthFlowError(
                type: .generalError,
                errorDescription: MSALNativeAuthErrorMessage.missingContinuationToken,
                correlationId: flowContinuationState.correlationId
            ))
        }

        return await performInteraction(context: step.context) {
            try self.requestProvider.challenge(
                href: resendHref,
                continuationToken: continuationToken,
                apiId: step.apiId,
                context: step.context
            )
        }
    }

    func signInAfterSignUp(
        state: MSALNativeAuthFlowInternalState
    ) async -> MSALNativeAuthFlowControllerResponse {
        let flowContinuationState = state.continuation
        guard flowContinuationState.flowScenario == .signUp else {
            return invalidFlowMethodCalled(
                stateName: "MSALNativeAuthSignInAfterSignUpState",
                scenario: flowContinuationState.flowScenario,
                correlationId: flowContinuationState.correlationId
            )
        }
        let context = MSALNativeAuthRequestContext(correlationId: flowContinuationState.correlationId)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdSignInAfterSignUp, context: context)
        guard let continuationToken = flowContinuationState.continuationToken else {
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: MSALNativeAuthErrorMessage.missingContinuationToken)),
                event: event,
                context: context,
                scenario: flowContinuationState.flowScenario
            )
        }

        let step = MSALNativeAuthFlowStepContext(apiId: .telemetryApiIdSignInAfterSignUp, event: event, context: context)
        return await completeWithToken(
            flowContinuationState: flowContinuationState,
            continuationToken: continuationToken,
            step: step
        )
    }

    func signInAfterResetPassword(
        state: MSALNativeAuthFlowInternalState
    ) async -> MSALNativeAuthFlowControllerResponse {
        let flowContinuationState = state.continuation
        let context = MSALNativeAuthRequestContext(correlationId: flowContinuationState.correlationId)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdSignInAfterPasswordReset, context: context)

        guard let continuationToken = flowContinuationState.continuationToken else {
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: MSALNativeAuthErrorMessage.missingContinuationToken)),
                event: event,
                context: context,
                scenario: flowContinuationState.flowScenario
            )
        }

        let step = MSALNativeAuthFlowStepContext(apiId: .telemetryApiIdSignInAfterPasswordReset, event: event, context: context)
        return await completeWithToken(
            flowContinuationState: flowContinuationState,
            continuationToken: continuationToken,
            step: step
        )
    }

    // MARK: - Private

    private func enrollAuthMethod(
        _ method: MSALAuthMethod,
        offeredMethods: [MSALNativeAuthV2EnrollmentMethod],
        verificationContact: String?,
        flowContinuationState: MSALNativeAuthFlowContinuationState,
        step: MSALNativeAuthFlowStepContext
    ) async -> MSALNativeAuthFlowControllerResponse {
        guard let enrollmentMethod = offeredMethods.first(where: { $0.id == method.id }) else {
            return failure(
                .error(MSALNativeAuthFlowError(type: .invalidInput, errorDescription: "Select an offered enrollment method.")),
                event: step.event,
                context: step.context,
                scenario: flowContinuationState.flowScenario
            )
        }

        guard let enrollHref = flowContinuationState.methodLink(for: method.id)?.absoluteString else {
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing enrollment link for selected auth method")),
                event: step.event,
                context: step.context,
                scenario: flowContinuationState.flowScenario
            )
        }

        guard let continuationToken = flowContinuationState.continuationToken else {
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: MSALNativeAuthErrorMessage.missingContinuationToken)),
                event: step.event,
                context: step.context,
                scenario: flowContinuationState.flowScenario
            )
        }

        guard let contact = verificationContact,
              !contact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return failure(
                .error(MSALNativeAuthFlowError(type: .invalidInput, errorDescription: "Provide a nonempty verification contact.")),
                event: step.event,
                context: step.context,
                scenario: flowContinuationState.flowScenario
            )
        }
        let result = await performInteraction(context: step.context) {
            try self.requestProvider.enroll(
                href: enrollHref,
                verificationContact: contact,
                channelType: enrollmentMethod.channelType,
                continuationToken: continuationToken,
                apiId: step.apiId,
                context: step.context
            )
        }
        return await handleInteractionResult(
            result,
            flowContinuationState: flowContinuationState,
            step: step
        )
    }

    private func performAuthMethodChallenge(
        _ method: MSALAuthMethod,
        flowContinuationState: MSALNativeAuthFlowContinuationState,
        step: MSALNativeAuthFlowStepContext
    ) async -> MSALNativeAuthV2InteractionParsedResponse {
        guard let challengeHref = flowContinuationState.methodLink(for: method.id)?.absoluteString else {
            return .error(MSALNativeAuthFlowError(
                type: .generalError,
                errorDescription: MSALNativeAuthErrorMessage.missingAuthMethodChallengeLink
            ))
        }

        guard let continuationToken = flowContinuationState.continuationToken else {
            return .error(MSALNativeAuthFlowError(
                type: .generalError,
                errorDescription: MSALNativeAuthErrorMessage.missingContinuationToken
            ))
        }

        return await performInteraction(context: step.context) {
            try self.requestProvider.challenge(
                href: challengeHref,
                continuationToken: continuationToken,
                apiId: step.apiId,
                context: step.context
            )
        }
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
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: MSALNativeAuthErrorMessage.missingContinuationToken)),
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
        return await handleInteractionResult(result, flowContinuationState: flowContinuationState, step: step)
    }

    // MARK: - Attribute collection

    /// Sign-up submits email as the username and pending profile values once; re-requesting
    /// submitted sign-up attributes fails. Other flows may ask the app to supply values again.
    private func collectAttributes(
        continuationToken: String,
        submitHref: String,
        attributes: [MSALNativeAuthRequiredAttributeInternal],
        flowContinuationState: MSALNativeAuthFlowContinuationState,
        step: MSALNativeAuthFlowStepContext
    ) async -> MSALNativeAuthFlowControllerResponse {
        if flowContinuationState.flowScenario == .signUp,
           attributes.contains(where: { $0.name.caseInsensitiveCompare("email") == .orderedSame }) {
            return failure(
                .error(MSALNativeAuthFlowError(
                    type: .generalError,
                    errorDescription: "The server requested email as an attribute after it was supplied as the sign-up username."
                )),
                event: step.event,
                context: step.context,
                scenario: flowContinuationState.flowScenario
            )
        }

        let links: [MSALNativeAuthV2LinkKey: URL]
        do {
            links = try resolveRequiredLinks([(.relation(.submitAttributes), submitHref)])
        } catch {
            return interactionFailure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Invalid attribute submission link")),
                event: step.event, context: step.context, scenario: flowContinuationState.flowScenario, newState: nil
            )
        }
        let next = flowContinuationState.successor(
            continuationToken: continuationToken, links: links, nextAction: .submitAttributes
        )

        if !next.pendingSignUpAttributes.isEmpty {
            return await performSubmitAttributes(next.pendingSignUpAttributes, flowContinuationState: next, step: step)
        }

        if attributes.contains(where: { $0.name.caseInsensitiveCompare("password") == .orderedSame }),
           flowContinuationState.flowScenario != .signUp || !flowContinuationState.hasSubmittedAttribute("password") {
            return passwordRequiredResponse(flowContinuationState: next, step: step)
        }

        if flowContinuationState.flowScenario == .signUp,
           let invalid = attributes.first(where: { flowContinuationState.hasSubmittedAttribute($0.name) }) {
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
        guard flowContinuationState.flowScenario != .signUp ||
                !attributes.keys.contains(where: { $0.caseInsensitiveCompare("email") == .orderedSame }) else {
            return failure(
                .error(MSALNativeAuthFlowError(
                    type: .generalError,
                    errorDescription: "Email must be supplied as the sign-up username, not as an attribute."
                )),
                event: step.event,
                context: step.context,
                scenario: flowContinuationState.flowScenario
            )
        }

        guard let submitHref = flowContinuationState.link(.submitAttributes)?.absoluteString else {
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing submit attributes link")),
                event: step.event,
                context: step.context, scenario: flowContinuationState.flowScenario
            )
        }

        guard let continuationToken = flowContinuationState.continuationToken else {
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: MSALNativeAuthErrorMessage.missingContinuationToken)),
                event: step.event,
                context: step.context, scenario: flowContinuationState.flowScenario
            )
        }

        let result = await performInteraction(context: step.context) {
            try self.requestProvider.submitAttributes(
                href: submitHref,
                attributes: attributes,
                continuationToken: continuationToken,
                apiId: step.apiId,
                context: step.context
            )
        }
        let submitted = flowContinuationState.addingSubmittedAttributes(Array(attributes.keys))
        return await handleInteractionResult(result, flowContinuationState: submitted, step: step)
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
        href: String,
        step: MSALNativeAuthFlowStepContext
    ) -> MSALNativeAuthFlowControllerResponse {
        let continuation = MSALNativeAuthFlowContinuationState(
            flowScenario: flowContinuationState.flowScenario,
            correlationId: flowContinuationState.correlationId,
            continuationToken: continuationToken,
            links: resolveLinks([.continue: href]),
            scopes: flowContinuationState.scopes,
            claimsRequestJson: flowContinuationState.claimsRequestJson,
            submittedAttributes: flowContinuationState.submittedAttributes
        )
        let internalState = MSALNativeAuthFlowInternalState(continuation: continuation, controller: self)
        stopTelemetryEvent(step.event, context: step.context)
        return response(
            .actionRequired(state: MSALNativeAuthSignInAfterSignUpState(internalState: internalState)),
            context: step.context
        )
    }

    // MARK: - Strong authentication registration

    private func registrationRequiredResponse(
        continuationToken: String,
        methods: [MSALNativeAuthV2EnrollmentMethod],
        flowContinuationState: MSALNativeAuthFlowContinuationState,
        step: MSALNativeAuthFlowStepContext
    ) -> MSALNativeAuthFlowControllerResponse {
        let links: [MSALNativeAuthV2LinkKey: URL]
        do {
            links = try resolveRequiredLinks(methods.map { (.method(id: $0.id), $0.enrollHref) })
        } catch {
            return interactionFailure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Invalid enrollment link")),
                event: step.event,
                context: step.context,
                scenario: flowContinuationState.flowScenario,
                newState: nil
            )
        }
        let continuation = flowContinuationState.successor(
            continuationToken: continuationToken,
            links: links,
            challengeResponse: .registrationRequired(continuationToken: continuationToken, methods: methods),
            nextAction: .enroll
        )
        let state = MSALNativeAuthStrongAuthRegistrationRequiredState(
            internalState: MSALNativeAuthFlowInternalState(continuation: continuation, controller: self),
            authMethods: methods.map(\.publicAuthMethod)
        )
        stopTelemetryEvent(step.event, context: step.context)
        return response(.actionRequired(state: state), context: step.context)
    }

    private func activateAuthMethod(
        _ code: String,
        state: MSALNativeAuthFlowInternalState
    ) async -> MSALNativeAuthFlowControllerResponse {
        let continuation = state.continuation
        let context = MSALNativeAuthRequestContext(correlationId: continuation.correlationId)
        let apiId: MSALNativeAuthTelemetryApiId = .telemetryApiIdV2JITChallenge
        let event = makeAndStartTelemetryEvent(id: apiId, context: context)
        guard let href = continuation.link(.activate)?.absoluteString else {
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing activation link")),
                event: event,
                context: context,
                scenario: continuation.flowScenario
            )
        }

        guard let token = continuation.continuationToken else {
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: MSALNativeAuthErrorMessage.missingContinuationToken)),
                event: event,
                context: context,
                scenario: continuation.flowScenario
            )
        }
        let activationResult = await performInteraction(context: context) {
            try self.requestProvider.activate(
                href: href,
                otp: code,
                continuationToken: token,
                apiId: apiId,
                context: context
            )
        }
        let result = mapChallengeVerificationError(activationResult)
        let step = MSALNativeAuthFlowStepContext(apiId: apiId, event: event, context: context)
        return await handleInteractionResult(result, flowContinuationState: continuation, step: step)
    }

    // MARK: - Sign-in result mapping

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

    private enum AuthMethodSelectionContinuationError: Error {
        case missingContinuationToken
        case invalidChallengeLink
    }

    /// Derives the next continuation for an auth-method-selection step.
    private func makeAuthMethodSelectionContinuation(
        from flowContinuationState: MSALNativeAuthFlowContinuationState,
        continuationToken: String? = nil,
        methods: [MSALNativeAuthV2ChallengeMethod],
        challengeResponse: MSALNativeAuthV2InteractionParsedResponse
    ) -> Result<MSALNativeAuthFlowContinuationState, AuthMethodSelectionContinuationError> {
        let continuationToken = continuationToken ?? flowContinuationState.continuationToken
        guard let continuationToken else {
            return .failure(.missingContinuationToken)
        }

        let resolvedLinks: [MSALNativeAuthV2LinkKey: URL]
        do {
            resolvedLinks = try resolveRequiredLinks(methods.map { (.method(id: $0.id), $0.challengeHref) })
        } catch {
            return .failure(.invalidChallengeLink)
        }
        return .success(flowContinuationState.successor(
            continuationToken: continuationToken,
            links: resolvedLinks,
            challengeResponse: challengeResponse,
            nextAction: .challenge
        ))
    }

    private func authMethodSelectionRequiredResponse(
        flowContinuationState: MSALNativeAuthFlowContinuationState,
        methods: [MSALNativeAuthV2ChallengeMethod],
        step: MSALNativeAuthFlowStepContext
    ) -> MSALNativeAuthFlowControllerResponse {
        let internalState = MSALNativeAuthFlowInternalState(continuation: flowContinuationState, controller: self)
        stopTelemetryEvent(step.event, context: step.context)
        return response(
            .actionRequired(state: MSALNativeAuthAuthMethodSelectionRequiredState(
                internalState: internalState,
                authMethods: methods.map(\.publicAuthMethod)
            )),
            context: step.context
        )
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
        return response(.actionRequired(state: state), context: step.context, scenario: flowContinuationState.flowScenario)
    }

    private func completeSignIn(
        flowContinuationState: MSALNativeAuthFlowContinuationState,
        continuationToken: String,
        href: String,
        step: MSALNativeAuthFlowStepContext
    ) async -> MSALNativeAuthFlowControllerResponse {
        let next = makeContinuation(from: flowContinuationState, continuationToken: continuationToken, links: [.continue: href])
        return await completeWithToken(
            flowContinuationState: next,
            continuationToken: continuationToken,
            step: step
        )
    }

    // MARK: - Shared interaction result mapping

    // Routes the next server-directed step for sign-up, sign-in, or password reset.
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func handleInteractionResult(
        _ result: MSALNativeAuthV2InteractionParsedResponse,
        flowContinuationState: MSALNativeAuthFlowContinuationState,
        step: MSALNativeAuthFlowStepContext,
        pollsRemaining: Int = 5
    ) async -> MSALNativeAuthFlowControllerResponse {
        switch result {
        case .challengeRequired(let token, let offeredMethods), .mfaRequired(let token, let offeredMethods):
            let continuation = flowContinuationState
            let methods = offeredMethods
            guard !methods.isEmpty else {
                return interactionFailure(
                    .error(MSALNativeAuthFlowError(
                        type: .generalError,
                        errorDescription: MSALNativeAuthErrorMessage.noSupportedAuthMethodAvailable
                    )),
                    event: step.event, context: step.context, scenario: continuation.flowScenario, newState: nil
                )
            }
            let next: MSALNativeAuthFlowContinuationState
            switch makeAuthMethodSelectionContinuation(
                from: continuation, continuationToken: token, methods: methods, challengeResponse: result
            ) {
            case .success(let selection):
                next = selection
            case .failure(let error):
                return makeAuthMethodSelectionContinuationFailure(
                    error, event: step.event, context: step.context, scenario: continuation.flowScenario
                )
            }
            if next.isMFAChallenge || methods.count > 1 {
                return authMethodSelectionRequiredResponse(flowContinuationState: next, methods: methods, step: step)
            }
            let method = methods[0]
            let challengeResult = await performAuthMethodChallenge(method.publicAuthMethod, flowContinuationState: next, step: step)
            return await handleInteractionResult(
                challengeResult, flowContinuationState: next, step: step,
                pollsRemaining: pollsRemaining
            )
        case .attributesRequired(let token, let submitHref, let attributes):
            return await collectAttributes(
                continuationToken: token,
                submitHref: submitHref,
                attributes: attributes,
                flowContinuationState: flowContinuationState,
                step: step
            )
        case .verificationRequired(let token, let verifyHref, let resendHref, let sentTo, let channelType, let codeLength):
            guard channelType.isEmailType || channelType.isSMSType || channelType.isPasswordType else {
                return interactionFailure(
                    result, event: step.event, context: step.context, scenario: flowContinuationState.flowScenario, newState: nil
                )
            }
            let links: [MSALNativeAuthV2LinkKey: URL]
            do {
                var requiredLinks: [(MSALNativeAuthV2LinkKey, String)] = [(.relation(.verify), verifyHref)]
                if let resendHref { requiredLinks.append((.relation(.resend), resendHref)) }
                links = try resolveRequiredLinks(requiredLinks)
            } catch {
                return interactionFailure(
                    .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Invalid verification or resend link")),
                    event: step.event, context: step.context, scenario: flowContinuationState.flowScenario, newState: nil
                )
            }
            let next = flowContinuationState.successor(
                continuationToken: token, links: links, nextAction: .verify
            )
            if channelType.isPasswordType {
                return passwordRequiredResponse(flowContinuationState: next, step: step)
            }
            if next.isMFAChallenge {
                return mfaVerificationRequiredResponse(
                    flowContinuationState: next, sentTo: sentTo, channelType: channelType, codeLength: codeLength, step: step
                )
            }
            return codeRequiredResponse(flowContinuationState: next, sentTo: sentTo, channelType: channelType, codeLength: codeLength, step: step)
        case .activationRequired(let token, let href, let resendHref, let sentTo, let codeLength, let responseChannel):
            guard let channel = responseChannel,
                  channel.isEmailType || channel.isSMSType else {
                return interactionFailure(
                    .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing or unsupported activation channel")),
                    event: step.event, context: step.context, scenario: flowContinuationState.flowScenario, newState: nil
                )
            }
            let links: [MSALNativeAuthV2LinkKey: URL]
            do {
                var requiredLinks: [(MSALNativeAuthV2LinkKey, String)] = [(.relation(.activate), href)]
                if let resendHref { requiredLinks.append((.relation(.resend), resendHref)) }
                links = try resolveRequiredLinks(requiredLinks)
            } catch {
                return interactionFailure(
                    .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Invalid activation or resend link")),
                    event: step.event, context: step.context, scenario: flowContinuationState.flowScenario, newState: nil
                )
            }
            let next = flowContinuationState.successor(
                continuationToken: token, links: links, challengeResponse: result, nextAction: .activate
            )
            let state = MSALNativeAuthStrongAuthVerificationRequiredState(
                internalState: MSALNativeAuthFlowInternalState(continuation: next, controller: self),
                sentTo: sentTo, channel: channel, codeLength: codeLength
            )
            stopTelemetryEvent(step.event, context: step.context)
            return response(.actionRequired(state: state), context: step.context)
        case .updateRequired(let token, let updateHref):
            let links: [MSALNativeAuthV2LinkKey: URL]
            do {
                links = try resolveRequiredLinks([(.relation(.update), updateHref)])
            } catch {
                return interactionFailure(
                    .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Invalid password update link")),
                    event: step.event, context: step.context, scenario: flowContinuationState.flowScenario, newState: nil
                )
            }
            let next = flowContinuationState.successor(continuationToken: token, links: links)
            return newPasswordRequiredResponse(flowContinuationState: next, step: step)
        case .readyToComplete(let token, let href):
            do {
                _ = try resolveRequiredLinks([(.relation(.continue), href)])
            } catch {
                return interactionFailure(
                    .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Invalid authorize-challenge continue link")),
                    event: step.event, context: step.context, scenario: flowContinuationState.flowScenario, newState: nil
                )
            }
            switch flowContinuationState.flowScenario {
            case .signUp:
                return signInAfterSignUpResponse(flowContinuationState: flowContinuationState, continuationToken: token, href: href, step: step)
            case .signIn:
                return await completeSignIn(flowContinuationState: flowContinuationState, continuationToken: token, href: href, step: step)
            case .passwordReset:
                return signInAfterResetPasswordResponse(
                    flowContinuationState: flowContinuationState, continuationToken: token, href: href, step: step
                )
            default:
                return interactionFailure(
                    result, event: step.event, context: step.context, scenario: flowContinuationState.flowScenario, newState: nil
                )
            }
        case .registrationRequired(let token, let methods):
            return registrationRequiredResponse(
                continuationToken: token,
                methods: methods,
                flowContinuationState: flowContinuationState,
                step: step
            )
        case .pollInProgress(let token, let href):
            guard pollsRemaining > 0 else {
                return interactionFailure(
                    .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Polling timed out after five attempts")),
                    event: step.event, context: step.context, scenario: flowContinuationState.flowScenario, newState: nil
                )
            }
            if pollsRemaining < 5 {
                do {
                    try await Task.sleep(nanoseconds: UInt64(pollIntervalSeconds * 1_000_000_000))
                } catch {
                    return interactionFailure(
                        .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Polling was cancelled")),
                        event: step.event, context: step.context, scenario: flowContinuationState.flowScenario, newState: nil
                    )
                }
            }
            let nextResult = await performInteraction(context: step.context) {
                return try self.requestProvider.poll(href: href, continuationToken: token, apiId: step.apiId, context: step.context)
            }
            let next = flowContinuationState.successor(
                continuationToken: token, links: [:], challengeResponse: flowContinuationState.challengeResponse
            )
            return await handleInteractionResult(
                nextResult, flowContinuationState: next, step: step,
                pollsRemaining: pollsRemaining - 1
            )
        case .error:
            return interactionFailure(result, event: step.event, context: step.context, scenario: flowContinuationState.flowScenario, newState: nil)
        }
    }

    // MARK: - Response builders

    /// Retains flow context while replacing the token and links with the successor's values.
    private func makeContinuation(
        from flowContinuationState: MSALNativeAuthFlowContinuationState,
        continuationToken: String,
        links: [MSALNativeAuthV2LinkRelation: String?]
    ) -> MSALNativeAuthFlowContinuationState {
        return flowContinuationState.successor(
            continuationToken: continuationToken,
            links: resolveLinks(links)
        )
    }

    private func makeAuthMethodSelectionContinuationFailure(
        _ error: AuthMethodSelectionContinuationError,
        event: MSIDTelemetryAPIEvent?,
        context: MSALNativeAuthRequestContext,
        scenario: MSALNativeAuthFlowScenario
    ) -> MSALNativeAuthFlowControllerResponse {
        switch error {
        case .missingContinuationToken:
            let flowError = MSALNativeAuthFlowError(
                type: .generalError,
                errorDescription: MSALNativeAuthErrorMessage.missingContinuationToken,
                correlationId: context.correlationId()
            )
            return interactionFailure(.error(flowError), event: event, context: context, scenario: scenario, newState: nil)
        case .invalidChallengeLink:
            let error = MSALNativeAuthFlowError(
                type: .generalError,
                errorDescription: MSALNativeAuthErrorMessage.invalidAuthMethodChallengeLink,
                correlationId: context.correlationId()
            )
            return interactionFailure(.error(error), event: event, context: context, scenario: scenario, newState: nil)
        }
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
        href: String,
        step: MSALNativeAuthFlowStepContext
    ) -> MSALNativeAuthFlowControllerResponse {
        let continuation = makeContinuation(from: flowContinuationState, continuationToken: continuationToken, links: [.continue: href])
        let internalState = MSALNativeAuthFlowInternalState(continuation: continuation, controller: self)
        stopTelemetryEvent(step.event, context: step.context)
        return response(
            .actionRequired(state: MSALNativeAuthSignInAfterResetPasswordState(internalState: internalState)),
            context: step.context,
            scenario: flowContinuationState.flowScenario
        )
    }

    private func completeWithToken(
        flowContinuationState: MSALNativeAuthFlowContinuationState,
        continuationToken: String,
        step: MSALNativeAuthFlowStepContext
    ) async -> MSALNativeAuthFlowControllerResponse {
        guard let href = flowContinuationState.link(.continue)?.absoluteString else {
            MSALNativeAuthLogger.log(level: .error, context: step.context, format: "Missing authorize-challenge continue link")
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing authorize-challenge continue link")),
                event: step.event,
                context: step.context,
                scenario: flowContinuationState.flowScenario
            )
        }
        let codeResult = await performAuthorizeChallengeContinue(
            flowScenario: flowContinuationState.flowScenario,
            continuationToken: continuationToken,
            href: href,
            apiId: step.apiId,
            context: step.context
        )
        guard case .authorizationCode(let code) = codeResult else {
            return failure(codeResult, event: step.event, context: step.context, scenario: flowContinuationState.flowScenario)
        }

        let tokenResponseResult = await performTokenExchange(
            code: code,
            apiId: step.apiId,
            context: step.context
        )
        switch tokenResponseResult {
        case .success(let tokenResponse):
            do {
                let msidConfiguration = resultFactory.makeMSIDConfiguration(scopes: flowContinuationState.scopes)
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
            stopTelemetryEvent(step.event, context: step.context, error: flowError.isBrowserRequired ? nil : flowError)
            return response(.error(error: flowError), context: step.context, scenario: flowContinuationState.flowScenario)
        }
    }

    /// Builds the `/token` request, delegates the send/parse to the shared token-request handler, and
    /// hands the outcome to the parser for classification, so an embedded server error is surfaced as
    /// `.error` rather than a "successful" token response with no tokens.
    private func performTokenExchange(
        code: String,
        apiId: MSALNativeAuthTelemetryApiId,
        context: MSALNativeAuthRequestContext
    ) async -> MSALNativeAuthV2TokenParsedResponse {
        let request: MSIDHttpRequestProtocol
        do {
            request = try requestProvider.token(
                code: code,
                scopes: [],
                claimsRequestJson: nil,
                apiId: apiId,
                context: context
            )
        } catch {
            return responseParser.parseToken(context: context, .failure(error))
        }

        let result = await performTokenRequest(
            request,
            requestCorrelationId: context.correlationId().uuidString,
            context: context
        )
        return responseParser.parseToken(context: context, result)
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

    private func resolveRequiredLinks(_ links: [(MSALNativeAuthV2LinkKey, String)]) throws -> [MSALNativeAuthV2LinkKey: URL] {
        let resolver = MSALNativeAuthV2HrefURLResolver(config: config)
        var resolvedLinks: [MSALNativeAuthV2LinkKey: URL] = [:]
        for (key, href) in links {
            resolvedLinks[key] = try resolver.url(forHref: href)
        }
        return resolvedLinks
    }

    // MARK: - Shared step helpers

    private func performAuthorizeChallengeStart(
        flowScenario: MSALNativeAuthFlowScenario,
        scopes: [String]? = nil,
        claimsRequestJson: String? = nil,
        apiId: MSALNativeAuthTelemetryApiId,
        context: MSALNativeAuthRequestContext
    ) async -> MSALNativeAuthV2AuthorizeChallengeParsedResponse {
        let result: Result<MSALNativeAuthHALResponse, Error> = await send(context: context) {
            try self.requestProvider.authorizeChallengeStart(
                scopes: scopes,
                claimsRequestJson: claimsRequestJson,
                apiId: apiId,
                context: context
            )
        }
        return responseParser.parseAuthorizeChallenge(context: context, result, flowScenario: flowScenario)
    }

    private func performAuthorizeChallengeContinue(
        flowScenario: MSALNativeAuthFlowScenario,
        continuationToken: String,
        href: String,
        apiId: MSALNativeAuthTelemetryApiId,
        context: MSALNativeAuthRequestContext
    ) async -> MSALNativeAuthV2AuthorizeChallengeParsedResponse {
        let result: Result<MSALNativeAuthHALResponse, Error> = await send(context: context) {
            try self.requestProvider.authorizeChallengeContinue(continuationToken: continuationToken, href: href, apiId: apiId, context: context)
        }
        return responseParser.parseAuthorizeChallenge(context: context, result, flowScenario: flowScenario)
    }

    private func performInteraction(
        context: MSALNativeAuthRequestContext,
        requestBuilder: @escaping () throws -> MSIDHttpRequestProtocol
    ) async -> MSALNativeAuthV2InteractionParsedResponse {
        let result: Result<MSALNativeAuthHALResponse, Error> = await send(context: context, requestBuilder)
        return responseParser.parseInteraction(context: context, result)
    }

    private func send(
        context: MSALNativeAuthRequestContext,
        _ requestBuilder: @escaping () throws -> MSIDHttpRequestProtocol
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
        stopTelemetryEvent(event, context: context, error: error.isBrowserRequired ? nil : error)
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
        // Browser fallback remains a successful handoff for interaction telemetry.
        stopTelemetryEvent(event, context: context, error: error.isBrowserRequired ? nil : error)
        return response(.error(error: error), context: context, scenario: scenario)
    }
}
