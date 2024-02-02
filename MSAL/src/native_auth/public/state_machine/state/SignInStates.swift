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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation

/// Base class for the SignIn state
@objcMembers public class SignInBaseState: MSALNativeAuthBaseState {
    let controller: MSALNativeAuthSignInControlling
    let inputValidator: MSALNativeAuthInputValidating

    init(
        controller: MSALNativeAuthSignInControlling,
        inputValidator: MSALNativeAuthInputValidating = MSALNativeAuthInputValidator(),
        continuationToken: String,
        correlationId: UUID) {
        self.controller = controller
        self.inputValidator = inputValidator
        super.init(continuationToken: continuationToken, correlationId: correlationId)
    }
}

/// An object of this type is created when a user is required to supply a verification code to continue a sign in flow.
@objcMembers public class SignInCodeRequiredState: SignInBaseState {

    let scopes: [String]

    init(
        scopes: [String],
        controller: MSALNativeAuthSignInControlling,
        inputValidator: MSALNativeAuthInputValidating = MSALNativeAuthInputValidator(),
        continuationToken: String,
        correlationId: UUID) {
        self.scopes = scopes
        super.init(controller: controller, inputValidator: inputValidator, continuationToken: continuationToken, correlationId: correlationId)
    }

    /// Requests the server to resend the verification code to the user.
    /// - Parameter delegate: Delegate that receives callbacks for the operation.
    public func resendCode(delegate: SignInResendCodeDelegate) {
        Task {
            let controllerResponse = await resendCodeInternal()
            let delegateDispatcher = SignInResendCodeDelegateDispatcher(delegate: delegate, telemetryUpdate: controllerResponse.telemetryUpdate)

            switch controllerResponse.result {
            case .codeRequired(let newState, let sentTo, let channelTargetType, let codeLength):
                await delegateDispatcher.dispatchSignInResendCodeCodeRequired(
                    newState: newState,
                    sentTo: sentTo,
                    channelTargetType: channelTargetType,
                    codeLength: codeLength,
                    correlationId: controllerResponse.correlationId
                )
            case .error(let error, let newState):
                await delegate.onSignInResendCodeError(error: error, newState: newState)
            }
        }
    }

    /// Submits the code to the server for verification.
    /// - Parameters:
    ///   - code: Verification code that the user supplies.
    ///   - delegate: Delegate that receives callbacks for the operation.
    public func submitCode(code: String, delegate: SignInVerifyCodeDelegate) {
        Task {
            let controllerResponse = await submitCodeInternal(code: code)
            let delegateDispatcher = SignInVerifyCodeDelegateDispatcher(delegate: delegate, telemetryUpdate: controllerResponse.telemetryUpdate)

            switch controllerResponse.result {
            case .completed(let accountResult):
                await delegateDispatcher.dispatchSignInCompleted(result: accountResult, correlationId: controllerResponse.correlationId)
            case .error(let error, let newState):
                await delegate.onSignInVerifyCodeError(error: error, newState: newState)
            }
        }
    }
}

/// An object of this type is created when a user is required to supply a password to continue a sign in flow.
@objcMembers public class SignInPasswordRequiredState: SignInBaseState {

    let scopes: [String]
    let username: String

    init(
        scopes: [String],
        username: String,
        controller: MSALNativeAuthSignInControlling,
        inputValidator: MSALNativeAuthInputValidating = MSALNativeAuthInputValidator(),
        continuationToken: String,
        correlationId: UUID) {
        self.scopes = scopes
        self.username = username
        super.init(controller: controller, inputValidator: inputValidator, continuationToken: continuationToken, correlationId: correlationId)
    }

    /// Submits the password to the server for verification.
    /// - Parameters:
    ///   - password: Password that the user supplied.
    ///   - delegate: Delegate that receives callbacks for the operation.
    public func submitPassword(password: String, delegate: SignInPasswordRequiredDelegate) {
        Task {
            let controllerResponse = await submitPasswordInternal(password: password)
            let delegateDispatcher = SignInPasswordRequiredDelegateDispatcher(delegate: delegate, telemetryUpdate: controllerResponse.telemetryUpdate)

            switch controllerResponse.result {
            case .completed(let accountResult):
                await delegateDispatcher.dispatchSignInCompleted(result: accountResult, correlationId: controllerResponse.correlationId)
            case .error(let error, let newState):
                await delegate.onSignInPasswordRequiredError(error: error, newState: newState)
            }
        }
    }
}
