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
/// `actionRequired` result the dispatcher matches the concrete ``MSALNativeAuthState`` to its
/// per-state delegate protocol and - if the app's delegate conforms - invokes its dedicated
/// callback. If the app does not conform, the terminal
/// ``MSALNativeAuthFlowDelegate/onFlowError(error:scenario:)`` is called with error type `notImplemented`.
struct MSALNativeAuthFlowResponseDispatcher {

    func dispatch(_ response: MSALNativeAuthFlowControllerResponse, delegate: MSALNativeAuthFlowDelegate) async {
        let scenario = response.scenario
        switch response.result {
        case .actionRequired(let state):
            await dispatchActionRequired(state, response: response, delegate: delegate)
        case .completed(let result):
            await delegate.onFlowCompleted(result: result, scenario: scenario)
            response.telemetryUpdate?(.success(()))
        case .error(let error):
            await delegate.onFlowError(error: error, scenario: scenario)
        case .browserRequired:
            let error = MSALNativeAuthFlowError(
                type: .browserRequired,
                correlationId: response.correlationId
            )
            await delegate.onFlowError(error: error, scenario: scenario)
            response.telemetryUpdate?(.success(()))
        }
    }

    // swiftlint:disable:next function_body_length
    private func dispatchActionRequired(
        _ state: MSALNativeAuthState,
        response: MSALNativeAuthFlowControllerResponse,
        delegate: MSALNativeAuthFlowDelegate
    ) async {
        let scenario = state.internalState.continuation.flowScenario
        switch state {
        case let state as MSALNativeAuthCodeRequiredState:
            await deliver(to: delegate,
                          delegateName: "MSALNativeAuthCodeRequiredDelegate",
                          response: response,
                          as: MSALNativeAuthCodeRequiredDelegate.self,
                          scenario: scenario) {
                await $0.onCodeRequired(state: state, scenario: scenario)
            }
        case let state as MSALNativeAuthPasswordRequiredState:
            await deliver(to: delegate,
                          delegateName: "MSALNativeAuthPasswordRequiredDelegate",
                          response: response,
                          as: MSALNativeAuthPasswordRequiredDelegate.self,
                          scenario: scenario) {
                await $0.onPasswordRequired(state: state, scenario: scenario)
            }
        case let state as MSALNativeAuthMFARequiredState:
            await deliver(to: delegate,
                          delegateName: "MSALNativeAuthMFARequiredDelegate",
                          response: response,
                          as: MSALNativeAuthMFARequiredDelegate.self,
                          scenario: scenario) {
                await $0.onMFARequired(state: state, scenario: scenario)
            }
        case let state as MSALNativeAuthMFAVerificationRequiredState:
            await deliver(to: delegate,
                          delegateName: "MSALNativeAuthMFAVerificationRequiredDelegate",
                          response: response,
                          as: MSALNativeAuthMFAVerificationRequiredDelegate.self,
                          scenario: scenario) {
                await $0.onMFAVerificationRequired(state: state, scenario: scenario)
            }
        case let state as MSALNativeAuthNewPasswordRequiredState:
            await deliver(to: delegate,
                          delegateName: "MSALNativeAuthNewPasswordRequiredDelegate",
                          response: response,
                          as: MSALNativeAuthNewPasswordRequiredDelegate.self,
                          scenario: scenario) {
                await $0.onNewPasswordRequired(state: state, scenario: scenario)
            }
        case let state as MSALNativeAuthSignInAfterResetPasswordState:
            await deliver(to: delegate,
                          delegateName: "MSALNativeAuthSignInAfterResetPasswordRequiredDelegate",
                          response: response,
                          as: MSALNativeAuthSignInAfterResetPasswordRequiredDelegate.self,
                          scenario: scenario) {
                await $0.onSignInAfterResetPasswordRequired(state: state, scenario: scenario)
            }
        case let state as MSALNativeAuthSignInAfterSignUpState:
            await deliver(to: delegate,
                          delegateName: "MSALNativeAuthSignInAfterSignUpRequiredDelegate",
                          response: response,
                          as: MSALNativeAuthSignInAfterSignUpRequiredDelegate.self,
                          scenario: scenario) {
                await $0.onSignInAfterSignUpRequired(state: state, scenario: scenario)
            }
        case let state as MSALNativeAuthAttributesRequiredState:
            await deliver(to: delegate,
                          delegateName: "MSALNativeAuthAttributesRequiredDelegate",
                          response: response,
                          as: MSALNativeAuthAttributesRequiredDelegate.self,
                          scenario: scenario) {
                await $0.onAttributesRequired(state: state, scenario: scenario)
            }
        case let state as MSALNativeAuthAttributesInvalidState:
            await deliver(to: delegate,
                          delegateName: "MSALNativeAuthAttributesInvalidDelegate",
                          response: response,
                          as: MSALNativeAuthAttributesInvalidDelegate.self,
                          scenario: scenario) {
                await $0.onAttributesInvalid(state: state, scenario: scenario)
            }
        default:
            await notImplemented(delegate: delegate, delegateName: "unknown", scenario: scenario, correlationId: response.correlationId)
        }
    }

    /// Invokes the app's per-state callback when the delegate conforms to `Delegate`; otherwise
    /// reports `notImplemented` through the error callback.
    private func deliver<Delegate>(
        to delegate: MSALNativeAuthFlowDelegate,
        delegateName: String,
        response: MSALNativeAuthFlowControllerResponse,
        as delegateType: Delegate.Type,
        scenario: MSALNativeAuthFlowScenario,
        callback: (Delegate) async -> Void
    ) async {
        if let typedDelegate = delegate as? Delegate {
            await callback(typedDelegate)
            response.telemetryUpdate?(.success(()))
        } else {
            await notImplemented(delegate: delegate, delegateName: delegateName, scenario: scenario, correlationId: response.correlationId)
        }
    }

    private func notImplemented(
        delegate: MSALNativeAuthFlowDelegate,
        delegateName: String,
        scenario: MSALNativeAuthFlowScenario,
        correlationId: UUID
    ) async {
        await delegate.onFlowError(
            error: MSALNativeAuthFlowError(type: .notImplemented,
                                           errorDescription: String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, delegateName),
                                            correlationId: correlationId),
            scenario: scenario
        )
    }
}
