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

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
final class MSALNativeAuthFlowController: MSALNativeAuthBaseController, MSALNativeAuthFlowControlling, MSALNativeAuthTokenRequestHandling {

    private let config: MSALNativeAuthInternalConfiguration
    private let requestProvider: MSALNativeAuthV2RequestProviding
    private let responseValidator: MSALNativeAuthV2ResponseValidating
    private let resultFactory: MSALNativeAuthResultBuildable
    private let tokenCacher: MSALNativeAuthTokenCacher

    private let kNumberOfTimesToRetryPollCompletionCall = 5
    // TODO: Confirm this is needed and server doesn't send
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

    func signUp(parameters: MSALNativeAuthSignUpParametersV2) async -> MSALNativeAuthFlowControllerResponse {
        return notImplementedResponse(scenario: .signUp)
    }

    func signIn(parameters: MSALNativeAuthSignInParameters) async -> MSALNativeAuthFlowControllerResponse {
        return notImplementedResponse(scenario: .signIn)
    }

    func resetPassword(parameters: MSALNativeAuthResetPasswordParametersV2) async -> MSALNativeAuthFlowControllerResponse {
        let flowScenario: MSALNativeAuthFlowScenario = .passwordReset
        let context = MSALNativeAuthRequestContext(correlationId: parameters.correlationId)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2ResetPasswordStart, context: context)
        let scopes = joinScopes(parameters.scopes)

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

        guard case .challengeRequired(let challengeContinuationToken, let challengeHref, let hint) = startResult else {
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

        return await mapInteraction(
            challengeResult,
            flowScenario: flowScenario,
            username: parameters.username,
            scopes: scopes,
            apiId: .telemetryApiIdV2ResetPasswordStart,
            event: event,
            context: context,
            fallbackHint: hint
        )
    }

    // MARK: - Continuation

