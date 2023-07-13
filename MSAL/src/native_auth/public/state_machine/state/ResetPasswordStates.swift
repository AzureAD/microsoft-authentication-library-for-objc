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

@objcMembers
public class ResetPasswordBaseState: MSALNativeAuthBaseState {
    fileprivate let controller: MSALNativeAuthResetPasswordControlling
    fileprivate let inputValidator: MSALNativeAuthInputValidating

    init(
        controller: MSALNativeAuthResetPasswordControlling,
        flowToken: String,
        inputValidator: MSALNativeAuthInputValidating = MSALNativeAuthInputValidator()
    ) {
        self.controller = controller
        self.inputValidator = inputValidator
        super.init(flowToken: flowToken)
    }
}

/// An object of this type is created when a user is required to supply a verification code to continue a reset password flow.
@objcMembers public class ResetPasswordCodeRequiredState: ResetPasswordBaseState {
    /// Requests the server to resend the verfication code to the user.
    /// - Parameters:
    ///   - delegate: Delegate that receives callbacks for the operation.
    ///   - correlationId: UUID to correlate this request with the server for debugging.
    public func resendCode(delegate: ResetPasswordResendCodeDelegate, correlationId: UUID? = nil) {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)

        Task {
            await controller.resendCode(passwordResetToken: flowToken, context: context, delegate: delegate)
        }
    }

    /// Submits the code to the server for verification.
    /// - Parameters:
    ///   - code: Verification code that the user supplied.
    ///   - delegate: Delegate that receives callbacks for the operation.
    ///   - correlationId: UUID to correlate this request with the server for debugging.
    public func submitCode(code: String, delegate: ResetPasswordVerifyCodeDelegate, correlationId: UUID? = nil) {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        guard inputValidator.isInputValid(code) else {
            MSALLogger.log(level: .error, context: context, format: "ResetPassword flow, invalid code")
            Task {
                await delegate.onResetPasswordVerifyCodeError(error: VerifyCodeError(type: .invalidCode), newState: self)
            }
            return
        }
        Task {
            await controller.submitCode(code: code, passwordResetToken: flowToken, context: context, delegate: delegate)
        }
    }
}

/// An object of this type is created when a user is required to supply a password to continue a reset password flow.
@objcMembers public class ResetPasswordRequiredState: ResetPasswordBaseState {
    /// Submits the password to the server for verification.
    /// - Parameters:
    ///   - password: Password that the user supplied.
    ///   - delegate: Delegate that receives callbacks for the operation.
    ///   - correlationId: UUID to correlate this request with the server for debugging.
    public func submitPassword(password: String, delegate: ResetPasswordRequiredDelegate, correlationId: UUID? = nil) {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)

        guard inputValidator.isInputValid(password) else {
            MSALLogger.log(level: .error, context: context, format: "ResetPassword flow, invalid password")
            Task {
                await delegate.onResetPasswordRequiredError(error: PasswordRequiredError(type: .invalidPassword), newState: self)
            }
            return
        }
        Task {
            await controller.submitPassword(password: password, passwordSubmitToken: flowToken, context: context, delegate: delegate)
        }
    }
}
