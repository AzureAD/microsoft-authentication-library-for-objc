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

/// Opaque handle that lets an app continue a Native Auth V2 (server-driven) flow.
///
/// The SDK hands a ``MSALNativeAuthFlowState`` to the app via
/// ``MSALNativeAuthFlowDelegate/onActionRequired(action:flowState:)``. The app then
/// calls the method matching the requested ``MSALNativeAuthAction`` to advance the flow.
public class MSALNativeAuthFlowState: NSObject {

    let continuation: MSALNativeAuthV2ContinuationState
    private let controller: MSALNativeAuthV2FlowControlling
    private let dispatcher = MSALNativeAuthFlowResponseDispatcher()

    init(continuation: MSALNativeAuthV2ContinuationState, controller: MSALNativeAuthV2FlowControlling) {
        self.continuation = continuation
        self.controller = controller
        super.init()
    }

    /// Submit a one-time verification code.
    public func submitCode(_ code: String, delegate: MSALNativeAuthFlowDelegate) {
        run(delegate: delegate) { controller in
            await controller.submitCode(code, state: self)
        }
    }

    /// Submit a password (sign in / sign up).
    public func submitPassword(_ password: String, delegate: MSALNativeAuthFlowDelegate) {
        run(delegate: delegate) { controller in
            await controller.submitPassword(password, state: self)
        }
    }

    /// Submit a new password (self-service password reset).
    public func submitNewPassword(_ password: String, delegate: MSALNativeAuthFlowDelegate) {
        run(delegate: delegate) { controller in
            await controller.submitNewPassword(password, state: self)
        }
    }

    /// Submit user attributes (sign up).
    public func submitAttributes(_ attributes: [String: Any], delegate: MSALNativeAuthFlowDelegate) {
        run(delegate: delegate) { controller in
            await controller.submitAttributes(attributes, state: self)
        }
    }

    /// Select an authentication method for MFA or strong-auth registration.
    public func selectAuthMethod(
        _ method: MSALAuthMethod,
        verificationContact: String? = nil,
        delegate: MSALNativeAuthFlowDelegate
    ) {
        run(delegate: delegate) { controller in
            await controller.selectAuthMethod(method, verificationContact: verificationContact, state: self)
        }
    }

    /// Submit an MFA / strong-auth challenge response.
    public func submitChallenge(_ challenge: String, delegate: MSALNativeAuthFlowDelegate) {
        run(delegate: delegate) { controller in
            await controller.submitChallenge(challenge, state: self)
        }
    }

    /// Request the server to resend the one-time code.
    public func resendCode(delegate: MSALNativeAuthFlowDelegate) {
        run(delegate: delegate) { controller in
            await controller.resendCode(state: self)
        }
    }

    private func run(
        delegate: MSALNativeAuthFlowDelegate,
        operation: @escaping (MSALNativeAuthV2FlowControlling) async -> MSALNativeAuthV2FlowControllerResponse
    ) {
        Task {
            let response = await operation(controller)
            await dispatcher.dispatch(response, delegate: delegate)
        }
    }
}
