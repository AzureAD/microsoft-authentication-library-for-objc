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
        return notImplementedResponse(scenario: .signUp)
    }

    func signIn(parameters: MSALNativeAuthSignInParameters) async -> MSALNativeAuthFlowControllerResponse {
        return notImplementedResponse(scenario: .signIn)
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

        guard case .challengeRequired(let challengeContinuationToken, let challengeHref, _) = startResult else {
            return interactionFailure(startResult, event: event, context: context, scenario: flowScenario, newState: nil)
        }

        let challengeResult = await performInteraction(context: context) {
            try self.requestProvider.challenge(
                href: challengeHref,
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
        return await handleChallengeResult(challengeResult, flowContinuationState: continuation, step: step)
    }

    // MARK: - Continuation

    func submitCode(_ code: String, state: MSALNativeAuthFlowInternalState) async -> MSALNativeAuthFlowControllerResponse {
        let flowContinuationState = state.continuation
        let context = MSALNativeAuthRequestContext(correlationId: flowContinuationState.correlationId)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2ResetPasswordSubmitCode, context: context)

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
                apiId: .telemetryApiIdV2ResetPasswordSubmitCode,
                context: context
            )
        }
        let step = MSALNativeAuthFlowStepContext(apiId: .telemetryApiIdV2ResetPasswordSubmitCode, event: event, context: context)
        return await handleSubmitCodeResult(result, flowContinuationState: flowContinuationState, step: step, recoverableState: state)
    }

    func submitPassword(_ password: String, state: MSALNativeAuthFlowInternalState) async -> MSALNativeAuthFlowControllerResponse {
        return notImplementedResponse(scenario: state.continuation.flowScenario)
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

        guard case .pollInProgress(var pollToken, let pollHref) = updateResult else {
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

            if case .pollInProgress(let token, _) = pollResult {
                pollToken = token
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
        return notImplementedResponse(scenario: state.continuation.flowScenario)
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

    func selectAuthMethod(
        _ method: MSALAuthMethod,
        verificationContact: String?,
        state: MSALNativeAuthFlowInternalState
    ) async -> MSALNativeAuthFlowControllerResponse {
        return notImplementedResponse(scenario: state.continuation.flowScenario)
    }

    func submitChallenge(_ challenge: String, state: MSALNativeAuthFlowInternalState) async -> MSALNativeAuthFlowControllerResponse {
        return notImplementedResponse(scenario: state.continuation.flowScenario)
    }

    func resendCode(state: MSALNativeAuthFlowInternalState) async -> MSALNativeAuthFlowControllerResponse {
        let flowContinuationState = state.continuation
        let context = MSALNativeAuthRequestContext(correlationId: flowContinuationState.correlationId)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2ResetPasswordResendCode, context: context)

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
                apiId: .telemetryApiIdV2ResetPasswordResendCode,
                context: context
            )
        }

        let step = MSALNativeAuthFlowStepContext(apiId: .telemetryApiIdV2ResetPasswordResendCode, event: event, context: context)
        return handleResendCodeResult(result, flowContinuationState: flowContinuationState, step: step)
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

    // MARK: - Result mapping

    /// Maps the challenge response from the reset-password start sequence.
    func handleChallengeResult(
        _ result: MSALNativeAuthV2InteractionParsedResponse,
        flowContinuationState: MSALNativeAuthFlowContinuationState,
        step: MSALNativeAuthFlowStepContext
    ) async -> MSALNativeAuthFlowControllerResponse {
        switch result {
        case .codeRequired(let token, let verifyHref, let resendHref, let sentTo, let channelType, let codeLength):
            let next = makeContinuation(from: flowContinuationState, continuationToken: token, links: [.verify: verifyHref, .resend: resendHref])
            return codeRequiredResponse(flowContinuationState: next, sentTo: sentTo, channelType: channelType, codeLength: codeLength, step: step)
        case .readyToComplete(let token):
            return signInAfterResetPasswordResponse(flowContinuationState: flowContinuationState, continuationToken: token, step: step)
        case .browserRequired:
            stopTelemetryEvent(step.event, context: step.context)
            return response(.browserRequired, context: step.context, scenario: flowContinuationState.flowScenario)
        case .error(let error):
            stopTelemetryEvent(step.event, context: step.context, error: error)
            return response(.error(error: error, newState: nil), context: step.context, scenario: flowContinuationState.flowScenario)
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
        case .codeRequired(let token, let verifyHref, let resendHref, let sentTo, let channelType, let codeLength):
            let next = makeContinuation(from: flowContinuationState, continuationToken: token, links: [.verify: verifyHref, .resend: resendHref])
            return codeRequiredResponse(flowContinuationState: next, sentTo: sentTo, channelType: channelType, codeLength: codeLength, step: step)
        case .browserRequired:
            stopTelemetryEvent(step.event, context: step.context)
            return response(.browserRequired, context: step.context, scenario: flowContinuationState.flowScenario)
        case .error(let error):
            stopTelemetryEvent(step.event, context: step.context, error: error)
            return response(.error(error: error, newState: nil), context: step.context, scenario: flowContinuationState.flowScenario)
        default:
            return interactionFailure(result, event: step.event, context: step.context, scenario: flowContinuationState.flowScenario, newState: nil)
        }
    }

    /// Maps the verify response from submitting a one-time code.
    func handleSubmitCodeResult(
        _ result: MSALNativeAuthV2InteractionParsedResponse,
        flowContinuationState: MSALNativeAuthFlowContinuationState,
        step: MSALNativeAuthFlowStepContext,
        recoverableState: MSALNativeAuthFlowInternalState?
    ) async -> MSALNativeAuthFlowControllerResponse {
        switch result {
        case .updateRequired(let token, let updateHref):
            let next = makeContinuation(from: flowContinuationState, continuationToken: token, links: [.update: updateHref])
            return newPasswordRequiredResponse(flowContinuationState: next, step: step)
        case .readyToComplete(let token):
            return signInAfterResetPasswordResponse(flowContinuationState: flowContinuationState, continuationToken: token, step: step)
        case .browserRequired:
            stopTelemetryEvent(step.event, context: step.context)
            return response(.browserRequired, context: step.context, scenario: flowContinuationState.flowScenario)
        case .error(let error):
            stopTelemetryEvent(step.event, context: step.context, error: error)
            return response(
                .error(error: error, newState: error.isInvalidCode || error.type == .invalidPassword ? recoverableState : nil),
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
                    return response(.error(error: error, newState: nil), context: step.context, scenario: flowContinuationState.flowScenario)
                }
                stopTelemetryEvent(step.event, context: step.context)
                return response(.completed(accountResult), context: step.context, scenario: flowContinuationState.flowScenario)
            } catch {
                let flowError = MSALNativeAuthFlowError(type: .generalError, errorDescription: "Unable to save tokens to the cache")
                stopTelemetryEvent(step.event, context: step.context, error: flowError)
                return response(.error(error: flowError, newState: nil), context: step.context, scenario: flowContinuationState.flowScenario)
            }
        case .failure(let error):
            let flowError = (error as? MSALNativeAuthFlowError)
            ?? MSALNativeAuthFlowError(type: .generalError, errorDescription: (error as NSError).localizedDescription)
            stopTelemetryEvent(step.event, context: step.context, error: flowError)
            return response(.error(error: flowError, newState: nil), context: step.context, scenario: flowContinuationState.flowScenario)
        }
    }

    /// Builds the `/token` request and delegates the send/parse to the shared token-request handler.
    private func performTokenExchange(
        code: String,
        scopes: [String],
        claimsRequestJson: String?,
        apiId: MSALNativeAuthTelemetryApiId,
        context: MSALNativeAuthRequestContext
    ) async -> Result<MSIDTokenResponse, Error> {
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
            return .failure(error)
        }

        return await performTokenRequest(request, context: context).map { $0 as MSIDTokenResponse }
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

    /// Response for flows that are not implemented currently
    private func notImplementedResponse(scenario: MSALNativeAuthFlowScenario) -> MSALNativeAuthFlowControllerResponse {
        return MSALNativeAuthFlowControllerResponse(
            .error(error: MSALNativeAuthFlowError(type: .notImplemented), newState: nil),
            correlationId: UUID(),
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
        return response(.error(error: error, newState: nil), context: context, scenario: scenario)
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
        return response(.error(error: error, newState: newState), context: context, scenario: scenario)
    }
}
