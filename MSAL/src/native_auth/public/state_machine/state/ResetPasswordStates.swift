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

/// Base class for the ResetPassword state
@objcMembers
public class ResetPasswordBaseState: MSALNativeAuthBaseState {
    let controller: MSALNativeAuthResetPasswordControlling
    let username: String
    let inputValidator: MSALNativeAuthInputValidating

    init(
        controller: MSALNativeAuthResetPasswordControlling,
        username: String,
        continuationToken: String,
        inputValidator: MSALNativeAuthInputValidating = MSALNativeAuthInputValidator(),
        correlationId: UUID
    ) {
        self.controller = controller
        self.username = username
        self.inputValidator = inputValidator
        super.init(continuationToken: continuationToken, correlationId: correlationId)
    }
}

/// An object of this type is created when a user is required to supply a verification code to continue a reset password flow.
@objcMembers public class ResetPasswordCodeRequiredState: ResetPasswordBaseState {
    /// Requests the server to resend the verification code to the user.
    /// - Parameter delegate: Delegate that receives callbacks for the operation.
    public func resendCode(delegate: ResetPasswordResendCodeDelegate) {
        Task {
            let controllerResponse = await resendCodeInternal()
            let delegateDispatcher = ResetPasswordResendCodeDelegateDispatcher(
                delegate: delegate,
                telemetryUpdate: controllerResponse.telemetryUpdate
            )

            switch controllerResponse.result {
            case .codeRequired(let newState, let sentTo, let channelTargetType, let codeLength):
                await delegateDispatcher.dispatchResetPasswordResendCodeRequired(
                    newState: newState,
                    sentTo: sentTo,
                    channelTargetType: channelTargetType,
                    codeLength: codeLength,
                    correlationId: controllerResponse.correlationId
                )
            case .error(let error, let newState):
                await delegate.onResetPasswordResendCodeError(error: error, newState: newState)
            }
        }
    }

    /// Submits the code to the server for verification.
    /// - Parameters:
    ///   - code: Verification code that the user supplied.
    ///   - delegate: Delegate that receives callbacks for the operation.
    public func submitCode(code: String, delegate: ResetPasswordVerifyCodeDelegate) {
        Task {
            let controllerResponse = await submitCodeInternal(code: code)
            let delegateDispatcher = ResetPasswordVerifyCodeDelegateDispatcher(
                delegate: delegate,
                telemetryUpdate: controllerResponse.telemetryUpdate
            )

            switch controllerResponse.result {
            case .passwordRequired(let newState):
                await delegateDispatcher.dispatchPasswordRequired(newState: newState, correlationId: controllerResponse.correlationId)
            case .error(let error, let newState):
                await delegate.onResetPasswordVerifyCodeError(error: error, newState: newState)
            }
        }
    }
}

/// An object of this type is created when a user is required to supply a password to continue a reset password flow.
@objcMembers public class ResetPasswordRequiredState: ResetPasswordBaseState {
    /// Submits the password to the server for verification.
    /// - Parameters:
    ///   - password: Password that the user supplied.
    ///   - delegate: Delegate that receives callbacks for the operation.
    public func submitPassword(password: String, delegate: ResetPasswordRequiredDelegate) {
        Task {
            let controllerResponse = await submitPasswordInternal(password: password)
            let delegateDispatcher = ResetPasswordRequiredDelegateDispatcher(delegate: delegate, telemetryUpdate: controllerResponse.telemetryUpdate)

            switch controllerResponse.result {
            case .completed(let newState):
                await delegateDispatcher.dispatchResetPasswordCompleted(newState: newState, correlationId: controllerResponse.correlationId)
            case .error(let error, let newState):
                await delegate.onResetPasswordRequiredError(error: error, newState: newState)
            }
        }
    }
}
