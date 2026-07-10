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

/// Unified controller backing the Native Auth V2 (server-driven, HAL) flows.
///
/// Mirrors the V1 controller structure (telemetry → request → validate → handle) but drives
/// the server-driven SSPR state machine end-to-end: bootstrap → reset-password start →
/// challenge → verify → update → poll → authorize-challenge → token. Sign up / sign in V2 are
/// defined for the unified contract but return `notImplemented` until their server APIs ship.
final class MSALNativeAuthV2FlowController: MSALNativeAuthBaseController, MSALNativeAuthV2FlowControlling {

    private let config: MSALNativeAuthInternalConfiguration
    private let requestProvider: MSALNativeAuthV2RequestProviding
    private let responseValidator: MSALNativeAuthV2ResponseValidating
    private let cacheAccessor: MSALNativeAuthCacheInterface
    private let resultFactory: MSALNativeAuthResultBuildable

    /// The flow currently driven by this controller instance. One controller serves a single flow's
    /// lifetime (created per entry point, reused across continuations), so this is set at the start
    /// of every public entry / continuation method and stamped onto every response — letting the
    /// delegate report the originating ``MSALNativeAuthFlowScenario`` on each callback.
    private var currentScenario: MSALNativeAuthFlowScenario = .unknown

    private let maxPollAttempts = 5
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

    func resetPassword(parameters: MSALNativeAuthResetPasswordParameters) async -> MSALNativeAuthV2FlowControllerResponse {
        currentScenario = .passwordReset
        let context = MSALNativeAuthRequestContext(correlationId: parameters.correlationId)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdResetPasswordStart, context: context)
        let scopes = joinScopes(parameters.scopes)

        // Step 1 — bootstrap authorize-challenge (expects 401 + continuation token).
        let bootstrap = await performAuthorizeChallengeStart(context: context)
        guard case .continuationToken(let bootstrapToken, _) = bootstrap else {
            return failure(bootstrap, event: event, context: context)
        }

        // Step 2 — reset-password start.
        let startResult = await performInteraction(context: context) {
            try self.requestProvider.resetPasswordStart(username: parameters.username, continuationToken: bootstrapToken, context: context)
        }

        guard case .challengeRequired(let token2, let challengeHref, let hint) = startResult else {
            return interactionFailure(startResult, event: event, context: context)
        }

        // Step 3 — auto-trigger the challenge (send EOTP).
        guard let challengeHref = challengeHref else {
            return failure(.error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing challenge link", correlationId: context.correlationId())), event: event, context: context)
        }

        let challengeResult = await performInteraction(context: context) {
            try self.requestProvider.challenge(href: challengeHref, continuationToken: token2, context: context)
        }

        return handleCodeRequired(challengeResult, username: parameters.username, fallbackHint: hint, scopes: scopes, event: event, context: context)
    }

    func signUp(parameters: MSALNativeAuthSignUpParameters) async -> MSALNativeAuthV2FlowControllerResponse {
        currentScenario = .signUp
        let context = MSALNativeAuthRequestContext(correlationId: parameters.correlationId)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdSignUp, context: context)
        let scopes = joinScopes(parameters.scopes)

        // Step 1 — bootstrap authorize-challenge (expects 401 + continuation token + sign_up link).
        let bootstrap = await performAuthorizeChallengeStart(context: context)
        guard case .continuationToken(let bootstrapToken, let links) = bootstrap else {
            return failure(bootstrap, event: event, context: context)
        }

        // Step 2 — sign-up start (auto-triggers the email challenge).
        let startResult = await performInteraction(context: context) {
            try self.requestProvider.signUpStart(
                username: parameters.username,
                continuationToken: bootstrapToken,
                href: links["sign_up"] ?? links["signup"],
                context: context
            )
        }

