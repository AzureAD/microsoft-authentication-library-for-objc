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
    /// - Parameter action: The code-required action (destination, channel, expected length) that
    ///   also exposes the continuation methods.
    @MainActor func onCodeRequired(action: MSALNativeAuthCodeRequiredAction)

    /// The server requires the user to enter their password.
    /// Continue with ``MSALNativeAuthPasswordRequiredAction/submitPassword(_:delegate:)``.
    /// - Parameter action: The password-required action.
    @MainActor func onPasswordRequired(action: MSALNativeAuthPasswordRequiredAction)

    /// The server requires the user to enter a new password (self-service password reset).
    /// Continue with ``MSALNativeAuthNewPasswordRequiredAction/submitNewPassword(_:delegate:)``.
    /// - Parameter action: The new-password-required action.
    @MainActor func onNewPasswordRequired(action: MSALNativeAuthNewPasswordRequiredAction)

    /// The server requires additional user attributes.
    /// Continue with ``MSALNativeAuthAttributesRequiredAction/submitAttributes(_:delegate:)``.
    /// - Parameter action: The required-attributes action.
    @MainActor func onAttributesRequired(action: MSALNativeAuthAttributesRequiredAction)

    /// The server reports that some attributes were invalid and must be corrected.
    /// Continue with ``MSALNativeAuthAttributesInvalidAction/submitAttributes(_:delegate:)``.
    /// - Parameter action: The invalid-attributes action.
    @MainActor func onAttributesInvalid(action: MSALNativeAuthAttributesInvalidAction)

    /// The server requires multi-factor authentication; the user must select an auth method.
    /// Continue with ``MSALNativeAuthMFARequiredAction/selectAuthMethod(_:verificationContact:delegate:)``.
    /// - Parameter action: The MFA-required action (available auth methods).
    @MainActor func onMFARequired(action: MSALNativeAuthMFARequiredAction)

    /// The server sent an MFA challenge; the user must enter the verification code.
    /// Continue with ``MSALNativeAuthMFAVerificationRequiredAction/submitChallenge(_:delegate:)``.
    /// - Parameter action: The MFA verification action (destination, channel, expected length).
    @MainActor func onMFAVerificationRequired(action: MSALNativeAuthMFAVerificationRequiredAction)

    /// The server requires strong authentication registration (JIT); the user must select an auth method.
    /// Continue with ``MSALNativeAuthStrongAuthRegistrationRequiredAction/selectAuthMethod(_:verificationContact:delegate:)``.
    /// - Parameter action: The strong-auth registration action (available auth methods).
    @MainActor func onStrongAuthRegistrationRequired(action: MSALNativeAuthStrongAuthRegistrationRequiredAction)

    /// The server sent a JIT challenge; the user must enter the verification code.
    /// Continue with ``MSALNativeAuthStrongAuthVerificationRequiredAction/submitChallenge(_:delegate:)``.
    /// - Parameter action: The strong-auth verification action (destination, channel, expected length).
    @MainActor func onStrongAuthVerificationRequired(action: MSALNativeAuthStrongAuthVerificationRequiredAction)

    /// The flow completed successfully and the user now has tokens.
    /// - Parameter result: The authenticated user account result.
    @MainActor func onFlowCompleted(result: MSALNativeAuthUserAccountResult)

    /// The flow encountered an error.
    /// - Parameter error: The error that occurred. The app decides whether it can retry by
    ///   inspecting the error (e.g. `error.isInvalidCode` / `error.isInvalidPassword`) and calling
    ///   the appropriate method again on the action it is currently handling.
    @MainActor func onFlowError(error: MSALNativeAuthFlowError)
}