    func submitCode(_ code: String, state: MSALNativeAuthFlowInternalState) async -> MSALNativeAuthFlowControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: nil)
        let continuation = state.continuation
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2ResetPasswordSubmitCode, context: context)

        guard let verifyHref = continuation.link(.verify)?.absoluteString else {
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing verify link")),
                event: event,
                context: context, scenario: continuation.flowScenario
            )
        }

        let result = await performInteraction(context: context) {
            try self.requestProvider.verify(
                href: verifyHref,
                otp: code,
                continuationToken: continuation.continuationToken,
                apiId: .telemetryApiIdV2ResetPasswordSubmitCode,
                context: context
            )
        }
        return await mapInteraction(
            result,
            flowScenario: continuation.flowScenario,
            username: continuation.username,
            scopes: continuation.scopes,
            apiId: .telemetryApiIdV2ResetPasswordSubmitCode,
            event: event,
            context: context,
            recoverableState: state
        )
    }

    func submitPassword(_ password: String, state: MSALNativeAuthFlowInternalState) async -> MSALNativeAuthFlowControllerResponse {
        return notImplementedResponse(scenario: state.continuation.flowScenario)
    }

    // swiftlint:disable:next function_body_length
    func submitNewPassword(_ password: String, state: MSALNativeAuthFlowInternalState) async -> MSALNativeAuthFlowControllerResponse {
        let context = MSALNativeAuthRequestContext(correlationId: nil)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2ResetPasswordSubmit, context: context)
        let continuation = state.continuation

        guard let updateHref = continuation.link(.update)?.absoluteString else {
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
                apiId: .telemetryApiIdV2ResetPasswordSubmit,
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
                try self.requestProvider.poll(
                    href: pollHref,
                    continuationToken: pollToken,
                    apiId: .telemetryApiIdV2ResetPasswordSubmit,
                    context: context
                )
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
            apiId: .telemetryApiIdV2ResetPasswordSubmit,
            event: event,
            context: context
        )
    }

    func submitAttributes(_ attributes: [String: Any], state: MSALNativeAuthFlowInternalState) async -> MSALNativeAuthFlowControllerResponse {
        return notImplementedResponse(scenario: state.continuation.flowScenario)
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
        let context = MSALNativeAuthRequestContext(correlationId: nil)
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdV2ResetPasswordResendCode, context: context)
        let continuation = state.continuation

        guard let resendHref = continuation.link(.resend)?.absoluteString else {
            return failure(
                .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing resend link")),
                event: event,
                context: context, scenario: continuation.flowScenario
            )
        }

        let result = await performInteraction(context: context) {
            try self.requestProvider.challenge(
                href: resendHref,
                continuationToken: continuation.continuationToken,
                apiId: .telemetryApiIdV2ResetPasswordResendCode,
                context: context
            )
        }

        return await mapInteraction(
            result,
            flowScenario: continuation.flowScenario,
            username: continuation.username,
            scopes: continuation.scopes,
            apiId: .telemetryApiIdV2ResetPasswordResendCode,
            event: event,
            context: context,
            fallbackHint: continuation.sentToHint
        )
    }

    // MARK: - Shared step helpers

    private func performAuthorizeChallengeStart(
        flowScenario: MSALNativeAuthFlowScenario,
        apiId: MSALNativeAuthTelemetryApiId,
        context: MSALNativeAuthRequestContext
    ) async -> MSALNativeAuthV2AuthorizeChallengeValidatedResponse {
        let result: Result<MSALNativeAuthHALResponse, Error> = await send {
            try self.requestProvider.authorizeChallengeStart(apiId: apiId, context: context)
        }
        return responseValidator.validateAuthorizeChallenge(context: context, result, flowScenario: flowScenario)
    }

    private func performAuthorizeChallengeContinue(
        flowScenario: MSALNativeAuthFlowScenario,
        continuationToken: String,
        apiId: MSALNativeAuthTelemetryApiId,
        context: MSALNativeAuthRequestContext
    ) async -> MSALNativeAuthV2AuthorizeChallengeValidatedResponse {
        let result: Result<MSALNativeAuthHALResponse, Error> = await send {
            try self.requestProvider.authorizeChallengeContinue(continuationToken: continuationToken, apiId: apiId, context: context)
        }
        return responseValidator.validateAuthorizeChallenge(context: context, result, flowScenario: flowScenario)
    }

    private func performInteraction(
        context: MSALNativeAuthRequestContext,
        requestBuilder: @escaping () throws -> MSIDHttpRequest
    ) async -> MSALNativeAuthV2InteractionValidatedResponse {
        let result: Result<MSALNativeAuthHALResponse, Error> = await send(requestBuilder)
        return responseValidator.validateInteraction(context: context, result)
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

    // Maps a validated interaction response onto a controller response, building the next
    // required state or, on a terminal response, running the authorize-challenge → token completion.
    private func mapInteraction(
        _ result: MSALNativeAuthV2InteractionValidatedResponse,
        flowScenario: MSALNativeAuthFlowScenario,
        username: String?,
        scopes: [String],
        apiId: MSALNativeAuthTelemetryApiId,
        event: MSIDTelemetryAPIEvent?,
        context: MSALNativeAuthRequestContext,
        recoverableState: MSALNativeAuthFlowInternalState? = nil,
        fallbackHint: String? = nil
    ) async -> MSALNativeAuthFlowControllerResponse {
        switch result {
        case .readyToComplete(let token):
            return await completeWithToken(
                flowScenario: flowScenario,
                continuationToken: token,
                username: username,
                scopes: scopes,
                apiId: apiId,
                event: event,
                context: context
            )
        case .codeRequired(let token, let verifyHref, let resendHref, let sentTo, let channelType, let codeLength):
            let newState = makeState(
                flowScenario,
                continuationToken: token,
                links: [.verify: verifyHref, .resend: resendHref],
                username: username,
                sentToHint: sentTo.isEmpty ? fallbackHint : sentTo,
                codeLength: codeLength,
                scopes: scopes
            )
            let displaySentTo = sentTo.isEmpty ? (fallbackHint ?? "") : sentTo
            let state = MSALNativeAuthCodeRequiredState(internalState: newState, sentTo: displaySentTo, channel: channelType, codeLength: codeLength)
            stopTelemetryEvent(event, context: context)
            return response(.actionRequired(state: state), context: context)
        case .updateRequired(let token, let updateHref):
            let newState = makeState(
                flowScenario,
                continuationToken: token,
                links: [.update: updateHref],
                username: username,
                scopes: scopes
            )
            stopTelemetryEvent(event, context: context)
            return response(
                .actionRequired(state: MSALNativeAuthNewPasswordRequiredState(internalState: newState)),
                context: context)
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
        apiId: MSALNativeAuthTelemetryApiId,
        event: MSIDTelemetryAPIEvent?,
        context: MSALNativeAuthRequestContext
    ) async -> MSALNativeAuthFlowControllerResponse {
        let codeResult = await performAuthorizeChallengeContinue(
            flowScenario: flowScenario,
            continuationToken: continuationToken,
            apiId: apiId,
            context: context
        )
        guard case .authorizationCode(let code) = codeResult else {
            return failure(codeResult, event: event, context: context, scenario: flowScenario)
        }

        let tokenResponseResult = await performTokenExchange(code: code, scopes: scopes, apiId: apiId, context: context)
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
        apiId: MSALNativeAuthTelemetryApiId,
        context: MSALNativeAuthRequestContext
    ) async -> Result<MSIDTokenResponse, Error> {
        let request: MSIDHttpRequest
        do {
            request = try requestProvider.token(code: code, scopes: scopes, apiId: apiId, context: context)
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
        links: [MSALNativeAuthV2LinkRelation: String?],
        username: String?,
        sentToHint: String? = nil,
        codeLength: Int? = nil,
        scopes: [String] = []
    ) -> MSALNativeAuthFlowInternalState {
        let resolver = MSALNativeAuthV2HrefURLResolver(config: config)
        var resolvedLinks: [MSALNativeAuthV2LinkKey: URL] = [:]
        for (relation, href) in links {
            if let href = href, let url = try? resolver.url(forHref: href) {
                resolvedLinks[.relation(relation)] = url
            }
        }
        let continuation = MSALNativeAuthFlowContinuationState(
            flowScenario: flowScenario,
            continuationToken: continuationToken,
            links: resolvedLinks,
            username: username,
            sentToHint: sentToHint,
            codeLength: codeLength,
            scopes: scopes
        )
        return MSALNativeAuthFlowInternalState(continuation: continuation, controller: self)
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
        _ validated: MSALNativeAuthV2AuthorizeChallengeValidatedResponse,
        event: MSIDTelemetryAPIEvent?,
        context: MSALNativeAuthRequestContext,
        scenario: MSALNativeAuthFlowScenario
    ) -> MSALNativeAuthFlowControllerResponse {
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
        newState: MSALNativeAuthFlowInternalState?
    ) -> MSALNativeAuthFlowControllerResponse {
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