        return await mapInteraction(startResult, scenario: .signUp, username: parameters.username, scopes: scopes, event: event, context: context)
    }

    func signIn(parameters: MSALNativeAuthSignInParameters) async -> MSALNativeAuthV2FlowControllerResponse {
        currentScenario = .signIn
        let context = MSALNativeAuthRequestContext(correlationId: parameters.correlationId)
        let apiId: MSALNativeAuthTelemetryApiId = parameters.password != nil ? .telemetryApiIdSignInWithPasswordStart : .telemetryApiIdSignInWithCodeStart
        let event = makeAndStartTelemetryEvent(id: apiId, context: context)
        let scopes = joinScopes(parameters.scopes)

        // Step 1 — bootstrap authorize-challenge (expects 401 + continuation token + sign_in link).
        let bootstrap = await performAuthorizeChallengeStart(context: context)
        guard case .continuationToken(let bootstrapToken, let links) = bootstrap else {
            return failure(bootstrap, event: event, context: context)
        }

        // Step 2 — sign-in (method discovery).
        let startResult = await performInteraction(context: context) {
            try self.requestProvider.signInStart(
                username: parameters.username,
                continuationToken: bootstrapToken,
                href: links["sign_in"] ?? links["signin"],
                context: context
            )
        }

        // Step 3 — resolve the token and the method challenge href.
        // The server may either return `.signInMethods` (action == nil, methods embedded) so the
        // client picks a method, or collapse discovery and return `.challengeRequired` (action ==
        // "challenge") directly with the chosen method's challenge href already resolved.
        let token2: String
        let challengeHref: String

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
                return failure(.error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "No usable sign-in method returned", correlationId: context.correlationId())), event: event, context: context)
            }
            token2 = token
            challengeHref = href
        case .challengeRequired(let token, let href, _):
            guard let href = href else {
                return await mapInteraction(startResult, scenario: .signIn, username: parameters.username, scopes: scopes, event: event, context: context)
            }
            token2 = token
            challengeHref = href
        default:
            return await mapInteraction(startResult, scenario: .signIn, username: parameters.username, scopes: scopes, event: event, context: context)
        }

        // Step 4 — challenge the chosen method.
        let challengeResult = await performInteraction(context: context) {
            try self.requestProvider.challenge(href: challengeHref, continuationToken: token2, context: context)
        }

        // Step 5 — when a password was supplied and the password factor is required, submit it now
        // so password sign-in completes in one call (mirroring V1).
        if let password = parameters.password, case .passwordRequired(let token, let verifyHref) = challengeResult, let verifyHref = verifyHref {
            let verifyResult = await performInteraction(context: context) {
                try self.requestProvider.submitPassword(href: verifyHref, password: password, continuationToken: token, context: context)
            }
            return await mapInteraction(verifyResult, scenario: .signIn, username: parameters.username, scopes: scopes, event: event, context: context)
        }

        return await mapInteraction(challengeResult, scenario: .signIn, username: parameters.username, scopes: scopes, event: event, context: context)
    }

    // MARK: - Continuation
}

extension MSALNativeAuthV2FlowController {

    func submitCode(_ code: String, continuation: MSALNativeAuthV2ContinuationState) async -> MSALNativeAuthV2FlowControllerResponse {
        currentScenario = continuation.scenario
        let context = MSALNativeAuthRequestContext(correlationId: nil)

        guard let verifyHref = continuation.link("verify")?.absoluteString else {
            let event = makeAndStartTelemetryEvent(id: .telemetryApiIdResetPasswordSubmitCode, context: context)
            return failure(.error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing verify link", correlationId: context.correlationId())), event: event, context: context)
        }

        // Sign in / sign up use `code`; reset password uses `otp`.
        switch continuation.scenario {
        case .signIn, .signUp:
            let apiId: MSALNativeAuthTelemetryApiId = continuation.scenario == .signUp ? .telemetryApiIdSignUpSubmitCode : .telemetryApiIdSignInSubmitCode
            let event = makeAndStartTelemetryEvent(id: apiId, context: context)
            let result = await performInteraction(context: context) {
                try self.requestProvider.submitCode(href: verifyHref, code: code, continuationToken: continuation.continuationToken, context: context)
            }
            return await mapInteraction(result, scenario: continuation.scenario, username: continuation.username, scopes: continuation.scopes, event: event, context: context)
        case .passwordReset:
            let event = makeAndStartTelemetryEvent(id: .telemetryApiIdResetPasswordSubmitCode, context: context)
            let result = await performInteraction(context: context) {
                try self.requestProvider.verify(href: verifyHref, otp: code, continuationToken: continuation.continuationToken, context: context)
            }
            switch result {
            case .updateRequired(let token, let updateHref):
                let newContinuation = makeContinuation(.passwordReset, continuationToken: token, links: ["update": updateHref], username: continuation.username, scopes: continuation.scopes)
                stopTelemetryEvent(event, context: context)
                return actionRequiredResponse(MSALNativeAuthNewPasswordRequiredAction(), continuation: newContinuation, context: context)
            case .error:
                return interactionFailure(result, event: event, context: context)
            default:
                return interactionFailure(result, event: event, context: context)
            }
        case .unknown:
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Unknown flow scenario", correlationId: context.correlationId())),
                event: nil,
                context: context)
        }
    }

