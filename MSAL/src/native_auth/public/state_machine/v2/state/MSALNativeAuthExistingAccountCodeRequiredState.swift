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

/// Sign-up found an existing account and sent an email code to sign it in, not to create an account.
///
/// Use the inherited `submitCode(_:delegate:)` to continue sign-in, including any MFA or enrollment steps.
/// An invalid code can be retried on this state. `resendCode(delegate:)` returns another
/// existing-account code state with the fresh code's destination and length.
/// Callbacks use the `signIn` scenario.
///
/// - Warning: This API is experimental. It may be changed in the future without notice. Do not use in production applications.
@objcMembers
public class MSALNativeAuthExistingAccountCodeRequiredState: MSALNativeAuthCodeRequiredState {

    /// Resend the sign-in code, retaining the existing-account callback for the fresh code state.
    /// Errors, browser fallback and enrollment outcomes retain their ordinary sign-in handling.
    public override func resendCode(delegate: MSALNativeAuthFlowDelegate) {
        run(delegate: delegate) { controller, state in
            let response = await controller.resendCode(state: state)
            guard case .actionRequired(let nextState as MSALNativeAuthCodeRequiredState) = response.result else {
                return response
            }
            let next = MSALNativeAuthExistingAccountCodeRequiredState(
                internalState: nextState.internalState,
                sentTo: nextState.sentTo,
                channel: nextState.channel,
                codeLength: nextState.codeLength
            )
            return MSALNativeAuthFlowControllerResponse(
                .actionRequired(state: next),
                correlationId: response.correlationId,
                scenario: response.scenario,
                telemetryUpdate: response.telemetryUpdate
            )
        }
    }

    public override var description: String {
        return "existingAccountCodeRequired"
    }
}

/// Handles existing-account email verification discovered during V2 sign-up.
///
/// - Warning: This API is experimental. It may be changed in the future without notice. Do not use in production applications.
@objc
public protocol MSALNativeAuthExistingAccountCodeRequiredDelegate: MSALNativeAuthFlowDelegate {

    /// Collect the existing account's email code and submit it through the state.
    /// - Parameters:
    ///   - state: The sign-in code state, including destination, channel, length, submit and resend operations.
    ///   - scenario: Always `signIn`, even though the flow started with sign-up.
    @MainActor func onExistingAccountCodeRequired(
        state: MSALNativeAuthExistingAccountCodeRequiredState,
        scenario: MSALNativeAuthFlowScenario
    )
}
