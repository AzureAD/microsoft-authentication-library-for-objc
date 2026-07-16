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

/// Identifies which V2 flow a ``MSALNativeAuthFlowState`` belongs to.
extension MSALNativeAuthFlowScenario {

    /// The server-driven flows the SDK follows when resolving `authorize-challenge` links.
    static let authorizeChallengeFlows: [MSALNativeAuthFlowScenario] = [.signUp, .signIn, .passwordReset, .unknown]

    /// The `authorize-challenge` link relation this flow follows.
    var link: String {
        switch self {
        case .signUp:
            return "sign_up"
        case .signIn:
            return "sign_in"
        case .passwordReset:
            return "reset_password"
        case .unknown:
            return "unknown"
        }
    }
}

/// Internal continuation context carried by a ``MSALNativeAuthFlowState``.
///
/// Holds the opaque server `continuation_token` and the resolved `_links` hrefs
/// the SDK must follow to advance the server-driven flow.
struct MSALNativeAuthV2ContinuationState {
    let flowScenario: MSALNativeAuthFlowScenario
    let continuationToken: String
    /// Resolved `_links` keyed by relation (e.g. "verify", "resend", "update", "poll", "continue",
    /// "challenge", "enroll", "activate", "submitAttributes"). Per-method links are keyed "method:<id>".
    let links: [String: URL]
    let username: String?
    let sentToHint: String?
    let codeLength: Int?
    /// Auth methods offered for MFA / strong-auth (JIT) selection.
    let authMethods: [MSALAuthMethod]
    /// Scopes (caller-requested merged with the default OIDC scopes) to request on the final
    /// `/token` exchange. Threaded through every step.
    let scopes: [String]
    /// Values supplied by the app at sign-up start (keyed by attribute id, e.g. "email"/"password")
    /// that the SDK submits automatically when the server issues a `collectAttributes` request for
    /// them. Deliberately kept internal so the app never sees them again; must never be logged or
    /// exposed on the public surface.
    let signUpAutofillValues: [String: Any]?
    /// Attribute ids already auto-submitted from ``signUpAutofillValues`` during this sign-up flow.
    /// Used to detect when the server re-requests an attribute we already sent (e.g. after a
    /// validation failure) so the SDK surfaces an error to the app instead of resending in a loop.
    /// Carries no attribute values.
    let signUpAutofillSubmittedIds: Set<String>

    init(
        flowScenario: MSALNativeAuthFlowScenario,
        continuationToken: String,
        links: [String: URL],
        username: String?,
        sentToHint: String? = nil,
        codeLength: Int? = nil,
        authMethods: [MSALAuthMethod] = [],
        scopes: [String] = [],
        signUpAutofillValues: [String: Any]? = nil,
        signUpAutofillSubmittedIds: Set<String> = []
    ) {
        self.flowScenario = flowScenario
        self.continuationToken = continuationToken
        self.links = links
        self.username = username
        self.sentToHint = sentToHint
        self.codeLength = codeLength
        self.authMethods = authMethods
        self.scopes = scopes
        self.signUpAutofillValues = signUpAutofillValues
        self.signUpAutofillSubmittedIds = signUpAutofillSubmittedIds
    }

    func link(_ relation: String) -> URL? {
        return links[relation]
    }

    /// The challenge / enroll link associated with a specific auth method.
    func methodLink(for methodId: String) -> URL? {
        return links["method:\(methodId)"]
    }
}

/// Result produced by the unified V2 controller for a single step of a flow.
enum MSALNativeAuthV2FlowResult {
    case actionRequired(action: MSALNativeAuthAction, newState: MSALNativeAuthFlowState)
    case completed(MSALNativeAuthUserAccountResult)
    case error(error: MSALNativeAuthFlowError, newState: MSALNativeAuthFlowState?)
    case browserRequired(url: URL, newState: MSALNativeAuthFlowState)
}

