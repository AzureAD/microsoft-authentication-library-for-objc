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

/// Single unified delegate for all Native Auth V2 (server-driven) flows.
///
/// Unlike V1 — which exposes a different delegate protocol per step — V2 uses one
/// delegate for sign up, sign in and reset password. The SDK drives the flow and
/// reports back through these callbacks; the app reacts and continues the flow by
/// calling methods directly on the ``MSALNativeAuthState`` it is handed.
///
/// Each server-driven state is delivered through its own strongly-typed callback (e.g.
/// ``onCodeRequired(state:)``), and each state exposes only the continuation methods valid for
/// that step — so the app never has to downcast a generic state or call an invalid continuation.
///
/// All callbacks are invoked on the main actor.
@objc
public protocol MSALNativeAuthFlowDelegate {

    /// The server requires the user to verify a one-time code.
    /// Continue with ``MSALNativeAuthCodeRequiredState/submitCode(_:delegate:)`` (or request a new
    /// code with ``MSALNativeAuthCodeRequiredState/resendCode(delegate:)``).
    /// - Parameters:
    ///   - state: The code-required state (destination, channel, expected length) that
    ///     also exposes the continuation methods.
    ///   - scenario: The flow (sign in / sign up / password reset) that produced this callback.
    @MainActor func onCodeRequired(state: MSALNativeAuthCodeRequiredState, scenario: MSALNativeAuthFlowScenario)

    /// The server requires the user to enter their password.
    /// Continue with ``MSALNativeAuthPasswordRequiredState/submitPassword(_:delegate:)``.
    /// - Parameters:
    ///   - state: The password-required state.
    ///   - scenario: The flow (sign in / sign up / password reset) that produced this callback.
    @MainActor func onPasswordRequired(state: MSALNativeAuthPasswordRequiredState, scenario: MSALNativeAuthFlowScenario)

    /// The server requires the user to enter a new password (self-service password reset).
    /// Continue with ``MSALNativeAuthNewPasswordRequiredState/submitNewPassword(_:delegate:)``.
    /// - Parameters:
    ///   - state: The new-password-required state.
    ///   - scenario: The flow (sign in / sign up / password reset) that produced this callback.
    @MainActor func onNewPasswordRequired(state: MSALNativeAuthNewPasswordRequiredState, scenario: MSALNativeAuthFlowScenario)

    /// The server requires additional user attributes.
    /// Continue with ``MSALNativeAuthAttributesRequiredState/submitAttributes(_:delegate:)``.
    /// - Parameters:
    ///   - state: The required-attributes state.
    ///   - scenario: The flow (sign in / sign up / password reset) that produced this callback.
    @MainActor func onAttributesRequired(state: MSALNativeAuthAttributesRequiredState, scenario: MSALNativeAuthFlowScenario)

    /// The server reports that some attributes were invalid and must be corrected.
    /// Continue with ``MSALNativeAuthAttributesInvalidState/submitAttributes(_:delegate:)``.
    /// - Parameters:
    ///   - state: The invalid-attributes state.
    ///   - scenario: The flow (sign in / sign up / password reset) that produced this callback.
    @MainActor func onAttributesInvalid(state: MSALNativeAuthAttributesInvalidState, scenario: MSALNativeAuthFlowScenario)

    /// The server requires multi-factor authentication; the user must select an auth method.
    /// Continue with ``MSALNativeAuthMFARequiredState/selectAuthMethod(_:verificationContact:delegate:)``.
    /// - Parameters:
    ///   - state: The MFA-required state (available auth methods).
    ///   - scenario: The flow (sign in / sign up / password reset) that produced this callback.
    @MainActor func onMFARequired(state: MSALNativeAuthMFARequiredState, scenario: MSALNativeAuthFlowScenario)

    /// The server sent an MFA challenge; the user must enter the verification code.
    /// Continue with ``MSALNativeAuthMFAVerificationRequiredState/submitChallenge(_:delegate:)``.
    /// - Parameters:
    ///   - state: The MFA verification state (destination, channel, expected length).
    ///   - scenario: The flow (sign in / sign up / password reset) that produced this callback.
    @MainActor func onMFAVerificationRequired(state: MSALNativeAuthMFAVerificationRequiredState, scenario: MSALNativeAuthFlowScenario)

    /// The server requires strong authentication registration (JIT); the user must select an auth method.
    /// Continue with ``MSALNativeAuthStrongAuthRegistrationRequiredState/selectAuthMethod(_:verificationContact:delegate:)``.
    /// - Parameters:
    ///   - state: The strong-auth registration state (available auth methods).
    ///   - scenario: The flow (sign in / sign up / password reset) that produced this callback.
    @MainActor func onStrongAuthRegistrationRequired(state: MSALNativeAuthStrongAuthRegistrationRequiredState, scenario: MSALNativeAuthFlowScenario)

    /// The server sent a JIT challenge; the user must enter the verification code.
    /// Continue with ``MSALNativeAuthStrongAuthVerificationRequiredState/submitChallenge(_:delegate:)``.
    /// - Parameters:
    ///   - state: The strong-auth verification state (destination, channel, expected length).
    ///   - scenario: The flow (sign in / sign up / password reset) that produced this callback.
    @MainActor func onStrongAuthVerificationRequired(state: MSALNativeAuthStrongAuthVerificationRequiredState, scenario: MSALNativeAuthFlowScenario)

    /// The flow completed successfully and the user now has tokens.
    /// - Parameters:
    ///   - result: The authenticated user account result.
    ///   - scenario: The flow (sign in / sign up / password reset) that produced this callback.
    @MainActor func onFlowCompleted(result: MSALNativeAuthUserAccountResult, scenario: MSALNativeAuthFlowScenario)

    /// The flow encountered an error.
    /// - Parameters:
    ///   - error: The error that occurred. The app decides whether it can retry by
    ///     inspecting the error (e.g. `error.isInvalidCode` / `error.isInvalidPassword`) and calling
    ///     the appropriate method again on the state it is currently handling.
    ///   - scenario: The flow (sign in / sign up / password reset) that produced this callback.
    @MainActor func onFlowError(error: MSALNativeAuthFlowError, scenario: MSALNativeAuthFlowScenario)
}
