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

/// Internal continuation context carried by a ``MSALNativeAuthState``.
///
/// Holds the opaque server `continuation_token` and the resolved `_links` hrefs
/// the SDK must follow to advance the server-driven flow.
struct MSALNativeAuthV2ContinuationState {
    let scenario: MSALNativeAuthFlowScenario
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
    /// `/token` exchange. Threaded through every step so completion mirrors the V1 sign-in flow.
    let scopes: [String]

    init(
        scenario: MSALNativeAuthFlowScenario,
        continuationToken: String,
        links: [String: URL],
        username: String?,
        sentToHint: String? = nil,
        codeLength: Int? = nil,
        authMethods: [MSALAuthMethod] = [],
        scopes: [String] = []
    ) {
        self.scenario = scenario
        self.continuationToken = continuationToken
        self.links = links
        self.username = username
        self.sentToHint = sentToHint
        self.codeLength = codeLength
        self.authMethods = authMethods
        self.scopes = scopes
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
    case stateRequired(state: MSALNativeAuthState)
    case completed(MSALNativeAuthUserAccountResult)
    /// A terminal error. The app decides whether it can retry (e.g. via `error.isInvalidCode` /
    /// `error.isInvalidPassword`) by calling the appropriate method again on the state it is
    /// currently handling.
    case error(error: MSALNativeAuthFlowError)
}

/// Wraps the controller result with the correlation id and an optional telemetry update closure.
struct MSALNativeAuthV2FlowControllerResponse {
    let result: MSALNativeAuthV2FlowResult
    let correlationId: UUID
    /// The flow that produced this response, reported to the app as a ``MSALNativeAuthFlowScenario``.
    let scenario: MSALNativeAuthFlowScenario
    let telemetryUpdate: ((Result<Void, MSALNativeAuthError>) -> Void)?

    init(
        _ result: MSALNativeAuthV2FlowResult,
        correlationId: UUID,
        scenario: MSALNativeAuthFlowScenario,
        telemetryUpdate: ((Result<Void, MSALNativeAuthError>) -> Void)? = nil
    ) {
        self.result = result
        self.correlationId = correlationId
        self.scenario = scenario
        self.telemetryUpdate = telemetryUpdate
    }
}

/// Routes a controller response to the appropriate ``MSALNativeAuthFlowDelegate`` callback.
struct MSALNativeAuthFlowResponseDispatcher {

    func dispatch(
        _ response: MSALNativeAuthV2FlowControllerResponse,
        delegate: MSALNativeAuthFlowDelegate
    ) async {
        let scenario = response.scenario
        switch response.result {
        case .stateRequired(let state):
            await dispatchState(state, scenario: scenario, correlationId: response.correlationId, delegate: delegate)
            response.telemetryUpdate?(.success(()))
        case .completed(let result):
            await delegate.onFlowCompleted(result: result, scenario: scenario)
            response.telemetryUpdate?(.success(()))
        case .error(let error):
            await delegate.onFlowError(error: error, scenario: scenario)
        }
    }