/// Wraps the controller result with the correlation id and an optional telemetry update closure.
struct MSALNativeAuthV2FlowControllerResponse {
    let result: MSALNativeAuthV2FlowResult
    let correlationId: UUID
    /// The public scenario reported to the app (defaults to `.unknown` when the flow is undetermined).
    let scenario: MSALNativeAuthFlowScenario
    let telemetryUpdate: ((Result<Void, MSALNativeAuthError>) -> Void)?

    init(
        _ result: MSALNativeAuthV2FlowResult,
        correlationId: UUID,
        scenario: MSALNativeAuthFlowScenario = .unknown,
        telemetryUpdate: ((Result<Void, MSALNativeAuthError>) -> Void)? = nil
    ) {
        self.result = result
        self.correlationId = correlationId
        self.scenario = scenario
        self.telemetryUpdate = telemetryUpdate
    }
}

/// Routes a controller response to the appropriate ``MSALNativeAuthFlowDelegate`` callback.
///
/// V2 uses opt-in, per-state delegate protocols that extend ``MSALNativeAuthFlowDelegate``. For an
/// `actionRequired` result the dispatcher builds the concrete ``MSALNativeAuthState`` for the step,
/// wires it to the flow engine, and — if the app's delegate conforms to that step's protocol —
/// invokes its dedicated callback. If the app does not conform, the terminal
/// ``MSALNativeAuthFlowDelegate/onFlowError(error:scenario:)`` is called with error type `notImplemented`.
struct MSALNativeAuthFlowResponseDispatcher {

    @MainActor
    func dispatch(_ response: MSALNativeAuthV2FlowControllerResponse, delegate: MSALNativeAuthFlowDelegate) async {
        let scenario = response.scenario
        switch response.result {
        case .actionRequired(let action, let engine):
            await dispatchAction(action, engine: engine, scenario: scenario, response: response, delegate: delegate)
        case .completed(let result):
            await delegate.onFlowCompleted(result: result, scenario: scenario)
            response.telemetryUpdate?(.success(()))
        case .error(let error, _):
            await delegate.onFlowError(error: error, scenario: scenario)
        case .browserRequired(let url, _):
            let error = MSALNativeAuthFlowError(
                type: .browserRequired,
                errorDescription: "The flow must continue in a web browser: \(url.absoluteString)",
                correlationId: response.correlationId
            )
            await delegate.onFlowError(error: error, scenario: scenario)
            response.telemetryUpdate?(.success(()))
        }
    }

