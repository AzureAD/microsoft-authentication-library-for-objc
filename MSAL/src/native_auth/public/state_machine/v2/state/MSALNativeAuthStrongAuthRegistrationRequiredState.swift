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

/// The server requires strong authentication registration (JIT); the user must select an auth method.
/// Continue with ``selectAuthMethod(_:verificationContact:delegate:)``.
/// V2 registration is server-driven and does not require configuring application capabilities.
/// Registration can interrupt sign-in, sign-up, or password reset; the original flow is preserved.
/// SMS and email options are surfaced when offered by the server.
/// After enrollment, the strong-auth verification state prompts for the code used to activate the selected method.
/// Successful activation returns `state: "continue"` and resumes completion of the original flow.
/// Activation does not introduce another MFA challenge.
/// JIT registration cannot follow an MFA challenge.
///
/// - Warning: This API is experimental. It may be changed in the future without notice. Do not use in production applications.
@objcMembers
public class MSALNativeAuthStrongAuthRegistrationRequiredState: MSALNativeAuthState {

    /// The recognized authentication methods offered by the server.
    public let authMethods: [MSALAuthMethod]

    let offeredMethods: [MSALNativeAuthV2EnrollmentMethod]

    init(internalState: MSALNativeAuthFlowInternalState, offeredMethods: [MSALNativeAuthV2EnrollmentMethod]) {
        self.offeredMethods = offeredMethods
        self.authMethods = offeredMethods.map(\.publicAuthMethod)
        super.init(internalState: internalState)
    }

    /// Select an authentication method for strong-auth registration.
    /// - Parameters:
    ///   - method: An entry from ``authMethods``; its ID is opaque and scoped to this state.
    ///   - verificationContact: The phone number (including its country calling code) or email address to register.
    ///     A nonempty contact is required.
    ///   - delegate: Receives the strong-auth verification state or a flow error.
    ///     An unoffered method or a missing/blank contact produces an `invalidInput` error.
    public func selectAuthMethod(
        _ method: MSALAuthMethod,
        verificationContact: String?,
        delegate: MSALNativeAuthFlowDelegate
    ) {
        run(delegate: delegate) { controller, state in
            await controller.enrollAuthMethod(
                method,
                offeredMethods: self.offeredMethods,
                verificationContact: verificationContact,
                state: state
            )
        }
    }

    /// Select an authentication method for strong-auth registration, without an explicit
    /// verification contact.
    /// Enrollment requires a contact, so this overload reports an `invalidInput` flow error.
    public func selectAuthMethod(_ method: MSALAuthMethod, delegate: MSALNativeAuthFlowDelegate) {
        selectAuthMethod(method, verificationContact: nil, delegate: delegate)
    }

    public override var description: String {
        return "strongAuthRegistrationRequired"
    }
}

/// Per-state delegate for the ``MSALNativeAuthStrongAuthRegistrationRequiredState`` step of a Native Auth V2 flow.
///
/// Conform to this protocol (in addition to the terminal callbacks inherited from
/// ``MSALNativeAuthFlowDelegate``) to handle this state. Conforming is opt-in per state, but the
/// callback is required once you conform.
///
/// - Warning: This API is experimental. It may be changed in the future without notice. Do not use in production applications.
@objc
public protocol MSALNativeAuthStrongAuthRegistrationRequiredDelegate: MSALNativeAuthFlowDelegate {

    /// The server requires strong authentication registration (JIT); the user must select an auth method.
    /// Continue with ``MSALNativeAuthStrongAuthRegistrationRequiredState/selectAuthMethod(_:verificationContact:delegate:)``.
    /// - Parameters:
    ///   - state: The strong-auth registration state (available auth methods).
    ///   - scenario: The flow that produced this callback.
    /// - Note: If the app's delegate does not conform to this protocol, then
    ///   ``MSALNativeAuthFlowDelegate/onFlowError(error:scenario:)`` is called with error type `notImplemented`.
    @MainActor func onStrongAuthRegistrationRequired(state: MSALNativeAuthStrongAuthRegistrationRequiredState, scenario: MSALNativeAuthFlowScenario)
}
