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

import Foundation

@_implementationOnly import MSAL_Private

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
final class MSALNativeAuthV2FlowController: MSALNativeAuthBaseController, MSALNativeAuthV2FlowControlling, MSALNativeAuthTokenRequestHandling {

    private let config: MSALNativeAuthInternalConfiguration
    private let requestProvider: MSALNativeAuthV2RequestProviding
    private let responseValidator: MSALNativeAuthV2ResponseValidating
    private let cacheAccessor: MSALNativeAuthCacheInterface
    private let resultFactory: MSALNativeAuthResultBuildable
    private let tokenCacher: MSALNativeAuthTokenCacher

    private let kNumberOfTimesToRetryPollCompletionCall = 5
    private let pollIntervalNanoseconds: UInt64 = 1_500_000_000 // 1.5s

    init(
        config: MSALNativeAuthInternalConfiguration,
        requestProvider: MSALNativeAuthV2RequestProviding,
        responseValidator: MSALNativeAuthV2ResponseValidating,
        cacheAccessor: MSALNativeAuthCacheInterface,
        resultFactory: MSALNativeAuthResultBuildable
    ) {
        self.config = config
        self.requestProvider = requestProvider
        self.responseValidator = responseValidator
        self.cacheAccessor = cacheAccessor
        self.resultFactory = resultFactory
        self.tokenCacher = MSALNativeAuthTokenCacher(cacheAccessor: cacheAccessor)
        super.init(clientId: config.clientId)
    }

    convenience init(config: MSALNativeAuthInternalConfiguration, cacheAccessor: MSALNativeAuthCacheInterface) {
        self.init(
            config: config,
            requestProvider: MSALNativeAuthV2RequestProvider(config: config),
            responseValidator: MSALNativeAuthV2ResponseValidator(),
            cacheAccessor: cacheAccessor,
            resultFactory: MSALNativeAuthResultFactory(config: config, cacheAccessor: cacheAccessor)
        )
    }

    // MARK: - Entry points

    func signUp(parameters: MSALNativeAuthSignUpParametersV2) async -> MSALNativeAuthV2FlowControllerResponse {
        let flowScenario: MSALNativeAuthFlowScenario = .signUp
        let context = MSALNativeAuthRequestContext(correlationId: parameters.correlationId)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2SignUpStart, context: context)
        let scopes = joinScopes(parameters.scopes)

        // Authorization challenge (expects 401 + continuation token + sign_up link).
        let authorizationChallenge = await performAuthorizeChallengeStart(flowScenario: flowScenario, context: context)
        guard case .continuationToken(let continuationToken, let signUpLink) = authorizationChallenge else {
            return failure(authorizationChallenge, event: event, context: context, scenario: flowScenario)
        }

        let startResult = await performInteraction(context: context) {
            try self.requestProvider.signUpStart(
                username: parameters.username,
                continuationToken: continuationToken,
                href: signUpLink,
                context: context
            )
        }

        // The APIs request attributes at specific parts of the SingUp process
        // so they must be carried privately for the whole flow
        var autofillValues: [String: Any] = ["email": parameters.username]
        if let attributes = parameters.attributes {
            autofillValues.merge(attributes) { _, new in new }
        }
        if let password = parameters.password {
            autofillValues["password"] = password
        }

