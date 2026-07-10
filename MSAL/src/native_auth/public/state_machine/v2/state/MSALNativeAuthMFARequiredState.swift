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

/// The server requires multi-factor authentication; the user must select an auth method.
/// Continue with ``selectAuthMethod(_:verificationContact:delegate:)``.
@objcMembers
public class MSALNativeAuthMFARequiredState: MSALNativeAuthState {

    /// The authentication methods available for selection.
    public let authMethods: [MSALAuthMethod]

    public init(authMethods: [MSALAuthMethod]) {
        self.authMethods = authMethods
        super.init()
    }

    /// Select an authentication method for MFA.
    public func selectAuthMethod(
        _ method: MSALAuthMethod,
        verificationContact: String?,
        delegate: MSALNativeAuthFlowDelegate
    ) {
        Task { @MainActor in
            delegate.onFlowError(
                error: MSALNativeAuthFlowError(type: .notImplemented, correlationId: UUID()),
                scenario: .unknown
            )
        }
    }

    /// Select an authentication method for MFA, without an explicit verification contact.
    public func selectAuthMethod(_ method: MSALAuthMethod, delegate: MSALNativeAuthFlowDelegate) {
        selectAuthMethod(method, verificationContact: nil, delegate: delegate)
    }

    public override var description: String {
        return "mfaRequired"
    }
}

/// Per-state delegate for the ``MSALNativeAuthMFARequiredState`` step of a Native Auth V2 flow.
///
/// Conform to this protocol (in addition to the terminal callbacks inherited from
/// ``MSALNativeAuthFlowDelegate``) to handle this state. Conforming is opt-in per state, but the
/// callback is required once you conform.
@objc
public protocol MSALNativeAuthMFARequiredDelegate: MSALNativeAuthFlowDelegate {

    /// The server requires multi-factor authentication; the user must select an auth method.
    /// Continue with ``MSALNativeAuthMFARequiredState/selectAuthMethod(_:verificationContact:delegate:)``.
    /// - Parameters:
    ///   - state: The MFA-required state (available auth methods).
    ///   - scenario: The flow (sign in / sign up / password reset) that produced this callback.
    /// - Note: If the app's delegate does not conform to this protocol, then
    ///   ``MSALNativeAuthFlowDelegate/onFlowError(error:scenario:)`` is called with error type `notImplemented`.
    @MainActor func onMFARequired(state: MSALNativeAuthMFARequiredState, scenario: MSALNativeAuthFlowScenario)
}
