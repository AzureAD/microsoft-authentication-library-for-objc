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

/// Routes a controller response to the appropriate ``MSALNativeAuthFlowDelegate`` callback.
///
/// V2 uses opt-in, per-state delegate protocols that extend ``MSALNativeAuthFlowDelegate``. For an
/// `actionRequired` result the dispatcher builds the concrete ``MSALNativeAuthState`` for the step,
/// wires it to the internal state, and - if the app's delegate conforms to that step's protocol -
/// invokes its dedicated callback. If the app does not conform, the terminal
/// ``MSALNativeAuthFlowDelegate/onFlowError(error:scenario:)`` is called with error type `notImplemented`.
struct MSALNativeAuthFlowResponseDispatcher {

    func dispatch(_ response: MSALNativeAuthFlowControllerResponse, delegate: MSALNativeAuthFlowDelegate) async {
        let scenario = response.scenario
        switch response.result {
        case .actionRequired(let action, let internalState):
            await dispatchAction(action, internalState: internalState, scenario: scenario, response: response, delegate: delegate)
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

    private func dispatchAction(
        _ action: MSALNativeAuthAction,
        internalState: MSALNativeAuthFlowInternalState,
        scenario: MSALNativeAuthFlowScenario,
        response: MSALNativeAuthFlowControllerResponse,
        delegate: MSALNativeAuthFlowDelegate
    ) async {
        switch action {
        case .codeRequired(let sentTo, let channel, let codeLength):
            let state = MSALNativeAuthCodeRequiredState(sentTo: sentTo, channel: channel, codeLength: codeLength)
            await deliver(state, internalState: internalState, scenario: scenario, response: response, delegate: delegate,
                          as: MSALNativeAuthCodeRequiredDelegate.self) { await $0.onCodeRequired(state: state, scenario: scenario) }
        case .passwordRequired:
            let state = MSALNativeAuthPasswordRequiredState()
            await deliver(state, internalState: internalState, scenario: scenario, response: response, delegate: delegate,
                          as: MSALNativeAuthPasswordRequiredDelegate.self) { await $0.onPasswordRequired(state: state, scenario: scenario) }
        case .newPasswordRequired:
            let state = MSALNativeAuthNewPasswordRequiredState()
            await deliver(state, internalState: internalState, scenario: scenario, response: response, delegate: delegate,
                          as: MSALNativeAuthNewPasswordRequiredDelegate.self) { await $0.onNewPasswordRequired(state: state, scenario: scenario) }
        case .attributesRequired(let attributes):
            let state = MSALNativeAuthAttributesRequiredState(attributes: attributes)
            await deliver(state, internalState: internalState, scenario: scenario, response: response, delegate: delegate,
                          as: MSALNativeAuthAttributesRequiredDelegate.self) {
                await $0.onAttributesRequired(state: state, scenario: scenario)
            }
        case .attributesInvalid(let attributeNames):
            let state = MSALNativeAuthAttributesInvalidState(attributeNames: attributeNames)
            await deliver(state, internalState: internalState, scenario: scenario, response: response, delegate: delegate,
                          as: MSALNativeAuthAttributesInvalidDelegate.self) { await $0.onAttributesInvalid(state: state, scenario: scenario) }
        case .mfaRequired(let authMethods):
            let state = MSALNativeAuthMFARequiredState(authMethods: authMethods)
            await deliver(state, internalState: internalState, scenario: scenario, response: response, delegate: delegate,
                          as: MSALNativeAuthMFARequiredDelegate.self) { await $0.onMFARequired(state: state, scenario: scenario) }
        case .mfaVerificationRequired(let sentTo, let channel, let codeLength):
            let state = MSALNativeAuthMFAVerificationRequiredState(sentTo: sentTo, channel: channel, codeLength: codeLength)
            await deliver(state, internalState: internalState, scenario: scenario, response: response, delegate: delegate,
                          as: MSALNativeAuthMFAVerificationRequiredDelegate.self) {
                await $0.onMFAVerificationRequired(state: state, scenario: scenario)
            }
        case .strongAuthRegistrationRequired(let authMethods):
            let state = MSALNativeAuthStrongAuthRegistrationRequiredState(authMethods: authMethods)
            await deliver(state, internalState: internalState, scenario: scenario, response: response, delegate: delegate,
                          as: MSALNativeAuthStrongAuthRegistrationRequiredDelegate.self) {
                await $0.onStrongAuthRegistrationRequired(state: state, scenario: scenario)
            }
        case .strongAuthVerificationRequired(let sentTo, let channel, let codeLength):
            let state = MSALNativeAuthStrongAuthVerificationRequiredState(sentTo: sentTo, channel: channel, codeLength: codeLength)
            await deliver(state, internalState: internalState, scenario: scenario, response: response, delegate: delegate,
                          as: MSALNativeAuthStrongAuthVerificationRequiredDelegate.self) {
                await $0.onStrongAuthVerificationRequired(state: state, scenario: scenario)
            }
        }
    }

    /// Wires a concrete state to its internal state and originating scenario, then invokes the app's
    /// per-state callback when the delegate conforms to `Delegate`; otherwise reports `notImplemented`
    /// through the terminal error callback.
    private func deliver<Delegate>(
        _ state: MSALNativeAuthState,
        internalState: MSALNativeAuthFlowInternalState,
        scenario: MSALNativeAuthFlowScenario,
        response: MSALNativeAuthFlowControllerResponse,
        delegate: MSALNativeAuthFlowDelegate,
        as delegateType: Delegate.Type,
        callback: (Delegate) async -> Void
    ) async {
        state.internalState = internalState
        state.scenario = scenario
        if let typedDelegate = delegate as? Delegate {
            await callback(typedDelegate)
            response.telemetryUpdate?(.success(()))
        } else {
            await notImplemented(delegate: delegate, scenario: scenario, correlationId: response.correlationId)
        }
    }

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
