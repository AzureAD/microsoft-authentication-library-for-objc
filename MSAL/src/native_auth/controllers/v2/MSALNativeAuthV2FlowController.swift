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

    private let maxPollAttempts = 5
    private let pollIntervalNanoseconds: UInt64 = 1_500_000_000 // 1.5s

    init(
        config: MSALNativeAuthInternalConfiguration,
        requestProvider: MSALNativeAuthV2RequestProviding,
        responseValidator: MSALNativeAuthV2ResponseValidating,
        cacheAccessor: MSALNativeAuthCacheInterface
    ) {
        self.config = config
        self.requestProvider = requestProvider
        self.responseValidator = responseValidator
        self.cacheAccessor = cacheAccessor
        super.init(clientId: config.clientId)
    }

    convenience init(config: MSALNativeAuthInternalConfiguration, cacheAccessor: MSALNativeAuthCacheInterface) {
        self.init(
            config: config,
            requestProvider: MSALNativeAuthV2RequestProvider(config: config),
            responseValidator: MSALNativeAuthV2ResponseValidator(),
            cacheAccessor: cacheAccessor
        )
    }

    // MARK: - Entry points

    func resetPassword(parameters: MSALNativeAuthResetPasswordParameters) async -> MSALNativeAuthV2FlowControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: parameters.correlationId)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdResetPasswordStart, context: context)

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
            return interactionFailure(startResult, event: event, context: context, newState: nil)
        }

        // Step 3 — auto-trigger the challenge (send EOTP).
        guard let challengeHref = challengeHref else {
            return failure(.error(MSALNativeAuthFlowError(kind: .generalError, errorDescription: "Missing challenge link")), event: event, context: context)
        }

        let challengeResult = await performInteraction(context: context) {
            try self.requestProvider.challenge(href: challengeHref, continuationToken: token2, context: context)
        }

        return handleCodeRequired(challengeResult, username: parameters.username, fallbackHint: hint, event: event, context: context)
    }

    func signUp(parameters: MSALNativeAuthSignUpParameters) async -> MSALNativeAuthV2FlowControllerResponse {
        return notImplemented(apiId: .telemetryApiIdSignUp, correlationId: parameters.correlationId, flow: "Sign up V2")
    }

    func signIn(parameters: MSALNativeAuthSignInParameters) async -> MSALNativeAuthV2FlowControllerResponse {
        return notImplemented(apiId: .telemetryApiIdSignInWithCodeStart, correlationId: parameters.correlationId, flow: "Sign in V2")
    }

    // MARK: - Continuation

    func submitCode(_ code: String, state: MSALNativeAuthFlowState) async -> MSALNativeAuthV2FlowControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: nil)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdResetPasswordSubmitCode, context: context)
        let continuation = state.continuation

        guard let verifyHref = continuation.link("verify")?.absoluteString else {
            return failure(.error(MSALNativeAuthFlowError(kind: .generalError, errorDescription: "Missing verify link")), event: event, context: context)
        }

        let result = await performInteraction(context: context) {
            try self.requestProvider.verify(href: verifyHref, otp: code, continuationToken: continuation.continuationToken, context: context)
        }

        switch result {
        case .updateRequired(let token, let updateHref):
            let newState = makeState(.resetPassword, continuationToken: token, links: ["update": updateHref], username: continuation.username)
            stopTelemetryEvent(event, context: context)
            return response(.actionRequired(action: .newPasswordRequired, newState: newState), context: context)
        case .error(let error):
            // Recoverable: allow the app to retry with the same code-required state.
            return interactionFailure(result, event: event, context: context, newState: error.isInvalidCode ? state : nil)
        default:
            return interactionFailure(result, event: event, context: context, newState: nil)
        }
    }

    func submitPassword(_ password: String, state: MSALNativeAuthFlowState) async -> MSALNativeAuthV2FlowControllerResponse {
        return notImplemented(apiId: .telemetryApiIdSignInSubmitPassword, correlationId: nil, flow: "Submit password V2")
    }

    func submitNewPassword(_ password: String, state: MSALNativeAuthFlowState) async -> MSALNativeAuthV2FlowControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: nil)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdResetPasswordSubmit, context: context)
        let continuation = state.continuation

        guard let updateHref = continuation.link("update")?.absoluteString else {
            return failure(.error(MSALNativeAuthFlowError(kind: .generalError, errorDescription: "Missing update link")), event: event, context: context)
        }

        // Step 5 — update password.
        let updateResult = await performInteraction(context: context) {
            try self.requestProvider.updatePassword(href: updateHref, newPassword: password, continuationToken: continuation.continuationToken, context: context)
        }

        guard case .pollInProgress(var pollToken, let pollHref) = updateResult else {
            return interactionFailure(updateResult, event: event, context: context, newState: nil)
        }

        guard let pollHref = pollHref else {
            return failure(.error(MSALNativeAuthFlowError(kind: .generalError, errorDescription: "Missing poll link")), event: event, context: context)
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
                return interactionFailure(pollResult, event: event, context: context, newState: nil)
            default:
                return interactionFailure(pollResult, event: event, context: context, newState: nil)
            }

            if completionToken != nil {
                break
            }
        }

        guard let completionToken = completionToken else {
            return failure(.error(MSALNativeAuthFlowError(kind: .generalError, errorDescription: "Password reset did not complete in time")), event: event, context: context)
        }

        // Step 7 — completion authorize-challenge → authorization code.
        let codeResult = await performAuthorizeChallengeContinue(continuationToken: completionToken, context: context)
        guard case .authorizationCode(let code) = codeResult else {
            return failure(codeResult, event: event, context: context)
        }

        // Step 8 — token exchange.
        let tokenRequestResult: Result<MSALNativeAuthHALResponse, Error> = await send {
            try self.requestProvider.token(code: code, context: context)
        }
        let tokenResult = responseValidator.validateToken(tokenRequestResult)

        switch tokenResult {
        case .success:
            guard let accountResult = makeUserAccountResult(username: continuation.username, context: context) else {
                let error = MSALNativeAuthFlowError(kind: .generalError, errorDescription: "Unable to construct account result")
                stopTelemetryEvent(event, context: context, error: error)
                return response(.error(error: error, newState: nil), context: context)
            }
            stopTelemetryEvent(event, context: context)
            return response(.completed(accountResult), context: context)
        case .error(let error):
            stopTelemetryEvent(event, context: context, error: error)
            return response(.error(error: error, newState: nil), context: context)
        }
    }

    func submitAttributes(_ attributes: [String: Any], state: MSALNativeAuthFlowState) async -> MSALNativeAuthV2FlowControllerResponse {
        return notImplemented(apiId: .telemetryApiIdSignUpSubmitAttributes, correlationId: nil, flow: "Submit attributes V2")
    }

    func selectAuthMethod(
        _ method: MSALAuthMethod,
        verificationContact: String?,
        state: MSALNativeAuthFlowState
    ) async -> MSALNativeAuthV2FlowControllerResponse {
        return notImplemented(apiId: .telemetryApiIdMFAGetAuthMethods, correlationId: nil, flow: "Select auth method V2")
    }

    func submitChallenge(_ challenge: String, state: MSALNativeAuthFlowState) async -> MSALNativeAuthV2FlowControllerResponse {
        return notImplemented(apiId: .telemetryApiIdMFASubmitChallenge, correlationId: nil, flow: "Submit challenge V2")
    }

    func resendCode(state: MSALNativeAuthFlowState) async -> MSALNativeAuthV2FlowControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: nil)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdResetPasswordResendCode, context: context)
        let continuation = state.continuation

        guard let resendHref = continuation.link("resend")?.absoluteString else {
            return failure(.error(MSALNativeAuthFlowError(kind: .generalError, errorDescription: "Missing resend link")), event: event, context: context)
        }

        let result = await performInteraction(context: context) {
            try self.requestProvider.challenge(href: resendHref, continuationToken: continuation.continuationToken, context: context)
        }

        return handleCodeRequired(result, username: continuation.username, fallbackHint: continuation.sentToHint, event: event, context: context)
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
                codeLength: codeLength
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

    private func makeState(
        _ flowType: MSALNativeAuthV2FlowType,
        continuationToken: String,
        links: [String: String?],
        username: String?,
        sentToHint: String? = nil,
        codeLength: Int? = nil
    ) -> MSALNativeAuthFlowState {
        let resolver = MSALNativeAuthV2HrefURLResolver(config: config)
        var resolvedLinks: [String: URL] = [:]
        for (relation, href) in links {
            if let href = href, let url = try? resolver.url(forHref: href) {
                resolvedLinks[relation] = url
            }
        }
        let continuation = MSALNativeAuthV2ContinuationState(
            flowType: flowType,
            continuationToken: continuationToken,
            links: resolvedLinks,
            username: username,
            sentToHint: sentToHint,
            codeLength: codeLength
        )
        return MSALNativeAuthFlowState(continuation: continuation, controller: self)
    }

    private func makeUserAccountResult(username: String?, context: MSALNativeAuthRequestContext) -> MSALNativeAuthUserAccountResult? {
        let environment = config.authority.url.host ?? "login.microsoftonline.com"
        let homeAccountId = MSALAccountId(accountIdentifier: "", objectId: "", tenantId: "")
        guard let account = MSALAccount(
            username: username ?? "",
            homeAccountId: homeAccountId,
            environment: environment,
            tenantProfiles: []
        ) else {
            return nil
        }
        return MSALNativeAuthUserAccountResult(
            account: account,
            rawIdToken: nil,
            configuration: config,
            cacheAccessor: cacheAccessor
        )
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
