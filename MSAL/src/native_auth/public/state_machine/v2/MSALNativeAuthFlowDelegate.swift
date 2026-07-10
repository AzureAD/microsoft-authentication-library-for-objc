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
/// calling methods directly on the ``MSALNativeAuthAction`` it is handed.
///
/// Each server-driven action is delivered through its own strongly-typed callback (e.g.
/// ``onCodeRequired(action:)``), and each action exposes only the continuation methods valid for
/// that step — so the app never has to downcast a generic action or call an invalid continuation.
///
/// All callbacks are invoked on the main actor.
@objc
public protocol MSALNativeAuthFlowDelegate {

    /// The server requires the user to verify a one-time code.
    /// Continue with ``MSALNativeAuthCodeRequiredAction/submitCode(_:delegate:)`` (or request a new
    /// code with ``MSALNativeAuthCodeRequiredAction/resendCode(delegate:)``).
    /// - Parameters:
    ///   - action: The code-required action (destination, channel, expected length) that
    ///     also exposes the continuation methods.
    ///   - scenario: The flow (sign in / sign up / password reset) that produced this callback.
    @MainActor func onCodeRequired(action: MSALNativeAuthCodeRequiredAction, scenario: MSALNativeAuthFlowScenario)

    /// The server requires the user to enter their password.
    /// Continue with ``MSALNativeAuthPasswordRequiredAction/submitPassword(_:delegate:)``.
    /// - Parameters:
    ///   - action: The password-required action.
    ///   - scenario: The flow (sign in / sign up / password reset) that produced this callback.
    @MainActor func onPasswordRequired(action: MSALNativeAuthPasswordRequiredAction, scenario: MSALNativeAuthFlowScenario)

    /// The server requires the user to enter a new password (self-service password reset).
    /// Continue with ``MSALNativeAuthNewPasswordRequiredAction/submitNewPassword(_:delegate:)``.
    /// - Parameters:
    ///   - action: The new-password-required action.
    ///   - scenario: The flow (sign in / sign up / password reset) that produced this callback.
    @MainActor func onNewPasswordRequired(action: MSALNativeAuthNewPasswordRequiredAction, scenario: MSALNativeAuthFlowScenario)

    /// The server requires additional user attributes.
    /// Continue with ``MSALNativeAuthAttributesRequiredAction/submitAttributes(_:delegate:)``.
    /// - Parameters:
    ///   - action: The required-attributes action.
    ///   - scenario: The flow (sign in / sign up / password reset) that produced this callback.
    @MainActor func onAttributesRequired(action: MSALNativeAuthAttributesRequiredAction, scenario: MSALNativeAuthFlowScenario)

    /// The server reports that some attributes were invalid and must be corrected.
    /// Continue with ``MSALNativeAuthAttributesInvalidAction/submitAttributes(_:delegate:)``.
    /// - Parameters:
    ///   - action: The invalid-attributes action.
    ///   - scenario: The flow (sign in / sign up / password reset) that produced this callback.
    @MainActor func onAttributesInvalid(action: MSALNativeAuthAttributesInvalidAction, scenario: MSALNativeAuthFlowScenario)

    /// The server requires multi-factor authentication; the user must select an auth method.
    /// Continue with ``MSALNativeAuthMFARequiredAction/selectAuthMethod(_:verificationContact:delegate:)``.
    /// - Parameters:
    ///   - action: The MFA-required action (available auth methods).
    ///   - scenario: The flow (sign in / sign up / password reset) that produced this callback.
    @MainActor func onMFARequired(action: MSALNativeAuthMFARequiredAction, scenario: MSALNativeAuthFlowScenario)

    /// The server sent an MFA challenge; the user must enter the verification code.
    /// Continue with ``MSALNativeAuthMFAVerificationRequiredAction/submitChallenge(_:delegate:)``.
    /// - Parameters:
    ///   - action: The MFA verification action (destination, channel, expected length).
    ///   - scenario: The flow (sign in / sign up / password reset) that produced this callback.
    @MainActor func onMFAVerificationRequired(action: MSALNativeAuthMFAVerificationRequiredAction, scenario: MSALNativeAuthFlowScenario)

    /// The server requires strong authentication registration (JIT); the user must select an auth method.
    /// Continue with ``MSALNativeAuthStrongAuthRegistrationRequiredAction/selectAuthMethod(_:verificationContact:delegate:)``.
    /// - Parameters:
    ///   - action: The strong-auth registration action (available auth methods).
    ///   - scenario: The flow (sign in / sign up / password reset) that produced this callback.
    @MainActor func onStrongAuthRegistrationRequired(action: MSALNativeAuthStrongAuthRegistrationRequiredAction, scenario: MSALNativeAuthFlowScenario)

    /// The server sent a JIT challenge; the user must enter the verification code.
    /// Continue with ``MSALNativeAuthStrongAuthVerificationRequiredAction/submitChallenge(_:delegate:)``.
    /// - Parameters:
    ///   - action: The strong-auth verification action (destination, channel, expected length).
    ///   - scenario: The flow (sign in / sign up / password reset) that produced this callback.
    @MainActor func onStrongAuthVerificationRequired(action: MSALNativeAuthStrongAuthVerificationRequiredAction, scenario: MSALNativeAuthFlowScenario)

    /// The flow completed successfully and the user now has tokens.
    /// - Parameters:
    ///   - result: The authenticated user account result.
    ///   - scenario: The flow (sign in / sign up / password reset) that produced this callback.
    @MainActor func onFlowCompleted(result: MSALNativeAuthUserAccountResult, scenario: MSALNativeAuthFlowScenario)

    /// The flow encountered an error.
    /// - Parameters:
    ///   - error: The error that occurred. The app decides whether it can retry by
    ///     inspecting the error (e.g. `error.isInvalidCode` / `error.isInvalidPassword`) and calling
    ///     the appropriate method again on the action it is currently handling.
    ///   - scenario: The flow (sign in / sign up / password reset) that produced this callback.
    @MainActor func onFlowError(error: MSALNativeAuthFlowError, scenario: MSALNativeAuthFlowScenario)
}
