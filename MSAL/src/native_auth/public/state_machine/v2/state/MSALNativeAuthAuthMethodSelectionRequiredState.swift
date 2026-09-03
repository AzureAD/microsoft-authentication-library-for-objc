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

/// The server requires the user to select an authentication method.
/// This state can be emitted by sign-in (MFA) and password-reset flows.
/// Continue with ``selectAuthMethod(_:verificationContact:delegate:)``.
///
/// - Warning: This API is experimental. It may be changed in the future without notice. Do not use in production applications.
@objcMembers
public class MSALNativeAuthAuthMethodSelectionRequiredState: MSALNativeAuthState {

    /// The authentication methods available for selection.
    public let authMethods: [MSALAuthMethod]

    init(internalState: MSALNativeAuthFlowInternalState, authMethods: [MSALAuthMethod]) {
        self.authMethods = authMethods
        super.init(internalState: internalState)
    }

    /// Select an authentication method.
    /// - Parameters:
    ///   - method: The authentication method selected from ``authMethods``.
    ///   - verificationContact: An optional contact value to verify for flows that require the app to
    ///     provide one. Pass `nil` when the server-provided method already contains the destination.
    ///   - delegate: The delegate that receives the next flow callback.
    public func selectAuthMethod(
        _ method: MSALAuthMethod,
        verificationContact: String?,
        delegate: MSALNativeAuthFlowDelegate
    ) {
        run(delegate: delegate) { controller, state in
            await controller.selectAuthMethod(method, verificationContact: verificationContact, state: state)
        }
    }

    /// Select an authentication method without an explicit verification contact.
    public func selectAuthMethod(_ method: MSALAuthMethod, delegate: MSALNativeAuthFlowDelegate) {
        selectAuthMethod(method, verificationContact: nil, delegate: delegate)
    }

    public override var description: String {
        return "authMethodSelectionRequired"
    }
}

/// Per-state delegate for the ``MSALNativeAuthAuthMethodSelectionRequiredState`` step of a Native Auth V2 flow.
///
/// Conform to this protocol (in addition to the terminal callbacks inherited from
/// ``MSALNativeAuthFlowDelegate``) to handle this state. Conforming is opt-in per state, but the
/// callback is required once you conform.
///
/// - Warning: This API is experimental. It may be changed in the future without notice. Do not use in production applications.
@objc
public protocol MSALNativeAuthAuthMethodSelectionRequiredDelegate: MSALNativeAuthFlowDelegate {

    /// The server requires the user to select an authentication method.
    /// This callback can be raised by sign-in (MFA) and password-reset flows.
    /// Continue with ``MSALNativeAuthAuthMethodSelectionRequiredState/selectAuthMethod(_:verificationContact:delegate:)``.
    /// - Parameters:
    ///   - state: The authentication-method-selection state (available auth methods).
    ///   - scenario: The flow that produced this callback.
    /// - Note: If the app's delegate does not conform to this protocol, then
    ///   ``MSALNativeAuthFlowDelegate/onFlowError(error:scenario:)`` is called with error type `notImplemented`.
    @MainActor func onAuthMethodSelectionRequired(state: MSALNativeAuthAuthMethodSelectionRequiredState, scenario: MSALNativeAuthFlowScenario)
}