    /// Maps a concrete ``MSALNativeAuthState`` onto its dedicated delegate callback, so apps never
    /// have to downcast the state themselves.
    @MainActor
    private func dispatchState(
        _ state: MSALNativeAuthState,
        scenario: MSALNativeAuthFlowScenario,
        correlationId: UUID,
        delegate: MSALNativeAuthFlowDelegate
    ) {
        switch state {
        case let state as MSALNativeAuthCodeRequiredState:
            fallBackToErrorIfUnhandled(
                (delegate as? MSALNativeAuthCodeRequiredDelegate)?.onCodeRequired(state: state, scenario: scenario),
                expectedProtocol: "MSALNativeAuthCodeRequiredDelegate",
                expectedMethod: "onCodeRequired(state:scenario:)",
                scenario: scenario, correlationId: correlationId, delegate: delegate)
        case let state as MSALNativeAuthPasswordRequiredState:
            fallBackToErrorIfUnhandled(
                (delegate as? MSALNativeAuthPasswordRequiredDelegate)?.onPasswordRequired(state: state, scenario: scenario),
                expectedProtocol: "MSALNativeAuthPasswordRequiredDelegate",
                expectedMethod: "onPasswordRequired(state:scenario:)",
                scenario: scenario, correlationId: correlationId, delegate: delegate)
        case let state as MSALNativeAuthNewPasswordRequiredState:
            fallBackToErrorIfUnhandled(
                (delegate as? MSALNativeAuthNewPasswordRequiredDelegate)?.onNewPasswordRequired(state: state, scenario: scenario),
                expectedProtocol: "MSALNativeAuthNewPasswordRequiredDelegate",
                expectedMethod: "onNewPasswordRequired(state:scenario:)",
                scenario: scenario, correlationId: correlationId, delegate: delegate)
        case let state as MSALNativeAuthAttributesRequiredState:
            fallBackToErrorIfUnhandled(
                (delegate as? MSALNativeAuthAttributesRequiredDelegate)?.onAttributesRequired(state: state, scenario: scenario),
                expectedProtocol: "MSALNativeAuthAttributesRequiredDelegate",
                expectedMethod: "onAttributesRequired(state:scenario:)",
                scenario: scenario, correlationId: correlationId, delegate: delegate)
        case let state as MSALNativeAuthAttributesInvalidState:
            fallBackToErrorIfUnhandled(
                (delegate as? MSALNativeAuthAttributesInvalidDelegate)?.onAttributesInvalid(state: state, scenario: scenario),
                expectedProtocol: "MSALNativeAuthAttributesInvalidDelegate",
                expectedMethod: "onAttributesInvalid(state:scenario:)",
                scenario: scenario, correlationId: correlationId, delegate: delegate)
        case let state as MSALNativeAuthMFARequiredState:
            fallBackToErrorIfUnhandled(
                (delegate as? MSALNativeAuthMFARequiredDelegate)?.onMFARequired(state: state, scenario: scenario),
                expectedProtocol: "MSALNativeAuthMFARequiredDelegate",
                expectedMethod: "onMFARequired(state:scenario:)",
                scenario: scenario, correlationId: correlationId, delegate: delegate)
        case let state as MSALNativeAuthMFAVerificationRequiredState:
            fallBackToErrorIfUnhandled(
                (delegate as? MSALNativeAuthMFAVerificationRequiredDelegate)?.onMFAVerificationRequired(state: state, scenario: scenario),
                expectedProtocol: "MSALNativeAuthMFAVerificationRequiredDelegate",
                expectedMethod: "onMFAVerificationRequired(state:scenario:)",
                scenario: scenario, correlationId: correlationId, delegate: delegate)
        case let state as MSALNativeAuthStrongAuthRegistrationRequiredState:
            fallBackToErrorIfUnhandled(
                (delegate as? MSALNativeAuthStrongAuthRegistrationRequiredDelegate)?
                    .onStrongAuthRegistrationRequired(state: state, scenario: scenario),
                expectedProtocol: "MSALNativeAuthStrongAuthRegistrationRequiredDelegate",
                expectedMethod: "onStrongAuthRegistrationRequired(state:scenario:)",
                scenario: scenario, correlationId: correlationId, delegate: delegate)
        case let state as MSALNativeAuthStrongAuthVerificationRequiredState:
            fallBackToErrorIfUnhandled(
                (delegate as? MSALNativeAuthStrongAuthVerificationRequiredDelegate)?
                    .onStrongAuthVerificationRequired(state: state, scenario: scenario),
                expectedProtocol: "MSALNativeAuthStrongAuthVerificationRequiredDelegate",
                expectedMethod: "onStrongAuthVerificationRequired(state:scenario:)",
                scenario: scenario, correlationId: correlationId, delegate: delegate)
        default:
            let error = MSALNativeAuthFlowError(type: .generalError, correlationId: correlationId)
            delegate.onFlowError(error: error, scenario: scenario)
        }
    }

    /// Routes to ``MSALNativeAuthFlowDelegate/onFlowError(error:scenario:)`` with a `notImplemented`
    /// error when the app's delegate does not conform to the per-state delegate protocol for the
    /// current state (the `as?` cast returns `nil`, so the optional-chained call returns `nil`). Once
    /// a delegate conforms to a per-state protocol its callback is required, so a missing handler can
    /// only mean the app did not conform.
    ///
    /// To reduce integration mistakes (a missing handler surfacing only as a runtime error and a
    /// support question), the `notImplemented` error carries an actionable message naming the exact
    /// per-state delegate protocol and method to implement, the failure is logged at `.error`
    /// (non-PII: only type/method/scenario names), and — in `DEBUG` builds only — an
    /// `assertionFailure` fires so the missing handler is caught during development without crashing
    /// release/customer builds.
    @MainActor
    private func fallBackToErrorIfUnhandled(
        _ callbackResult: Void?,
        expectedProtocol: String,
        expectedMethod: String,
        scenario: MSALNativeAuthFlowScenario,
        correlationId: UUID,
        delegate: MSALNativeAuthFlowDelegate
    ) {
        guard callbackResult == nil else { return }

        let message = "No delegate handled the \(scenarioDescription(scenario)) flow: the app's delegate does not "
            + "conform to \(expectedProtocol) (which extends MSALNativeAuthFlowDelegate). "
            + "Conform to it and implement \(expectedMethod). "
            + "See the MSAL Native Auth V2 documentation for the states each flow can reach."

        MSALNativeAuthLogger.log(level: .error, context: nil, format: message)

        #if DEBUG
        assertionFailure(message)
        #endif

        let error = MSALNativeAuthFlowError(type: .notImplemented, errorDescription: message, correlationId: correlationId)
        delegate.onFlowError(error: error, scenario: scenario)
    }

    private func scenarioDescription(_ scenario: MSALNativeAuthFlowScenario) -> String {
        switch scenario {
        case .signIn:
            return "sign in"
        case .signUp:
            return "sign up"
        case .passwordReset:
            return "password reset"
        case .unknown:
            return "unknown"
        @unknown default:
            return "unknown"
        }
    }
}