    func submitPassword(_ password: String, continuation: MSALNativeAuthV2ContinuationState) async -> MSALNativeAuthV2FlowControllerResponse {
        currentScenario = continuation.scenario
        let context = MSALNativeAuthRequestContext(correlationId: nil)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdSignInSubmitPassword, context: context)

        guard let verifyHref = continuation.link("verify")?.absoluteString else {
            return failure(.error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing verify link", correlationId: context.correlationId())), event: event, context: context)
        }

        let result = await performInteraction(context: context) {
            try self.requestProvider.submitPassword(href: verifyHref, password: password, continuationToken: continuation.continuationToken, context: context)
        }
        return await mapInteraction(result, scenario: continuation.scenario, username: continuation.username, scopes: continuation.scopes, event: event, context: context)
    }

    func submitNewPassword(_ password: String, continuation: MSALNativeAuthV2ContinuationState) async -> MSALNativeAuthV2FlowControllerResponse {
        currentScenario = continuation.scenario
        let context = MSALNativeAuthRequestContext(correlationId: nil)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdResetPasswordSubmit, context: context)

        guard let updateHref = continuation.link("update")?.absoluteString else {
            return failure(.error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing update link", correlationId: context.correlationId())), event: event, context: context)
        }

        // Step 5 — update password.
        let updateResult = await performInteraction(context: context) {
            try self.requestProvider.updatePassword(href: updateHref, newPassword: password, continuationToken: continuation.continuationToken, context: context)
        }

        guard case .pollInProgress(var pollToken, let pollHref) = updateResult else {
            return interactionFailure(updateResult, event: event, context: context)
        }

        guard let pollHref = pollHref else {
            return failure(.error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing poll link", correlationId: context.correlationId())), event: event, context: context)
        }

        // Step 6 — poll until the operation completes.
        var completionToken: String?
        for attempt in 0..<maxPollAttempts {
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
                return interactionFailure(pollResult, event: event, context: context)
            default:
                return interactionFailure(pollResult, event: event, context: context)
            }

            if completionToken != nil {
                break
            }
        }

        guard let completionToken = completionToken else {
            return failure(.error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Password reset did not complete in time", correlationId: context.correlationId())), event: event, context: context)
        }

        return await completeWithToken(continuationToken: completionToken, username: continuation.username, scopes: continuation.scopes, event: event, context: context)
    }

    func submitAttributes(
        _ attributes: [String: Any],
        continuation: MSALNativeAuthV2ContinuationState
    ) async -> MSALNativeAuthV2FlowControllerResponse {
        currentScenario = continuation.scenario
        let context = MSALNativeAuthRequestContext(correlationId: nil)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdSignUpSubmitAttributes, context: context)

        guard let submitHref = continuation.link("submitAttributes")?.absoluteString else {
            return failure(.error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing submit-attributes link", correlationId: context.correlationId())), event: event, context: context)
        }

        let result = await performInteraction(context: context) {
            try self.requestProvider.submitAttributes(href: submitHref, attributes: attributes, continuationToken: continuation.continuationToken, context: context)
        }
        return await mapInteraction(result, scenario: continuation.scenario, username: continuation.username, scopes: continuation.scopes, event: event, context: context)
    }

    func selectAuthMethod(
        _ method: MSALAuthMethod,
        verificationContact: String?,
        continuation: MSALNativeAuthV2ContinuationState
    ) async -> MSALNativeAuthV2FlowControllerResponse {
        currentScenario = continuation.scenario
        let context = MSALNativeAuthRequestContext(correlationId: nil)

        // JIT (strong-auth registration) carries an `enroll` link; MFA carries a `challenge` link.
        if continuation.link("enroll") != nil,
           let enrollHref = (continuation.methodLink(for: method.id) ?? continuation.link("enroll"))?.absoluteString {
            let event = makeAndStartTelemetryEvent(id: .telemetryApiIdJITChallenge, context: context)
            let result = await performInteraction(context: context) {
                try self.requestProvider.registerMethod(href: enrollHref, target: verificationContact, continuationToken: continuation.continuationToken, context: context)
            }
            return await mapInteraction(result, scenario: continuation.scenario, username: continuation.username, scopes: continuation.scopes, event: event, context: context)
        }

        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdMFAGetAuthMethods, context: context)
        guard let challengeHref = (continuation.methodLink(for: method.id) ?? continuation.link("challenge"))?.absoluteString else {
            return failure(.error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing challenge link for selected method", correlationId: context.correlationId())), event: event, context: context)
        }

        let result = await performInteraction(context: context) {
            try self.requestProvider.challenge(href: challengeHref, continuationToken: continuation.continuationToken, context: context)
        }

        // An MFA method challenge surfaces as a verification-required action.
        switch result {
        case .codeRequired(let token, let verifyHref, let resendHref, let sentTo, let codeLength):
            let newContinuation = makeContinuation(
                continuation.scenario,
                continuationToken: token,
                links: ["verify": verifyHref, "resend": resendHref],
                username: continuation.username,
                sentToHint: sentTo.isEmpty ? continuation.sentToHint : sentTo,
                codeLength: codeLength,
                scopes: continuation.scopes
            )
            stopTelemetryEvent(event, context: context)
            return actionRequiredResponse(
                MSALNativeAuthMFAVerificationRequiredAction(sentTo: sentTo, channel: MSALNativeAuthChannelType(value: "email"), codeLength: codeLength),
                continuation: newContinuation,
                context: context
            )
        default:
            return await mapInteraction(result, scenario: continuation.scenario, username: continuation.username, scopes: continuation.scopes, event: event, context: context)
        }
    }

    func submitChallenge(_ challenge: String, continuation: MSALNativeAuthV2ContinuationState) async -> MSALNativeAuthV2FlowControllerResponse {
        currentScenario = continuation.scenario
        let context = MSALNativeAuthRequestContext(correlationId: nil)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdMFASubmitChallenge, context: context)

        // JIT activation uses the `activate` link; MFA uses the `verify` link.
        guard let submitHref = (continuation.link("activate") ?? continuation.link("verify"))?.absoluteString else {
            return failure(.error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing verify/activate link", correlationId: context.correlationId())), event: event, context: context)
        }

        let result = await performInteraction(context: context) {
            try self.requestProvider.submitCode(href: submitHref, code: challenge, continuationToken: continuation.continuationToken, context: context)
        }
        return await mapInteraction(result, scenario: continuation.scenario, username: continuation.username, scopes: continuation.scopes, event: event, context: context)
    }

    func resendCode(continuation: MSALNativeAuthV2ContinuationState) async -> MSALNativeAuthV2FlowControllerResponse {
        currentScenario = continuation.scenario
        let context = MSALNativeAuthRequestContext(correlationId: nil)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdResetPasswordResendCode, context: context)

        guard let resendHref = continuation.link("resend")?.absoluteString else {
            return failure(.error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing resend link", correlationId: context.correlationId())), event: event, context: context)
        }

        let result = await performInteraction(context: context) {
            try self.requestProvider.challenge(href: resendHref, continuationToken: continuation.continuationToken, context: context)
        }

        return handleCodeRequired(result, username: continuation.username, fallbackHint: continuation.sentToHint, scopes: continuation.scopes, event: event, context: context)
    }

    // MARK: - Shared step helpers

    private func performAuthorizeChallengeStart(
        context: MSALNativeAuthRequestContext
    ) async -> MSALNativeAuthV2AuthorizeChallengeValidatedResponse {
        let result: Result<MSALNativeAuthHALResponse, Error> = await send {
            try self.requestProvider.authorizeChallengeStart(context: context)
        }
        return responseValidator.validateAuthorizeChallenge(result, correlationId: context.correlationId())
    }

    private func performAuthorizeChallengeContinue(
        continuationToken: String,
        context: MSALNativeAuthRequestContext
    ) async -> MSALNativeAuthV2AuthorizeChallengeValidatedResponse {
        let result: Result<MSALNativeAuthHALResponse, Error> = await send {
            try self.requestProvider.authorizeChallengeContinue(continuationToken: continuationToken, context: context)
        }
        return responseValidator.validateAuthorizeChallenge(result, correlationId: context.correlationId())
    }

    private func performInteraction(
        context: MSALNativeAuthRequestContext,
        requestBuilder: @escaping () throws -> MSIDHttpRequest
    ) async -> MSALNativeAuthV2InteractionValidatedResponse {
        let result: Result<MSALNativeAuthHALResponse, Error> = await send(requestBuilder)
        return responseValidator.validateInteraction(result, correlationId: context.correlationId())
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
}

extension MSALNativeAuthV2FlowController {

    private func handleCodeRequired(
        _ result: MSALNativeAuthV2InteractionValidatedResponse,
        username: String?,
        fallbackHint: String?,
        scopes: [String],
        event: MSIDTelemetryAPIEvent?,
        context: MSALNativeAuthRequestContext
    ) -> MSALNativeAuthV2FlowControllerResponse {
        switch result {
        case .codeRequired(let token, let verifyHref, let resendHref, let sentTo, let codeLength):
            let newContinuation = makeContinuation(
                .passwordReset,
                continuationToken: token,
                links: ["verify": verifyHref, "resend": resendHref],
                username: username,
                sentToHint: sentTo.isEmpty ? fallbackHint : sentTo,
                codeLength: codeLength,
                scopes: scopes
            )
            let displaySentTo = sentTo.isEmpty ? (fallbackHint ?? "") : sentTo
            stopTelemetryEvent(event, context: context)
            return actionRequiredResponse(
                MSALNativeAuthCodeRequiredAction(sentTo: displaySentTo, channel: MSALNativeAuthChannelType(value: "email"), codeLength: codeLength),
                continuation: newContinuation,
                context: context
            )
        default:
            return interactionFailure(result, event: event, context: context)
        }
    }

    /// Maps a validated interaction response onto a controller response (the unified, server-driven
    /// branch used by sign in / sign up / MFA / JIT continuation steps). On a terminal `continue`
    /// state it runs the completion (authorize-challenge → token) sequence.
    private func mapInteraction(
        _ result: MSALNativeAuthV2InteractionValidatedResponse,
        scenario: MSALNativeAuthFlowScenario,
        username: String?,
        scopes: [String],
        event: MSIDTelemetryAPIEvent?,
        context: MSALNativeAuthRequestContext
    ) async -> MSALNativeAuthV2FlowControllerResponse {
        switch result {
        case .readyToComplete(let token):
            return await completeWithToken(continuationToken: token, username: username, scopes: scopes, event: event, context: context)
        case .codeRequired(let token, let verifyHref, let resendHref, let sentTo, let codeLength):
            let newContinuation = makeContinuation(
                scenario,
                continuationToken: token,
                links: ["verify": verifyHref, "resend": resendHref],
                username: username,
                sentToHint: sentTo.isEmpty ? nil : sentTo,
                codeLength: codeLength,
                scopes: scopes
            )
            stopTelemetryEvent(event, context: context)
            return actionRequiredResponse(
                MSALNativeAuthCodeRequiredAction(sentTo: sentTo, channel: MSALNativeAuthChannelType(value: "email"), codeLength: codeLength),
                continuation: newContinuation,
                context: context
            )
        case .passwordRequired(let token, let verifyHref):
            let newContinuation = makeContinuation(scenario, continuationToken: token, links: ["verify": verifyHref], username: username, scopes: scopes)
            stopTelemetryEvent(event, context: context)
            return actionRequiredResponse(MSALNativeAuthPasswordRequiredAction(), continuation: newContinuation, context: context)
        case .updateRequired(let token, let updateHref):
            let newContinuation = makeContinuation(scenario, continuationToken: token, links: ["update": updateHref], username: username, scopes: scopes)
            stopTelemetryEvent(event, context: context)
            return actionRequiredResponse(MSALNativeAuthNewPasswordRequiredAction(), continuation: newContinuation, context: context)
        case .attributesRequired(let token, let attributes, let submitHref):
            let newContinuation = makeContinuation(scenario, continuationToken: token, links: ["submitAttributes": submitHref], username: username, scopes: scopes)
            stopTelemetryEvent(event, context: context)
            return actionRequiredResponse(
                MSALNativeAuthAttributesRequiredAction(attributes: requiredAttributes(from: attributes)),
                continuation: newContinuation,
                context: context
            )
        case .mfaRequired(let token, let methods, let challengeHref):
            let (authMethods, methodLinks) = authMethods(from: methods)
            let newContinuation = makeContinuation(
                scenario,
                continuationToken: token,
                links: ["challenge": challengeHref],
                username: username,
                authMethods: authMethods,
                methodLinks: methodLinks,
                scopes: scopes
            )
            stopTelemetryEvent(event, context: context)
            return actionRequiredResponse(MSALNativeAuthMFARequiredAction(authMethods: authMethods), continuation: newContinuation, context: context)
        case .registrationRequired(let token, let enrollHref, let methods):
            let (authMethods, methodLinks) = authMethods(from: methods)
            let newContinuation = makeContinuation(
                scenario,
                continuationToken: token,
                links: ["enroll": enrollHref],
                username: username,
                authMethods: authMethods,
                methodLinks: methodLinks,
                scopes: scopes
            )
            stopTelemetryEvent(event, context: context)
            return actionRequiredResponse(
                MSALNativeAuthStrongAuthRegistrationRequiredAction(authMethods: authMethods),
                continuation: newContinuation,
                context: context
            )
        case .activationRequired(let token, let activateHref, let sentTo, let codeLength):
            let newContinuation = makeContinuation(
                scenario,
                continuationToken: token,
                links: ["activate": activateHref],
                username: username,
                sentToHint: sentTo.isEmpty ? nil : sentTo,
                codeLength: codeLength,
                scopes: scopes
            )
            stopTelemetryEvent(event, context: context)
            return actionRequiredResponse(
                MSALNativeAuthStrongAuthVerificationRequiredAction(sentTo: sentTo, channel: MSALNativeAuthChannelType(value: "email"), codeLength: codeLength),
                continuation: newContinuation,
                context: context
            )
        case .error(let error):
            stopTelemetryEvent(event, context: context, error: error)
            return response(.error(error: error), context: context)
        default:
            return interactionFailure(result, event: event, context: context)
        }
    }

    /// Completion sequence shared by every flow: authorize-challenge (continue) → token exchange.
    /// The `/token` response is persisted to the shared MSAL token cache — exactly like the V1
    /// sign-in flow — so the returned ``MSALNativeAuthUserAccountResult`` can vend access tokens
    /// via `getAccessToken(...)`.
    private func completeWithToken(
        continuationToken: String,
        username: String?,
        scopes: [String],
        event: MSIDTelemetryAPIEvent?,
        context: MSALNativeAuthRequestContext
    ) async -> MSALNativeAuthV2FlowControllerResponse {
        let codeResult = await performAuthorizeChallengeContinue(continuationToken: continuationToken, context: context)
        guard case .authorizationCode(let code) = codeResult else {
            return failure(codeResult, event: event, context: context)
        }

        let tokenResponseResult = await performTokenExchange(code: code, scopes: scopes, context: context)
        switch tokenResponseResult {
        case .success(let tokenResponse):
            do {
                let msidConfiguration = resultFactory.makeMSIDConfiguration(scopes: Self.scopes(from: tokenResponse))
                let tokenResult = try cacheTokenResponse(tokenResponse, context: context, msidConfiguration: msidConfiguration)

                guard let accountResult = resultFactory.makeUserAccountResult(tokenResult: tokenResult, context: context) else {
                    let error = MSALNativeAuthFlowError(type: .generalError, errorDescription: "Unable to construct account result", correlationId: context.correlationId())
                    stopTelemetryEvent(event, context: context, error: error)
                    return response(.error(error: error), context: context)
                }
                stopTelemetryEvent(event, context: context)
                return response(.completed(accountResult), context: context)
            } catch {
                let flowError = MSALNativeAuthFlowError(type: .generalError, errorDescription: "Unable to save tokens to the cache", correlationId: context.correlationId())
                stopTelemetryEvent(event, context: context, error: flowError)
                return response(.error(error: flowError), context: context)
            }
        case .failure(let error):
            let flowError = (error as? MSALNativeAuthFlowError) ?? MSALNativeAuthFlowError(type: .generalError, errorDescription: (error as NSError).localizedDescription, correlationId: context.correlationId())
            stopTelemetryEvent(event, context: context, error: flowError)
            return response(.error(error: flowError), context: context)
        }
    }

    /// Sends the `/token` request and parses the raw OAuth JSON into an `MSIDTokenResponse`.
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

        return await withCheckedContinuation { continuation in
            request.send { response, error in
                if let error = error {
                    continuation.resume(returning: .failure(error))
                    return
                }
                guard let responseDict = response as? [AnyHashable: Any] else {
                    continuation.resume(returning: .failure(MSALNativeAuthInternalError.invalidResponse))
                    return
                }
                do {
                    let tokenResponse = try MSALNativeAuthCIAMTokenResponse(jsonDictionary: responseDict)
                    tokenResponse.correlationId = tokenResponse.correlationId ?? request.context?.correlationId().uuidString
                    continuation.resume(returning: .success(tokenResponse))
                } catch {
                    continuation.resume(returning: .failure(MSALNativeAuthInternalError.invalidResponse))
                }
            }
        }
    }

    /// Persists the token response (tokens + account) to the shared MSAL cache and returns the
    /// resulting `MSIDTokenResult`. Mirrors the V1 `cacheTokenResponse` implementation.
    private func cacheTokenResponse(
        _ tokenResponse: MSIDTokenResponse,
        context: MSALNativeAuthRequestContext,
        msidConfiguration: MSIDConfiguration
    ) throws -> MSIDTokenResult {
        // Remove any existing account for this configuration before saving the new tokens.
        if let accounts = try? cacheAccessor.getAllAccounts(configuration: msidConfiguration),
           let account = accounts.first,
           let identifier = MSIDAccountIdentifier(displayableId: account.username, homeAccountId: account.identifier) {
            try? cacheAccessor.clearCache(
                accountIdentifier: identifier,
                authority: msidConfiguration.authority,
                clientId: msidConfiguration.clientId,
                context: context
            )
        }

        guard let tokenResult = try cacheAccessor.validateAndSaveTokensAndAccount(
            tokenResponse: tokenResponse,
            configuration: msidConfiguration,
            context: context
        ) else {
            throw MSALNativeAuthInternalError.invalidResponse
        }
        return tokenResult
    }

    /// Extracts the granted scopes from a token response so the cache target matches what was issued.
    private static func scopes(from tokenResponse: MSIDTokenResponse) -> [String] {
        guard let scope = tokenResponse.scope, !scope.isEmpty else {
            return []
        }
        return scope.components(separatedBy: " ").filter { !$0.isEmpty }
    }

    private func makeContinuation(
        _ scenario: MSALNativeAuthFlowScenario,
        continuationToken: String,
        links: [String: String?],
        username: String?,
        sentToHint: String? = nil,
        codeLength: Int? = nil,
        authMethods: [MSALAuthMethod] = [],
        methodLinks: [String: String] = [:],
        scopes: [String] = []
    ) -> MSALNativeAuthV2ContinuationState {
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
        return MSALNativeAuthV2ContinuationState(
            scenario: scenario,
            continuationToken: continuationToken,
            links: resolvedLinks,
            username: username,
            sentToHint: sentToHint,
            codeLength: codeLength,
            authMethods: authMethods,
            scopes: scopes
        )
    }

    /// Merges the caller-requested scopes with the default OIDC scopes (openid, profile,
    /// offline_access), de-duplicating while preserving order. Mirrors the V1 sign-in behaviour so
    /// the same access token / cache target results regardless of the flow version.
    private func joinScopes(_ scopes: [String]?) -> [String] {
        let defaultOIDCScopes = MSALPublicClientApplication.defaultOIDCScopes().array
        guard let scopes = scopes else {
            return defaultOIDCScopes as? [String] ?? []
        }
        let joinedScopes = NSMutableOrderedSet(array: scopes)
        joinedScopes.addObjects(from: defaultOIDCScopes)
        return joinedScopes.array as? [String] ?? []
    }

    /// Converts embedded HAL methods into public ``MSALAuthMethod`` objects plus a map of each
    /// method's `challenge` href (keyed by method id) for later selection.
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
            if let challenge = method.links["challenge"] {
                methodLinks[id] = challenge
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

    // MARK: - Response construction

    private func response(
        _ result: MSALNativeAuthV2FlowResult,
        context: MSALNativeAuthRequestContext
    ) -> MSALNativeAuthV2FlowControllerResponse {
        return MSALNativeAuthV2FlowControllerResponse(result, correlationId: context.correlationId(), scenario: currentScenario)
    }

    /// Injects the continuation context and controller into the action, then wraps it in an
    /// `.actionRequired` response so the action is self-sufficient for the next step.
    private func actionRequiredResponse(
        _ action: MSALNativeAuthAction,
        continuation: MSALNativeAuthV2ContinuationState,
        context: MSALNativeAuthRequestContext
    ) -> MSALNativeAuthV2FlowControllerResponse {
        action.inject(continuation: continuation, controller: self)
        return response(.actionRequired(action: action), context: context)
    }

    private func failure(
        _ validated: MSALNativeAuthV2AuthorizeChallengeValidatedResponse,
        event: MSIDTelemetryAPIEvent?,
        context: MSALNativeAuthRequestContext
    ) -> MSALNativeAuthV2FlowControllerResponse {
        let error: MSALNativeAuthFlowError
        if case .error(let flowError) = validated {
            error = flowError
        } else {
            error = MSALNativeAuthFlowError(type: .generalError, errorDescription: "Unexpected authorize-challenge response", correlationId: context.correlationId())
        }
        stopTelemetryEvent(event, context: context, error: error)
        return response(.error(error: error), context: context)
    }

    private func interactionFailure(
        _ validated: MSALNativeAuthV2InteractionValidatedResponse,
        event: MSIDTelemetryAPIEvent?,
        context: MSALNativeAuthRequestContext
    ) -> MSALNativeAuthV2FlowControllerResponse {
        let error: MSALNativeAuthFlowError
        if case .error(let flowError) = validated {
            error = flowError
        } else {
            error = MSALNativeAuthFlowError(type: .generalError, errorDescription: "Unexpected server response", correlationId: context.correlationId())
        }
        stopTelemetryEvent(event, context: context, error: error)
        return response(.error(error: error), context: context)
    }

    private func notImplemented(
        apiId: MSALNativeAuthTelemetryApiId,
        correlationId: UUID?,
        flow: String
    ) -> MSALNativeAuthV2FlowControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        let event = makeAndStartTelemetryEvent(id: apiId, context: context)
        let error = MSALNativeAuthFlowError(type: .notImplemented, errorDescription: "\(flow) is not implemented yet.", correlationId: context.correlationId())
        stopTelemetryEvent(event, context: context, error: error)
        return response(.error(error: error), context: context)
    }
}