    @MainActor
    private func dispatchAction(
        _ action: MSALNativeAuthAction,
        engine: MSALNativeAuthFlowState,
        scenario: MSALNativeAuthFlowScenario,
        response: MSALNativeAuthV2FlowControllerResponse,
        delegate: MSALNativeAuthFlowDelegate
    ) async {
        switch action {
        case .codeRequired(let sentTo, let channel, let codeLength):
            let state = MSALNativeAuthCodeRequiredState(sentTo: sentTo, channel: channel, codeLength: codeLength)
            await deliver(state, engine: engine, scenario: scenario, response: response, delegate: delegate,
                          as: MSALNativeAuthCodeRequiredDelegate.self) { await $0.onCodeRequired(state: state, scenario: scenario) }
        case .passwordRequired:
            let state = MSALNativeAuthPasswordRequiredState()
            await deliver(state, engine: engine, scenario: scenario, response: response, delegate: delegate,
                          as: MSALNativeAuthPasswordRequiredDelegate.self) { await $0.onPasswordRequired(state: state, scenario: scenario) }
        case .newPasswordRequired:
            let state = MSALNativeAuthNewPasswordRequiredState()
            await deliver(state, engine: engine, scenario: scenario, response: response, delegate: delegate,
                          as: MSALNativeAuthNewPasswordRequiredDelegate.self) { await $0.onNewPasswordRequired(state: state, scenario: scenario) }
        case .attributesRequired(let attributes):
            let state = MSALNativeAuthAttributesRequiredState(attributes: attributes)
            await deliver(state, engine: engine, scenario: scenario, response: response, delegate: delegate,
                          as: MSALNativeAuthAttributesRequiredDelegate.self) {
                await $0.onAttributesRequired(state: state, scenario: scenario)
            }
        case .attributesInvalid(let attributeNames):
            let state = MSALNativeAuthAttributesInvalidState(attributeNames: attributeNames)
            await deliver(state, engine: engine, scenario: scenario, response: response, delegate: delegate,
                          as: MSALNativeAuthAttributesInvalidDelegate.self) { await $0.onAttributesInvalid(state: state, scenario: scenario) }
        case .mfaRequired(let authMethods):
            let state = MSALNativeAuthMFARequiredState(authMethods: authMethods)
            await deliver(state, engine: engine, scenario: scenario, response: response, delegate: delegate,
                          as: MSALNativeAuthMFARequiredDelegate.self) { await $0.onMFARequired(state: state, scenario: scenario) }
        case .mfaVerificationRequired(let sentTo, let channel, let codeLength):
            let state = MSALNativeAuthMFAVerificationRequiredState(sentTo: sentTo, channel: channel, codeLength: codeLength)
            await deliver(state, engine: engine, scenario: scenario, response: response, delegate: delegate,
                          as: MSALNativeAuthMFAVerificationRequiredDelegate.self) {
                await $0.onMFAVerificationRequired(state: state, scenario: scenario)
            }
        case .strongAuthRegistrationRequired(let authMethods):
            let state = MSALNativeAuthStrongAuthRegistrationRequiredState(authMethods: authMethods)
            await deliver(state, engine: engine, scenario: scenario, response: response, delegate: delegate,
                          as: MSALNativeAuthStrongAuthRegistrationRequiredDelegate.self) {
                await $0.onStrongAuthRegistrationRequired(state: state, scenario: scenario)
            }
        case .strongAuthVerificationRequired(let sentTo, let channel, let codeLength):
            let state = MSALNativeAuthStrongAuthVerificationRequiredState(sentTo: sentTo, channel: channel, codeLength: codeLength)
            await deliver(state, engine: engine, scenario: scenario, response: response, delegate: delegate,
                          as: MSALNativeAuthStrongAuthVerificationRequiredDelegate.self) {
                await $0.onStrongAuthVerificationRequired(state: state, scenario: scenario)
            }
        }
    }

    /// Wires a concrete state to the engine and invokes the app's per-state callback when the delegate
    /// conforms to `Delegate`; otherwise reports `notImplemented` through the terminal error callback.
    @MainActor
    private func deliver<Delegate>(
        _ state: MSALNativeAuthState,
        engine: MSALNativeAuthFlowState,
        scenario: MSALNativeAuthFlowScenario,
        response: MSALNativeAuthV2FlowControllerResponse,
        delegate: MSALNativeAuthFlowDelegate,
        as delegateType: Delegate.Type,
        callback: (Delegate) async -> Void
    ) async {
        prepare(state, engine: engine, scenario: scenario)
        if let typedDelegate = delegate as? Delegate {
            await callback(typedDelegate)
            response.telemetryUpdate?(.success(()))
        } else {
            await notImplemented(delegate: delegate, scenario: scenario, correlationId: response.correlationId)
        }
    }

    /// Wires a freshly built concrete state to the flow engine and stamps the originating scenario.
    private func prepare(_ state: MSALNativeAuthState, engine: MSALNativeAuthFlowState, scenario: MSALNativeAuthFlowScenario) {
        state.scenario = scenario
        state.engine = engine
    }

    @MainActor
    private func notImplemented(
        delegate: MSALNativeAuthFlowDelegate,
        scenario: MSALNativeAuthFlowScenario,
        correlationId: UUID
    ) async {
        await delegate.onFlowError(
            error: MSALNativeAuthFlowError(type: .notImplemented, correlationId: correlationId),
            scenario: scenario
        )
    }
}