        return await mapInteraction(
            startResult,
            flowScenario: flowScenario,
            username: parameters.username,
            scopes: scopes,
            event: event,
            context: context,
            signUpAutofillValues: autofillValues
        )
    }

    // swiftlint:disable:next function_body_length
    func signIn(parameters: MSALNativeAuthSignInParameters) async -> MSALNativeAuthV2FlowControllerResponse {
        let flowScenario: MSALNativeAuthFlowScenario = .signIn
        let context = MSALNativeAuthRequestContext(correlationId: parameters.correlationId)
        let apiId: MSALNativeAuthTelemetryApiId = parameters.password != nil
        ? .telemetryApiIdV2SignInWithPasswordStart
        : .telemetryApiIdV2SignInWithCodeStart
        let event = makeAndStartTelemetryEvent(id: apiId, context: context)
        let scopes = joinScopes(parameters.scopes)

        // Authorization challenge (expects 401 + continuation token + sign_in link).
        let authorizationChallenge = await performAuthorizeChallengeStart(flowScenario: flowScenario, context: context)
        guard case .continuationToken(let continuationToken, let signInLink) = authorizationChallenge else {
            return failure(authorizationChallenge, event: event, context: context, scenario: flowScenario)
        }

        let startResult = await performInteraction(context: context) {
            try self.requestProvider.signInStart(
                username: parameters.username,
                continuationToken: continuationToken,
                href: signInLink,
                context: context
            )
        }

        let challengeContinuationToken: String
        let challengeHref: String
        let challengeHint: String?

        switch startResult {
        case .signInMethods(let token, let methods):
            // Pick a method: password when a password was supplied, otherwise the first OTP method.
            let passwordMethod = methods.first { ($0.type ?? "") == "password" }
            let otpMethod = methods.first { ($0.type ?? "") != "password" }
            let chosen: MSALNativeAuthHALResponse.EmbeddedMethod?
            if parameters.password != nil, let passwordMethod = passwordMethod {
                chosen = passwordMethod
            } else {
                chosen = otpMethod ?? passwordMethod
            }

            guard let method = chosen, let href = method.links["challenge"] else {
                return failure(
                    .error(
                        MSALNativeAuthFlowError(
                            type: .generalError,
                            errorDescription: "No usable sign-in method returned"
                        )
                    ),
                    event: event,
                    context: context, scenario: flowScenario
                )
            }
            challengeContinuationToken = token
            challengeHref = href
            challengeHint = method.hint
        case .challengeRequired(let token, let href, let hint):
            challengeContinuationToken = token
            challengeHref = href
            challengeHint = hint
        default:
            return await mapInteraction(
                startResult,
                flowScenario: flowScenario,
                username: parameters.username,
                scopes: scopes,
                event: event,
                context: context
            )
        }

        let challengeResult = await performInteraction(context: context) {
            try self.requestProvider.challenge(href: challengeHref, continuationToken: challengeContinuationToken, context: context)
        }

        if let password = parameters.password, case .passwordRequired(let token, let verifyHref) = challengeResult {
            let verifyResult = await performInteraction(context: context) {
                try self.requestProvider.submitPassword(href: verifyHref, password: password, continuationToken: token, context: context)
            }
            return await mapInteraction(
                verifyResult,
                flowScenario: flowScenario,
                username: parameters.username,
                scopes: scopes,
                event: event,
                context: context
            )
        }

        return await mapInteraction(
            challengeResult,
            flowScenario: flowScenario,
            username: parameters.username,
            scopes: scopes,
            event: event,
            context: context,
            fallbackHint: challengeHint
        )
    }

    func resetPassword(parameters: MSALNativeAuthResetPasswordParametersV2) async -> MSALNativeAuthV2FlowControllerResponse {
        let flowScenario: MSALNativeAuthFlowScenario = .passwordReset
        let context = MSALNativeAuthRequestContext(correlationId: parameters.correlationId)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2ResetPasswordStart, context: context)
        let scopes = joinScopes(parameters.scopes)

        // Authorization challenge (expects 401 + continuation token + reset_password link).
        let authorizationChallenge = await performAuthorizeChallengeStart(flowScenario: flowScenario, context: context)
        guard case .continuationToken(let continuationToken, let resetPasswordLink) = authorizationChallenge else {
            return failure(authorizationChallenge, event: event, context: context, scenario: flowScenario)
        }

        let startResult = await performInteraction(context: context) {
            try self.requestProvider.resetPasswordStart(
                username: parameters.username,
                continuationToken: continuationToken,
                href: resetPasswordLink,
                context: context
            )
        }

        guard case .challengeRequired(let challengeContinuationToken, let challengeHref, let hint) = startResult else {
            return interactionFailure(startResult, event: event, context: context, scenario: flowScenario, newState: nil)
        }

        let challengeResult = await performInteraction(context: context) {
            try self.requestProvider.challenge(href: challengeHref, continuationToken: challengeContinuationToken, context: context)
        }

        return handleCodeRequired(
            challengeResult,
            flowScenario: flowScenario,
            username: parameters.username,
            fallbackHint: hint,
            scopes: scopes,
            event: event,
            context: context
        )
    }

    // MARK: - Continuation

    // swiftlint:disable:next function_body_length
    func submitCode(_ code: String, state: MSALNativeAuthFlowState) async -> MSALNativeAuthV2FlowControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: nil)
        let continuation = state.continuation

        guard let verifyHref = continuation.link("verify")?.absoluteString else {
            let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2ResetPasswordSubmitCode, context: context)
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing verify link")),
                event: event,
                context: context, scenario: continuation.flowScenario
            )
        }

        switch continuation.flowScenario {
        case .signIn, .signUp:
            let apiId: MSALNativeAuthTelemetryApiId = continuation.flowScenario == .signUp
            ? .telemetryApiIdV2SignUpSubmitCode
            : .telemetryApiIdV2SignInSubmitCode
            let event = makeAndStartTelemetryEvent(id: apiId, context: context)
            let result = await performInteraction(context: context) {
                try self.requestProvider.verify(href: verifyHref, otp: code, continuationToken: continuation.continuationToken, context: context)
            }
            return await mapInteraction(
                result,
                flowScenario: continuation.flowScenario,
                username: continuation.username,
                scopes: continuation.scopes,
                event: event,
                context: context,
                recoverableState: state,
                signUpAutofillValues: continuation.signUpAutofillValues,
                signUpAutofillSubmittedIds: continuation.signUpAutofillSubmittedIds
            )
        case .passwordReset:
            let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2ResetPasswordSubmitCode, context: context)
            let result = await performInteraction(context: context) {
                try self.requestProvider.verify(href: verifyHref, otp: code, continuationToken: continuation.continuationToken, context: context)
            }
            switch result {
            case .updateRequired(let token, let updateHref):
                let newState = makeState(
                    continuation.flowScenario,
                    continuationToken: token,
                    links: ["update": updateHref],
                    username: continuation.username,
                    scopes: continuation.scopes
                )
                stopTelemetryEvent(event, context: context)
                return response(.actionRequired(action: .newPasswordRequired, newState: newState), context: context, scenario: continuation.flowScenario)
            case .error(let error):
                // Recoverable: allow the app to retry with the same code-required state.
                return interactionFailure(result, event: event, context: context, scenario: continuation.flowScenario, newState: error.isInvalidCode ? state : nil)
            default:
                return interactionFailure(result, event: event, context: context, scenario: continuation.flowScenario, newState: nil)
            }
        case .unknown:
            let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2ResetPasswordSubmitCode, context: context)
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Unknown flow for verify link")),
                event: event,
                context: context, scenario: continuation.flowScenario
            )
        }
    }

    func submitPassword(_ password: String, state: MSALNativeAuthFlowState) async -> MSALNativeAuthV2FlowControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: nil)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2SignInSubmitPassword, context: context)
        let continuation = state.continuation

        guard let verifyHref = continuation.link("verify")?.absoluteString else {
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing verify link")),
                event: event,
                context: context, scenario: continuation.flowScenario
            )
        }

        let result = await performInteraction(context: context) {
            try self.requestProvider.submitPassword(
                href: verifyHref,
                password: password,
                continuationToken: continuation.continuationToken,
                context: context
            )
        }
        return await mapInteraction(
            result,
            flowScenario: continuation.flowScenario,
            username: continuation.username,
            scopes: continuation.scopes,
            event: event,
            context: context,
            recoverableState: state
        )
    }

    // swiftlint:disable:next function_body_length
    func submitNewPassword(_ password: String, state: MSALNativeAuthFlowState) async -> MSALNativeAuthV2FlowControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: nil)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2ResetPasswordSubmit, context: context)
        let continuation = state.continuation

        guard let updateHref = continuation.link("update")?.absoluteString else {
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing update link")),
                event: event,
                context: context, scenario: continuation.flowScenario
            )
        }

        let updateResult = await performInteraction(context: context) {
            try self.requestProvider.updatePassword(
                href: updateHref,
                newPassword: password,
                continuationToken: continuation.continuationToken,
                context: context
            )
        }

        guard case .pollInProgress(var pollToken, let pollHref) = updateResult else {
            return interactionFailure(updateResult, event: event, context: context, scenario: continuation.flowScenario, newState: nil)
        }

        var completionToken: String?
        for attempt in 0..<kNumberOfTimesToRetryPollCompletionCall {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
            }

            let pollResult = await performInteraction(context: context) {
                try self.requestProvider.poll(href: pollHref, continuationToken: pollToken, context: context)
            }

            switch pollResult {
            case .readyToComplete(let token):
                completionToken = token
            case .pollInProgress(let token, _):
                pollToken = token
                continue
            case .error:
                return interactionFailure(pollResult, event: event, context: context, scenario: continuation.flowScenario, newState: nil)
            default:
                return interactionFailure(pollResult, event: event, context: context, scenario: continuation.flowScenario, newState: nil)
            }

            if completionToken != nil {
                break
            }
        }

        guard let completionToken = completionToken else {
            return failure(
                .error(
                    MSALNativeAuthFlowError(
                        type: .generalError,
                        errorDescription: "Password reset did not complete in time"
                    )
                ),
                event: event,
                context: context, scenario: continuation.flowScenario
            )
        }

        return await completeWithToken(
            flowScenario: continuation.flowScenario,
            continuationToken: completionToken,
            username: continuation.username,
            scopes: continuation.scopes,
            event: event,
            context: context
        )
    }

    func submitAttributes(_ attributes: [String: Any], state: MSALNativeAuthFlowState) async -> MSALNativeAuthV2FlowControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: nil)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2SignUpSubmitAttributes, context: context)
        let continuation = state.continuation

        guard let submitHref = continuation.link("submitAttributes")?.absoluteString else {
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing submit-attributes link")),
                event: event,
                context: context, scenario: continuation.flowScenario
            )
        }

        let result = await performInteraction(context: context) {
            try self.requestProvider.submitAttributes(
                href: submitHref,
                attributes: attributes,
                continuationToken: continuation.continuationToken,
                context: context
            )
        }
        return await mapInteraction(
            result,
            flowScenario: continuation.flowScenario,
            username: continuation.username,
            scopes: continuation.scopes,
            event: event,
            context: context,
            recoverableState: state,
            signUpAutofillValues: continuation.signUpAutofillValues,
            signUpAutofillSubmittedIds: continuation.signUpAutofillSubmittedIds
        )
    }

    // swiftlint:disable:next function_body_length
    func selectAuthMethod(
        _ method: MSALAuthMethod,
        verificationContact: String?,
        state: MSALNativeAuthFlowState
    ) async -> MSALNativeAuthV2FlowControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: nil)
        let continuation = state.continuation

        // JIT (strong-auth registration) carries an `enroll` link; MFA carries a `challenge` link.
        if continuation.link("enroll") != nil {
            guard let enrollHref = (continuation.methodLink(for: method.id) ?? continuation.link("enroll"))?.absoluteString else {
                let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2JITChallenge, context: context)
                return failure(
                    .error(
                        MSALNativeAuthFlowError(
                            type: .generalError,
                            errorDescription: "Missing enroll link for selected method"
                        )
                    ),
                    event: event,
                    context: context, scenario: continuation.flowScenario
                )
            }
            let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2JITChallenge, context: context)
            let result = await performInteraction(context: context) {
                try self.requestProvider.registerMethod(
                    href: enrollHref,
                    target: verificationContact,
                    continuationToken: continuation.continuationToken,
                    context: context
                )
            }
            return await mapInteraction(
                result,
                flowScenario: continuation.flowScenario,
                username: continuation.username,
                scopes: continuation.scopes,
                event: event,
                context: context
            )
        } else {
            guard let challengeHref = (continuation.methodLink(for: method.id) ?? continuation.link("challenge"))?.absoluteString else {
                let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2MFAGetAuthMethods, context: context)
                return failure(
                    .error(
                        MSALNativeAuthFlowError(
                            type: .generalError,
                            errorDescription: "Missing challenge link for selected method"
                        )
                    ),
                    event: event,
                    context: context, scenario: continuation.flowScenario
                )
            }
            let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2MFAGetAuthMethods, context: context)
            let result = await performInteraction(context: context) {
                try self.requestProvider.challenge(href: challengeHref, continuationToken: continuation.continuationToken, context: context)
            }

            switch result {
            case .codeRequired(let token, let verifyHref, let resendHref, let sentTo, let codeLength):
                let newState = makeState(
                    continuation.flowScenario,
                    continuationToken: token,
                    links: ["verify": verifyHref, "resend": resendHref],
                    username: continuation.username,
                    sentToHint: sentTo.isEmpty ? continuation.sentToHint : sentTo,
                    codeLength: codeLength,
                    scopes: continuation.scopes
                )
                stopTelemetryEvent(event, context: context)
                return response(.actionRequired(
                    action: .mfaVerificationRequired(sentTo: sentTo, channel: MSALNativeAuthChannelType(value: "email"), codeLength: codeLength),
                    newState: newState
                ), context: context, scenario: continuation.flowScenario)
            default:
                return await mapInteraction(
                    result,
                    flowScenario: continuation.flowScenario,
                    username: continuation.username,
                    scopes: continuation.scopes,
                    event: event,
                    context: context
                )
            }
        }
    }

    func submitChallenge(_ challenge: String, state: MSALNativeAuthFlowState) async -> MSALNativeAuthV2FlowControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: nil)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2MFASubmitChallenge, context: context)
        let continuation = state.continuation

        // JIT activation uses the `activate` link and submits the code via the `code` field;
        // MFA uses the `verify` link and submits the code via the `otp` field.
        let submitHref: String
        let isActivation: Bool
        if let activateHref = continuation.link("activate")?.absoluteString {
            submitHref = activateHref
            isActivation = true
        } else if let verifyHref = continuation.link("verify")?.absoluteString {
            submitHref = verifyHref
            isActivation = false
        } else {
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing verify link")),
                event: event,
                context: context, scenario: continuation.flowScenario
            )
        }

        let result = await performInteraction(context: context) {
            if isActivation {
                return try self.requestProvider.submitCode(
                    href: submitHref,
                    code: challenge,
                    continuationToken: continuation.continuationToken,
                    context: context
                )
            } else {
                return try self.requestProvider.verify(
                    href: submitHref,
                    otp: challenge,
                    continuationToken: continuation.continuationToken,
                    context: context
                )
            }
        }
        return await mapInteraction(
            result,
            flowScenario: continuation.flowScenario,
            username: continuation.username,
            scopes: continuation.scopes,
            event: event,
            context: context,
            recoverableState: state
        )
    }

    func resendCode(state: MSALNativeAuthFlowState) async -> MSALNativeAuthV2FlowControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: nil)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2ResetPasswordResendCode, context: context)
        let continuation = state.continuation

        guard let resendHref = continuation.link("resend")?.absoluteString else {
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing resend link")),
                event: event,
                context: context, scenario: continuation.flowScenario
            )
        }

        let result = await performInteraction(context: context) {
            try self.requestProvider.challenge(href: resendHref, continuationToken: continuation.continuationToken, context: context)
        }

        return handleCodeRequired(
            result,
            flowScenario: continuation.flowScenario,
            username: continuation.username,
            fallbackHint: continuation.sentToHint,
            scopes: continuation.scopes,
            event: event,
            context: context
        )
    }

    // MARK: - Shared step helpers

    private func performAuthorizeChallengeStart(
        flowScenario: MSALNativeAuthFlowScenario,
        context: MSALNativeAuthRequestContext
    ) async -> MSALNativeAuthV2AuthorizeChallengeValidatedResponse {
        let result: Result<MSALNativeAuthHALResponse, Error> = await send {
            try self.requestProvider.authorizeChallengeStart(context: context)
        }
        return responseValidator.validateAuthorizeChallenge(result, flowScenario: flowScenario)
    }

    private func performAuthorizeChallengeContinue(
        flowScenario: MSALNativeAuthFlowScenario,
        continuationToken: String,
        context: MSALNativeAuthRequestContext
    ) async -> MSALNativeAuthV2AuthorizeChallengeValidatedResponse {
        let result: Result<MSALNativeAuthHALResponse, Error> = await send {
            try self.requestProvider.authorizeChallengeContinue(continuationToken: continuationToken, context: context)
        }
        return responseValidator.validateAuthorizeChallenge(result, flowScenario: flowScenario)
    }

    private func performInteraction(
        context: MSALNativeAuthRequestContext,
        requestBuilder: @escaping () throws -> MSIDHttpRequest
    ) async -> MSALNativeAuthV2InteractionValidatedResponse {
        let result: Result<MSALNativeAuthHALResponse, Error> = await send(requestBuilder)
        return responseValidator.validateInteraction(result)
    }

    private func send(
        _ requestBuilder: @escaping () throws -> MSIDHttpRequest
    ) async -> Result<MSALNativeAuthHALResponse, Error> {
        let context = MSALNativeAuthRequestContext(correlationId: nil)
        do {
            let request = try requestBuilder()
            let typedContext = (request.context as? MSALNativeAuthRequestContext) ?? context
            return await performRequest(request, context: typedContext)
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Result mapping

    private func handleCodeRequired(
        _ result: MSALNativeAuthV2InteractionValidatedResponse,
        flowScenario: MSALNativeAuthFlowScenario,
        username: String?,
        fallbackHint: String?,
        scopes: [String],
        event: MSIDTelemetryAPIEvent?,
        context: MSALNativeAuthRequestContext
    ) -> MSALNativeAuthV2FlowControllerResponse {
        switch result {
        case .codeRequired(let token, let verifyHref, let resendHref, let sentTo, let codeLength):
            let newState = makeState(
                flowScenario,
                continuationToken: token,
                links: ["verify": verifyHref, "resend": resendHref],
                username: username,
                sentToHint: sentTo.isEmpty ? fallbackHint : sentTo,
                codeLength: codeLength,
                scopes: scopes
            )
            let displaySentTo = sentTo.isEmpty ? (fallbackHint ?? "") : sentTo
            stopTelemetryEvent(event, context: context)
            return response(
                .actionRequired(
                    action: .codeRequired(sentTo: displaySentTo, channel: MSALNativeAuthChannelType(value: "email"), codeLength: codeLength),
                    newState: newState
                ),
                context: context, scenario: flowScenario
            )
        default:
            return interactionFailure(result, event: event, context: context, scenario: flowScenario, newState: nil)
        }
    }

    // Maps a validated interaction response onto a controller response (the unified, server-driven
    // branch used by sign in / sign up / MFA / JIT continuation steps). On a terminal `continue`
    // state it runs the completion (authorize-challenge → token) sequence.
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func mapInteraction(
        _ result: MSALNativeAuthV2InteractionValidatedResponse,
        flowScenario: MSALNativeAuthFlowScenario,
        username: String?,
        scopes: [String],
        event: MSIDTelemetryAPIEvent?,
        context: MSALNativeAuthRequestContext,
        recoverableState: MSALNativeAuthFlowState? = nil,
        fallbackHint: String? = nil,
        signUpAutofillValues: [String: Any]? = nil,
        signUpAutofillSubmittedIds: Set<String> = []
    ) async -> MSALNativeAuthV2FlowControllerResponse {
        switch result {
        case .readyToComplete(let token):
            return await completeWithToken(
                flowScenario: flowScenario,
                continuationToken: token,
                username: username,
                scopes: scopes,
                event: event,
                context: context
            )
        case .codeRequired(let token, let verifyHref, let resendHref, let sentTo, let codeLength):
            let newState = makeState(
                flowScenario,
                continuationToken: token,
                links: ["verify": verifyHref, "resend": resendHref],
                username: username,
                sentToHint: sentTo.isEmpty ? fallbackHint : sentTo,
                codeLength: codeLength,
                scopes: scopes,
                signUpAutofillValues: signUpAutofillValues,
                signUpAutofillSubmittedIds: signUpAutofillSubmittedIds
            )
            let displaySentTo = sentTo.isEmpty ? (fallbackHint ?? "") : sentTo
            stopTelemetryEvent(event, context: context)
            return response(.actionRequired(
                action: .codeRequired(sentTo: displaySentTo, channel: MSALNativeAuthChannelType(value: "email"), codeLength: codeLength),
                newState: newState
            ), context: context, scenario: flowScenario)
        case .passwordRequired(let token, let verifyHref):
            let newState = makeState(
                flowScenario,
                continuationToken: token,
                links: ["verify": verifyHref],
                username: username,
                scopes: scopes,
                signUpAutofillValues: signUpAutofillValues,
                signUpAutofillSubmittedIds: signUpAutofillSubmittedIds
            )
            stopTelemetryEvent(event, context: context)
            return response(.actionRequired(action: .passwordRequired, newState: newState), context: context, scenario: flowScenario)
        case .updateRequired(let token, let updateHref):
            let newState = makeState(
                flowScenario,
                continuationToken: token,
                links: ["update": updateHref],
                username: username,
                scopes: scopes,
                signUpAutofillValues: signUpAutofillValues,
                signUpAutofillSubmittedIds: signUpAutofillSubmittedIds
            )
            stopTelemetryEvent(event, context: context)
            return response(.actionRequired(action: .newPasswordRequired, newState: newState), context: context, scenario: flowScenario)
        case .attributesRequired(let token, let attributes, let submitHref):
            // Sign-up: submit values the app supplied at start (e.g. email/password) automatically.
            // The full set is kept intact for the whole flow; only the attributes the server
            // requests in this step are sent, so the app never sees them.
            if flowScenario == .signUp,
               let autoValues = autoAttributeValues(for: attributes, from: signUpAutofillValues) {
                let autoIds = Set(autoValues.keys)
                // If the server re-requests an attribute we already auto-submitted
                // we throw an error specifying this
                let repeats = autoIds.intersection(signUpAutofillSubmittedIds)
                if !repeats.isEmpty {
                    let repeatedIds = repeats.sorted().joined(separator: ", ")
                    return failure(
                        .error(MSALNativeAuthFlowError(
                            type: .generalError,
                            errorDescription: "The server re-requested attribute(s) already submitted: \(repeatedIds)."
                        )),
                        event: event,
                        context: context, scenario: flowScenario
                    )
                }
                let submitState = makeState(
                    flowScenario,
                    continuationToken: token,
                    links: ["submitAttributes": submitHref],
                    username: username,
                    scopes: scopes,
                    signUpAutofillValues: signUpAutofillValues,
                    signUpAutofillSubmittedIds: signUpAutofillSubmittedIds.union(autoIds)
                )
                stopTelemetryEvent(event, context: context)
                return await submitAttributes(autoValues, state: submitState)
            }
            let newState = makeState(
                flowScenario,
                continuationToken: token,
                links: ["submitAttributes": submitHref],
                username: username,
                scopes: scopes,
                signUpAutofillValues: signUpAutofillValues,
                signUpAutofillSubmittedIds: signUpAutofillSubmittedIds
            )
            stopTelemetryEvent(event, context: context)
            return response(.actionRequired(
                action: .attributesRequired(attributes: requiredAttributes(from: attributes)),
                newState: newState
            ), context: context, scenario: flowScenario)
        case .mfaRequired(let token, let methods, let challengeHref):
            let (authMethods, methodLinks) = authMethods(from: methods)
            let newState = makeState(
                flowScenario,
                continuationToken: token,
                links: ["challenge": challengeHref],
                username: username,
                authMethods: authMethods,
                methodLinks: methodLinks,
                scopes: scopes,
                signUpAutofillValues: signUpAutofillValues,
                signUpAutofillSubmittedIds: signUpAutofillSubmittedIds
            )
            stopTelemetryEvent(event, context: context)
            return response(.actionRequired(action: .mfaRequired(authMethods: authMethods), newState: newState), context: context, scenario: flowScenario)
        case .registrationRequired(let token, let enrollHref, let methods):
            let (authMethods, methodLinks) = authMethods(from: methods)
            let newState = makeState(
                flowScenario,
                continuationToken: token,
                links: ["enroll": enrollHref],
                username: username,
                authMethods: authMethods,
                methodLinks: methodLinks,
                scopes: scopes,
                signUpAutofillValues: signUpAutofillValues,
                signUpAutofillSubmittedIds: signUpAutofillSubmittedIds
            )
            stopTelemetryEvent(event, context: context)
            return response(.actionRequired(action: .strongAuthRegistrationRequired(authMethods: authMethods), newState: newState), context: context, scenario: flowScenario)
        case .activationRequired(let token, let activateHref, let sentTo, let codeLength):
            let newState = makeState(
                flowScenario,
                continuationToken: token,
                links: ["activate": activateHref],
                username: username,
                sentToHint: sentTo.isEmpty ? fallbackHint : sentTo,
                codeLength: codeLength,
                scopes: scopes,
                signUpAutofillValues: signUpAutofillValues,
                signUpAutofillSubmittedIds: signUpAutofillSubmittedIds
            )
            let displaySentTo = sentTo.isEmpty ? (fallbackHint ?? "") : sentTo
            stopTelemetryEvent(event, context: context)
            return response(.actionRequired(
                action: .strongAuthVerificationRequired(
                    sentTo: displaySentTo,
                    channel: MSALNativeAuthChannelType(value: "email"),
                    codeLength: codeLength
                ),
                newState: newState
            ), context: context, scenario: flowScenario)
        case .error(let error):
            stopTelemetryEvent(event, context: context, error: error)
            return response(
                .error(error: error, newState: error.isInvalidCode || error.type == .invalidPassword ? recoverableState : nil),
                context: context, scenario: flowScenario
            )
        default:
            return interactionFailure(result, event: event, context: context, scenario: flowScenario, newState: nil)
        }
    }

    /// Completion sequence shared by every flow: authorize-challenge (continue) → token exchange.
    /// The `/token` response is persisted to the shared MSAL token cache so the returned
    /// ``MSALNativeAuthUserAccountResult`` can retrieve access tokens via `getAccessToken(...)`.
    private func completeWithToken(
        flowScenario: MSALNativeAuthFlowScenario,
        continuationToken: String,
        username: String?,
        scopes: [String],
        event: MSIDTelemetryAPIEvent?,
        context: MSALNativeAuthRequestContext
    ) async -> MSALNativeAuthV2FlowControllerResponse {
        let codeResult = await performAuthorizeChallengeContinue(flowScenario: flowScenario, continuationToken: continuationToken, context: context)
        guard case .authorizationCode(let code) = codeResult else {
            return failure(codeResult, event: event, context: context, scenario: flowScenario)
        }

        let tokenResponseResult = await performTokenExchange(code: code, scopes: scopes, context: context)
        switch tokenResponseResult {
        case .success(let tokenResponse):
            do {
                let msidConfiguration = resultFactory.makeMSIDConfiguration(scopes: retrieveScopes(from: tokenResponse))
                let tokenResult = try cacheTokenResponse(tokenResponse, context: context, msidConfiguration: msidConfiguration)

                guard let accountResult = resultFactory.makeUserAccountResult(tokenResult: tokenResult, context: context) else {
                    let error = MSALNativeAuthFlowError(type: .generalError, errorDescription: "Unable to construct account result")
                    stopTelemetryEvent(event, context: context, error: error)
                    return response(.error(error: error, newState: nil), context: context, scenario: flowScenario)
                }
                stopTelemetryEvent(event, context: context)
                return response(.completed(accountResult), context: context, scenario: flowScenario)
            } catch {
                let flowError = MSALNativeAuthFlowError(type: .generalError, errorDescription: "Unable to save tokens to the cache")
                stopTelemetryEvent(event, context: context, error: flowError)
                return response(.error(error: flowError, newState: nil), context: context, scenario: flowScenario)
            }
        case .failure(let error):
            let flowError = (error as? MSALNativeAuthFlowError)
            ?? MSALNativeAuthFlowError(type: .generalError, errorDescription: (error as NSError).localizedDescription)
            stopTelemetryEvent(event, context: context, error: flowError)
            return response(.error(error: flowError, newState: nil), context: context, scenario: flowScenario)
        }
    }

    /// Builds the `/token` request and delegates the send/parse to the shared token-request handler.
    private func performTokenExchange(
        code: String,
        scopes: [String],
        context: MSALNativeAuthRequestContext
    ) async -> Result<MSIDTokenResponse, Error> {
        let request: MSIDHttpRequest
        do {
            request = try requestProvider.token(code: code, scopes: scopes, context: context)
        } catch {
            return .failure(error)
        }

        return await performTokenRequest(request, context: context).map { $0 as MSIDTokenResponse }
    }

    private func cacheTokenResponse(
        _ tokenResponse: MSIDTokenResponse,
        context: MSALNativeAuthRequestContext,
        msidConfiguration: MSIDConfiguration
    ) throws -> MSIDTokenResult {
        return try tokenCacher.cache(
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

    private func makeState(
        _ flowScenario: MSALNativeAuthFlowScenario,
        continuationToken: String,
        links: [String: String?],
        username: String?,
        sentToHint: String? = nil,
        codeLength: Int? = nil,
        authMethods: [MSALAuthMethod] = [],
        methodLinks: [String: String] = [:],
        scopes: [String] = [],
        signUpAutofillValues: [String: Any]? = nil,
        signUpAutofillSubmittedIds: Set<String> = []
    ) -> MSALNativeAuthFlowState {
        let resolver = MSALNativeAuthV2HrefURLResolver(config: config)
        var resolvedLinks: [String: URL] = [:]
        for (relation, href) in links {
            if let href = href, let url = try? resolver.url(forHref: href) {
                resolvedLinks[relation] = url
            }
        }
        for (methodId, href) in methodLinks {
            if let url = try? resolver.url(forHref: href) {
                resolvedLinks["method:\(methodId)"] = url
            }
        }
        let continuation = MSALNativeAuthV2ContinuationState(
            flowScenario: flowScenario,
            continuationToken: continuationToken,
            links: resolvedLinks,
            username: username,
            sentToHint: sentToHint,
            codeLength: codeLength,
            authMethods: authMethods,
            scopes: scopes,
            signUpAutofillValues: signUpAutofillValues,
            signUpAutofillSubmittedIds: signUpAutofillSubmittedIds
        )
        return MSALNativeAuthFlowState(continuation: continuation, controller: self)
    }

    /// Converts embedded HAL methods into public ``MSALAuthMethod`` objects plus a map of each
    /// method's action href (keyed by method id) for later selection. MFA methods carry a
    /// `challenge` link; JIT registration methods carry an `enroll`/`register` link.
    private func authMethods(
        from methods: [MSALNativeAuthHALResponse.EmbeddedMethod]
    ) -> (methods: [MSALAuthMethod], methodLinks: [String: String]) {
        var out: [MSALAuthMethod] = []
        var methodLinks: [String: String] = [:]
        for method in methods {
            let id = method.id ?? ""
            let type = method.type ?? ""
            out.append(MSALAuthMethod(
                id: id,
                challengeType: type,
                channelTargetType: MSALNativeAuthChannelType(value: type),
                loginHint: method.hint
            ))
            if let link = method.links["challenge"] ?? method.links["enroll"] ?? method.links["register"] {
                methodLinks[id] = link
            }
        }
        return (out, methodLinks)
    }

    private func requiredAttributes(
        from attributes: [MSALNativeAuthHALResponse.RequiredAttributeEntry]
    ) -> [MSALNativeAuthRequiredAttribute] {
        return attributes.map { entry in
            MSALNativeAuthRequiredAttribute(
                name: entry.id ?? "",
                type: entry.type ?? "",
                required: entry.required,
                regex: entry.regex
            )
        }
    }

    /// Returns the values needed to satisfy a `collectAttributes` request from the values the app
    /// supplied at sign-up start, but only when *every* required attribute is covered.
    /// Optional attributes are never auto-submitted
    private func autoAttributeValues(
        for requested: [MSALNativeAuthHALResponse.RequiredAttributeEntry],
        from autofill: [String: Any]?
    ) -> [String: Any]? {
        guard let autofill = autofill, !requested.isEmpty else {
            return nil
        }
        var values: [String: Any] = [:]
        for entry in requested where entry.required {
            guard let id = entry.id, let value = autofill[id] else {
                return nil
            }
            values[id] = value
        }
        return values.isEmpty ? nil : values
    }

    // MARK: - Response construction

    private func response(
        _ result: MSALNativeAuthV2FlowResult,
        context: MSALNativeAuthRequestContext,
        scenario: MSALNativeAuthFlowScenario
    ) -> MSALNativeAuthV2FlowControllerResponse {
        return MSALNativeAuthV2FlowControllerResponse(
            result,
            correlationId: context.correlationId(),
            scenario: scenario
        )
    }

    private func failure(
        _ validated: MSALNativeAuthV2AuthorizeChallengeValidatedResponse,
        event: MSIDTelemetryAPIEvent?,
        context: MSALNativeAuthRequestContext,
        scenario: MSALNativeAuthFlowScenario
    ) -> MSALNativeAuthV2FlowControllerResponse {
        let error: MSALNativeAuthFlowError
        if case .error(let flowError) = validated {
            error = flowError
        } else {
            error = MSALNativeAuthFlowError(type: .generalError, errorDescription: "Unexpected authorize-challenge response")
        }
        stopTelemetryEvent(event, context: context, error: error)
        return response(.error(error: error, newState: nil), context: context, scenario: scenario)
    }

    private func interactionFailure(
        _ validated: MSALNativeAuthV2InteractionValidatedResponse,
        event: MSIDTelemetryAPIEvent?,
        context: MSALNativeAuthRequestContext,
        scenario: MSALNativeAuthFlowScenario,
        newState: MSALNativeAuthFlowState?
    ) -> MSALNativeAuthV2FlowControllerResponse {
        let error: MSALNativeAuthFlowError
        if case .error(let flowError) = validated {
            error = flowError
        } else {
            error = MSALNativeAuthFlowError(type: .generalError, errorDescription: "Unexpected server response")
        }
        stopTelemetryEvent(event, context: context, error: error)
        return response(.error(error: error, newState: newState), context: context, scenario: scenario)
    }
}
