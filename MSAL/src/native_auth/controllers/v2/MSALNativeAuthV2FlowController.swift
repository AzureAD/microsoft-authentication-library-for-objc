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
final class MSALNativeAuthV2FlowController: MSALNativeAuthBaseController, MSALNativeAuthV2FlowControlling {

    private let config: MSALNativeAuthInternalConfiguration
    private let requestProvider: MSALNativeAuthV2RequestProviding
    private let responseValidator: MSALNativeAuthV2ResponseValidating
    private let cacheAccessor: MSALNativeAuthCacheInterface
    private let resultFactory: MSALNativeAuthResultBuildable

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

    func signUp(parameters: MSALNativeAuthSignUpParameters) async -> MSALNativeAuthV2FlowControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: parameters.correlationId)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdSignUp, context: context)
        let scopes = joinScopes(parameters.scopes)

        // Bootstrap authorize-challenge (expects 401 + continuation token + sign_up link).
        let bootstrap = await performAuthorizeChallengeStart(context: context)
        guard case .continuationToken(let continuationToken, let links) = bootstrap else {
            return failure(bootstrap, event: event, context: context)
        }
        guard let signUpLink = links["sign_up"] ?? links["signup"] else {
            return missingLinkFailure(relation: "sign_up", event: event, context: context)
        }

        // Sign-up start (auto-triggers the email challenge).
        let startResult = await performInteraction(context: context) {
            try self.requestProvider.signUpStart(
                username: parameters.username,
                continuationToken: continuationToken,
                href: signUpLink,
                context: context
            )
        }

        return await mapInteraction(startResult, flowType: .signUp, username: parameters.username, scopes: scopes, event: event, context: context)
    }

    // swiftlint:disable:next function_body_length
    func signIn(parameters: MSALNativeAuthSignInParameters) async -> MSALNativeAuthV2FlowControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: parameters.correlationId)
        let apiId: MSALNativeAuthTelemetryApiId = parameters.password != nil
        ? .telemetryApiIdSignInWithPasswordStart
        : .telemetryApiIdSignInWithCodeStart
        let event = makeAndStartTelemetryEvent(id: apiId, context: context)
        let scopes = joinScopes(parameters.scopes)

        // Bootstrap authorize-challenge (expects 401 + continuation token + sign_in link).
        let bootstrap = await performAuthorizeChallengeStart(context: context)
        guard case .continuationToken(let continuationToken, let links) = bootstrap else {
            return failure(bootstrap, event: event, context: context)
        }
        guard let signInLink = links["sign_in"] ?? links["signin"] else {
            return missingLinkFailure(relation: "sign_in", event: event, context: context)
        }

        // Sign-in (method discovery).
        let startResult = await performInteraction(context: context) {
            try self.requestProvider.signInStart(
                username: parameters.username,
                continuationToken: continuationToken,
                href: signInLink,
                context: context
            )
        }

        // Resolve the token and the method challenge href.
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
                return failure(
                    .error(
                        MSALNativeAuthFlowError(
                            kind: .generalError,
                            errorDescription: "No usable sign-in method returned"
                        )
                    ),
                    event: event,
                    context: context
                )
            }
            token2 = token
            challengeHref = href
        case .challengeRequired(let token, let href, _):
            token2 = token
            challengeHref = href
        default:
            return await mapInteraction(
                startResult,
                flowType: .signIn,
                username: parameters.username,
                scopes: scopes,
                event: event,
                context: context
            )
        }

        // Challenge the chosen method.
        let challengeResult = await performInteraction(context: context) {
            try self.requestProvider.challenge(href: challengeHref, continuationToken: token2, context: context)
        }

        // When a password was supplied and the password factor is required, submit it now
        // so password sign-in completes in one call.
        if let password = parameters.password, case .passwordRequired(let token, let verifyHref) = challengeResult {
            let verifyResult = await performInteraction(context: context) {
                try self.requestProvider.submitPassword(href: verifyHref, password: password, continuationToken: token, context: context)
            }
            return await mapInteraction(
                verifyResult,
                flowType: .signIn,
                username: parameters.username,
                scopes: scopes,
                event: event,
                context: context
            )
        }

        return await mapInteraction(
            challengeResult,
            flowType: .signIn,
            username: parameters.username,
            scopes: scopes,
            event: event,
            context: context
        )
    }

    func resetPassword(parameters: MSALNativeAuthResetPasswordParameters) async -> MSALNativeAuthV2FlowControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: parameters.correlationId)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdResetPasswordStart, context: context)
        let scopes = joinScopes(parameters.scopes)

        // Bootstrap authorize-challenge (expects 401 + continuation token + reset_password link).
        let bootstrap = await performAuthorizeChallengeStart(context: context)
        guard case .continuationToken(let continuationToken, let links) = bootstrap else {
            return failure(bootstrap, event: event, context: context)
        }
        guard let resetPasswordLink = links["reset_password"] ?? links["resetpassword"] else {
            return missingLinkFailure(relation: "reset_password", event: event, context: context)
        }

        // Reset-password start.
        let startResult = await performInteraction(context: context) {
            try self.requestProvider.resetPasswordStart(
                username: parameters.username,
                continuationToken: continuationToken,
                href: resetPasswordLink,
                context: context
            )
        }

        guard case .challengeRequired(let token2, let challengeHref, let hint) = startResult else {
            return interactionFailure(startResult, event: event, context: context, newState: nil)
        }

        // Auto-trigger the challenge (send EOTP).
        let challengeResult = await performInteraction(context: context) {
            try self.requestProvider.challenge(href: challengeHref, continuationToken: token2, context: context)
        }

        return handleCodeRequired(challengeResult, username: parameters.username, fallbackHint: hint, scopes: scopes, event: event, context: context)
    }

    // MARK: - Continuation

    func submitCode(_ code: String, state: MSALNativeAuthFlowState) async -> MSALNativeAuthV2FlowControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: nil)
        let continuation = state.continuation

        guard let verifyHref = continuation.link("verify")?.absoluteString else {
            let event = makeAndStartTelemetryEvent(id: .telemetryApiIdResetPasswordSubmitCode, context: context)
            return failure(
                .error(MSALNativeAuthFlowError(kind: .generalError, errorDescription: "Missing verify link")),
                event: event,
                context: context
            )
        }

        // Sign in / sign up use `code`; reset password uses `otp`.
        switch continuation.flowType {
        case .signIn, .signUp:
            let apiId: MSALNativeAuthTelemetryApiId = continuation.flowType == .signUp
            ? .telemetryApiIdSignUpSubmitCode
            : .telemetryApiIdSignInSubmitCode
            let event = makeAndStartTelemetryEvent(id: apiId, context: context)
            let result = await performInteraction(context: context) {
                try self.requestProvider.submitCode(href: verifyHref, code: code, continuationToken: continuation.continuationToken, context: context)
            }
            return await mapInteraction(
                result,
                flowType: continuation.flowType,
                username: continuation.username,
                scopes: continuation.scopes,
                event: event,
                context: context,
                recoverableState: state
            )
        case .resetPassword:
            let event = makeAndStartTelemetryEvent(id: .telemetryApiIdResetPasswordSubmitCode, context: context)
            let result = await performInteraction(context: context) {
                try self.requestProvider.verify(href: verifyHref, otp: code, continuationToken: continuation.continuationToken, context: context)
            }
            switch result {
            case .updateRequired(let token, let updateHref):
                let newState = makeState(
                    .resetPassword,
                    continuationToken: token,
                    links: ["update": updateHref],
                    username: continuation.username,
                    scopes: continuation.scopes
                )
                stopTelemetryEvent(event, context: context)
                return response(.actionRequired(action: .newPasswordRequired, newState: newState), context: context)
            case .error(let error):
                // Recoverable: allow the app to retry with the same code-required state.
                return interactionFailure(result, event: event, context: context, newState: error.isInvalidCode ? state : nil)
            default:
                return interactionFailure(result, event: event, context: context, newState: nil)
            }
        }
    }

    func submitPassword(_ password: String, state: MSALNativeAuthFlowState) async -> MSALNativeAuthV2FlowControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: nil)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdSignInSubmitPassword, context: context)
        let continuation = state.continuation

        guard let verifyHref = continuation.link("verify")?.absoluteString else {
            return failure(
                .error(MSALNativeAuthFlowError(kind: .generalError, errorDescription: "Missing verify link")),
                event: event,
                context: context
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
            flowType: continuation.flowType,
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
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdResetPasswordSubmit, context: context)
        let continuation = state.continuation

        guard let updateHref = continuation.link("update")?.absoluteString else {
            return failure(
                .error(MSALNativeAuthFlowError(kind: .generalError, errorDescription: "Missing update link")),
                event: event,
                context: context
            )
        }

        // Update password.
        let updateResult = await performInteraction(context: context) {
            try self.requestProvider.updatePassword(
                href: updateHref,
                newPassword: password,
                continuationToken: continuation.continuationToken,
                context: context
            )
        }

        guard case .pollInProgress(var pollToken, let pollHref) = updateResult else {
            return interactionFailure(updateResult, event: event, context: context, newState: nil)
        }

        // Poll until the operation completes.
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
                return interactionFailure(pollResult, event: event, context: context, newState: nil)
            default:
                return interactionFailure(pollResult, event: event, context: context, newState: nil)
            }

            if completionToken != nil {
                break
            }
        }

        guard let completionToken = completionToken else {
            return failure(
                .error(
                    MSALNativeAuthFlowError(
                        kind: .generalError,
                        errorDescription: "Password reset did not complete in time"
                    )
                ),
                event: event,
                context: context
            )
        }

        return await completeWithToken(
            continuationToken: completionToken,
            username: continuation.username,
            scopes: continuation.scopes,
            event: event,
            context: context
        )
    }

    func submitAttributes(_ attributes: [String: Any], state: MSALNativeAuthFlowState) async -> MSALNativeAuthV2FlowControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: nil)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdSignUpSubmitAttributes, context: context)
        let continuation = state.continuation

        guard let submitHref = continuation.link("submitAttributes")?.absoluteString else {
            return failure(
                .error(MSALNativeAuthFlowError(kind: .generalError, errorDescription: "Missing submit-attributes link")),
                event: event,
                context: context
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
            flowType: continuation.flowType,
            username: continuation.username,
            scopes: continuation.scopes,
            event: event,
            context: context,
            recoverableState: state
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
        if continuation.link("enroll") != nil,
           let enrollHref = (continuation.methodLink(for: method.id) ?? continuation.link("enroll"))?.absoluteString {
            let event = makeAndStartTelemetryEvent(id: .telemetryApiIdJITChallenge, context: context)
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
                flowType: continuation.flowType,
                username: continuation.username,
                scopes: continuation.scopes,
                event: event,
                context: context
            )
        }

        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdMFAGetAuthMethods, context: context)
        guard let challengeHref = (continuation.methodLink(for: method.id) ?? continuation.link("challenge"))?.absoluteString else {
            return failure(
                .error(
                    MSALNativeAuthFlowError(
                        kind: .generalError,
                        errorDescription: "Missing challenge link for selected method"
                    )
                ),
                event: event,
                context: context
            )
        }

        let result = await performInteraction(context: context) {
            try self.requestProvider.challenge(href: challengeHref, continuationToken: continuation.continuationToken, context: context)
        }

        // An MFA method challenge surfaces as a verification-required action.
        switch result {
        case .codeRequired(let token, let verifyHref, let resendHref, let sentTo, let codeLength):
            let newState = makeState(
                continuation.flowType,
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
            ), context: context)
        default:
            return await mapInteraction(
                result,
                flowType: continuation.flowType,
                username: continuation.username,
                scopes: continuation.scopes,
                event: event,
                context: context
            )
        }
    }

    func submitChallenge(_ challenge: String, state: MSALNativeAuthFlowState) async -> MSALNativeAuthV2FlowControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: nil)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdMFASubmitChallenge, context: context)
        let continuation = state.continuation

        // JIT activation uses the `activate` link; MFA uses the `verify` link.
        guard let submitHref = (continuation.link("activate") ?? continuation.link("verify"))?.absoluteString else {
            return failure(
                .error(MSALNativeAuthFlowError(kind: .generalError, errorDescription: "Missing verify/activate link")),
                event: event,
                context: context
            )
        }

        let result = await performInteraction(context: context) {
            try self.requestProvider.submitCode(
                href: submitHref,
                code: challenge,
                continuationToken: continuation.continuationToken,
                context: context
            )
        }
        return await mapInteraction(
            result,
            flowType: continuation.flowType,
            username: continuation.username,
            scopes: continuation.scopes,
            event: event,
            context: context,
            recoverableState: state
        )
    }

    func resendCode(state: MSALNativeAuthFlowState) async -> MSALNativeAuthV2FlowControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: nil)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdResetPasswordResendCode, context: context)
        let continuation = state.continuation

        guard let resendHref = continuation.link("resend")?.absoluteString else {
            return failure(
                .error(MSALNativeAuthFlowError(kind: .generalError, errorDescription: "Missing resend link")),
                event: event,
                context: context
            )
        }

        let result = await performInteraction(context: context) {
            try self.requestProvider.challenge(href: resendHref, continuationToken: continuation.continuationToken, context: context)
        }

        return handleCodeRequired(
            result,
            username: continuation.username,
            fallbackHint: continuation.sentToHint,
            scopes: continuation.scopes,
            event: event,
            context: context
        )
    }

    // MARK: - Shared step helpers

    private func performAuthorizeChallengeStart(
        context: MSALNativeAuthRequestContext
    ) async -> MSALNativeAuthV2AuthorizeChallengeValidatedResponse {
        let result: Result<MSALNativeAuthHALResponse, Error> = await send {
            try self.requestProvider.authorizeChallengeStart(context: context)
        }
        return responseValidator.validateAuthorizeChallenge(result)
    }

    private func performAuthorizeChallengeContinue(
        continuationToken: String,
        context: MSALNativeAuthRequestContext
    ) async -> MSALNativeAuthV2AuthorizeChallengeValidatedResponse {
        let result: Result<MSALNativeAuthHALResponse, Error> = await send {
            try self.requestProvider.authorizeChallengeContinue(continuationToken: continuationToken, context: context)
        }
        return responseValidator.validateAuthorizeChallenge(result)
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
        username: String?,
        fallbackHint: String?,
        scopes: [String],
        event: MSIDTelemetryAPIEvent?,
        context: MSALNativeAuthRequestContext
    ) -> MSALNativeAuthV2FlowControllerResponse {
        switch result {
        case .codeRequired(let token, let verifyHref, let resendHref, let sentTo, let codeLength):
            let newState = makeState(
                .resetPassword,
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
                context: context
            )
        default:
            return interactionFailure(result, event: event, context: context, newState: nil)
        }
    }

    // Maps a validated interaction response onto a controller response (the unified, server-driven
    // branch used by sign in / sign up / MFA / JIT continuation steps). On a terminal `continue`
    // state it runs the completion (authorize-challenge → token) sequence.
    // swiftlint:disable:next function_body_length
    private func mapInteraction(
        _ result: MSALNativeAuthV2InteractionValidatedResponse,
        flowType: MSALNativeAuthV2FlowType,
        username: String?,
        scopes: [String],
        event: MSIDTelemetryAPIEvent?,
        context: MSALNativeAuthRequestContext,
        recoverableState: MSALNativeAuthFlowState? = nil
    ) async -> MSALNativeAuthV2FlowControllerResponse {
        switch result {
        case .readyToComplete(let token):
            return await completeWithToken(continuationToken: token, username: username, scopes: scopes, event: event, context: context)
        case .codeRequired(let token, let verifyHref, let resendHref, let sentTo, let codeLength):
            let newState = makeState(
                flowType,
                continuationToken: token,
                links: ["verify": verifyHref, "resend": resendHref],
                username: username,
                sentToHint: sentTo.isEmpty ? nil : sentTo,
                codeLength: codeLength,
                scopes: scopes
            )
            stopTelemetryEvent(event, context: context)
            return response(.actionRequired(
                action: .codeRequired(sentTo: sentTo, channel: MSALNativeAuthChannelType(value: "email"), codeLength: codeLength),
                newState: newState
            ), context: context)
        case .passwordRequired(let token, let verifyHref):
            let newState = makeState(flowType, continuationToken: token, links: ["verify": verifyHref], username: username, scopes: scopes)
            stopTelemetryEvent(event, context: context)
            return response(.actionRequired(action: .passwordRequired, newState: newState), context: context)
        case .updateRequired(let token, let updateHref):
            let newState = makeState(flowType, continuationToken: token, links: ["update": updateHref], username: username, scopes: scopes)
            stopTelemetryEvent(event, context: context)
            return response(.actionRequired(action: .newPasswordRequired, newState: newState), context: context)
        case .attributesRequired(let token, let attributes, let submitHref):
            let newState = makeState(flowType, continuationToken: token, links: ["submitAttributes": submitHref], username: username, scopes: scopes)
            stopTelemetryEvent(event, context: context)
            return response(.actionRequired(
                action: .attributesRequired(attributes: requiredAttributes(from: attributes)),
                newState: newState
            ), context: context)
        case .mfaRequired(let token, let methods, let challengeHref):
            let (authMethods, methodLinks) = authMethods(from: methods)
            let newState = makeState(
                flowType,
                continuationToken: token,
                links: ["challenge": challengeHref],
                username: username,
                authMethods: authMethods,
                methodLinks: methodLinks,
                scopes: scopes
            )
            stopTelemetryEvent(event, context: context)
            return response(.actionRequired(action: .mfaRequired(authMethods: authMethods), newState: newState), context: context)
        case .registrationRequired(let token, let enrollHref, let methods):
            let (authMethods, methodLinks) = authMethods(from: methods)
            let newState = makeState(
                flowType,
                continuationToken: token,
                links: ["enroll": enrollHref],
                username: username,
                authMethods: authMethods,
                methodLinks: methodLinks,
                scopes: scopes
            )
            stopTelemetryEvent(event, context: context)
            return response(.actionRequired(action: .strongAuthRegistrationRequired(authMethods: authMethods), newState: newState), context: context)
        case .activationRequired(let token, let activateHref, let sentTo, let codeLength):
            let newState = makeState(
                flowType,
                continuationToken: token,
                links: ["activate": activateHref],
                username: username,
                sentToHint: sentTo.isEmpty ? nil : sentTo,
                codeLength: codeLength,
                scopes: scopes
            )
            stopTelemetryEvent(event, context: context)
            return response(.actionRequired(
                action: .strongAuthVerificationRequired(sentTo: sentTo, channel: MSALNativeAuthChannelType(value: "email"), codeLength: codeLength),
                newState: newState
            ), context: context)
        case .error(let error):
            stopTelemetryEvent(event, context: context, error: error)
            return response(
                .error(error: error, newState: error.isInvalidCode || error.kind == .invalidPassword ? recoverableState : nil),
                context: context
            )
        default:
            return interactionFailure(result, event: event, context: context, newState: nil)
        }
    }

    /// Completion sequence shared by every flow: authorize-challenge (continue) → token exchange.
    /// The `/token` response is persisted to the shared MSAL token cache so the returned
    /// ``MSALNativeAuthUserAccountResult`` can retrieve access tokens via `getAccessToken(...)`.
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
                    let error = MSALNativeAuthFlowError(kind: .generalError, errorDescription: "Unable to construct account result")
                    stopTelemetryEvent(event, context: context, error: error)
                    return response(.error(error: error, newState: nil), context: context)
                }
                stopTelemetryEvent(event, context: context)
                return response(.completed(accountResult), context: context)
            } catch {
                let flowError = MSALNativeAuthFlowError(kind: .generalError, errorDescription: "Unable to save tokens to the cache")
                stopTelemetryEvent(event, context: context, error: flowError)
                return response(.error(error: flowError, newState: nil), context: context)
            }
        case .failure(let error):
            let flowError = (error as? MSALNativeAuthFlowError)
            ?? MSALNativeAuthFlowError(kind: .generalError, errorDescription: (error as NSError).localizedDescription)
            stopTelemetryEvent(event, context: context, error: flowError)
            return response(.error(error: flowError, newState: nil), context: context)
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

        let fallbackCorrelationId = request.context?.correlationId().uuidString

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
                    tokenResponse.correlationId = tokenResponse.correlationId ?? fallbackCorrelationId
                    continuation.resume(returning: .success(tokenResponse))
                } catch {
                    continuation.resume(returning: .failure(MSALNativeAuthInternalError.invalidResponse))
                }
            }
        }
    }

    /// Persists the token response (tokens + account) to the shared MSAL cache and returns the
    /// resulting `MSIDTokenResult`.
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

    private func makeState(
        _ flowType: MSALNativeAuthV2FlowType,
        continuationToken: String,
        links: [String: String?],
        username: String?,
        sentToHint: String? = nil,
        codeLength: Int? = nil,
        authMethods: [MSALAuthMethod] = [],
        methodLinks: [String: String] = [:],
        scopes: [String] = []
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
            flowType: flowType,
            continuationToken: continuationToken,
            links: resolvedLinks,
            username: username,
            sentToHint: sentToHint,
            codeLength: codeLength,
            authMethods: authMethods,
            scopes: scopes
        )
        return MSALNativeAuthFlowState(continuation: continuation, controller: self)
    }

    /// Merges the caller-requested scopes with the default OIDC scopes (openid, profile,
    /// offline_access), de-duplicating while preserving order.
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
        return MSALNativeAuthV2FlowControllerResponse(result, correlationId: context.correlationId())
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
            error = MSALNativeAuthFlowError(kind: .generalError, errorDescription: "Unexpected authorize-challenge response")
        }
        stopTelemetryEvent(event, context: context, error: error)
        return response(.error(error: error, newState: nil), context: context)
    }

    private func missingLinkFailure(
        relation: String,
        event: MSIDTelemetryAPIEvent?,
        context: MSALNativeAuthRequestContext
    ) -> MSALNativeAuthV2FlowControllerResponse {
        let error = MSALNativeAuthFlowError(
            kind: .generalError,
            errorDescription: "Invalid authorize-challenge response: missing '\(relation)' link"
        )
        stopTelemetryEvent(event, context: context, error: error)
        return response(.error(error: error, newState: nil), context: context)
    }

    private func interactionFailure(
        _ validated: MSALNativeAuthV2InteractionValidatedResponse,
        event: MSIDTelemetryAPIEvent?,
        context: MSALNativeAuthRequestContext,
        newState: MSALNativeAuthFlowState?
    ) -> MSALNativeAuthV2FlowControllerResponse {
        let error: MSALNativeAuthFlowError
        if case .error(let flowError) = validated {
            error = flowError
        } else {
            error = MSALNativeAuthFlowError(kind: .generalError, errorDescription: "Unexpected server response")
        }
        stopTelemetryEvent(event, context: context, error: error)
        return response(.error(error: error, newState: newState), context: context)
    }

    private func notImplemented(
        apiId: MSALNativeAuthTelemetryApiId,
        correlationId: UUID?,
        flow: String
    ) -> MSALNativeAuthV2FlowControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        let event = makeAndStartTelemetryEvent(id: apiId, context: context)
        let error = MSALNativeAuthFlowError(kind: .notImplemented, errorDescription: "\(flow) is not implemented yet.")
        stopTelemetryEvent(event, context: context, error: error)
        return response(.error(error: error, newState: nil), context: context)
    }
}
