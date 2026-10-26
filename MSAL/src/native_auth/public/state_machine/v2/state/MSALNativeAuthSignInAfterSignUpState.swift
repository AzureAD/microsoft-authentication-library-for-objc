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

/// The sign-up completed. Sign the new account in by calling
/// ``signIn(parameters:delegate:)`` with the scopes to request on the access token.
///
/// - Warning: This API is experimental. It may be changed in the future without notice. Do not use in production applications.
@objcMembers
public class MSALNativeAuthSignInAfterSignUpState: MSALNativeAuthState {

    /// Sign in after a successful sign up.
    public func signIn(parameters: MSALNativeAuthSignInAfterSignUpParameters, delegate: MSALNativeAuthFlowDelegate) {
        run(delegate: delegate) { controller, state in
            await controller.signInAfterSignUp(
                scopes: parameters.scopes,
                claimsRequestJson: parameters.claimsRequest?.jsonString(),
                state: state
            )
        }
    }

    public override var description: String {
        return "signInAfterSignUp"
    }
}

/// Per-state delegate for the ``MSALNativeAuthSignInAfterSignUpState`` step of a Native Auth V2 flow.
///
/// Conform to this protocol (in addition to the terminal callbacks inherited from
/// ``MSALNativeAuthFlowDelegate``) to handle this state. Conforming is opt-in per state, but the
/// callback is required once you conform.
///
/// - Warning: This API is experimental. It may be changed in the future without notice. Do not use in production applications.
@objc
public protocol MSALNativeAuthSignInAfterSignUpRequiredDelegate: MSALNativeAuthFlowDelegate {

    /// The sign up completed and the new account can now be signed in.
    /// Continue with ``MSALNativeAuthSignInAfterSignUpState/signIn(parameters:delegate:)``.
    /// - Parameters:
    ///   - state: The sign-in-after-sign-up state.
    ///   - scenario: The flow that produced this callback.
    /// - Note: If the app's delegate does not conform to this protocol, then
    ///   ``MSALNativeAuthFlowDelegate/onFlowError(error:scenario:)`` is called with error type `notImplemented`.
    @MainActor func onSignInAfterSignUpRequired(state: MSALNativeAuthSignInAfterSignUpState, scenario: MSALNativeAuthFlowScenario)
}
