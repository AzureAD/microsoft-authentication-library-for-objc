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

@objcMembers public class SignInBaseState: MSALNativeAuthBaseState {
    let controller: MSALNativeAuthSignInControlling
    let inputValidator: MSALNativeAuthInputValidating

    init(
        controller: MSALNativeAuthSignInControlling,
        inputValidator: MSALNativeAuthInputValidating = MSALNativeAuthInputValidator(),
        continuationToken: String) {
        self.controller = controller
        self.inputValidator = inputValidator
        super.init(continuationToken: continuationToken)
    }
}

/// An object of this type is created when a user is required to supply a verification code to continue a sign in flow.
@objcMembers public class SignInCodeRequiredState: SignInBaseState {

    let scopes: [String]

    init(
        scopes: [String],
        controller: MSALNativeAuthSignInControlling,
        inputValidator: MSALNativeAuthInputValidating = MSALNativeAuthInputValidator(),
        continuationToken: String) {
        self.scopes = scopes
        super.init(controller: controller, inputValidator: inputValidator, continuationToken: continuationToken)
    }

    /// Requests the server to resend the verification code to the user.
    /// - Parameters:
    ///   - correlationId: Optional. UUID to correlate this request with the server for debugging.
    ///   - delegate: Delegate that receives callbacks for the operation.
    public func resendCode(correlationId: UUID? = nil, delegate: SignInResendCodeDelegate) {
        Task {
            let result = await resendCodeInternal(correlationId: correlationId)

            switch result {
            case .codeRequired(let newState, let sentTo, let channelTargetType, let codeLength):
                await delegate.onSignInResendCodeCodeRequired(
                    newState: newState,
                    sentTo: sentTo,
                    channelTargetType: channelTargetType,
                    codeLength: codeLength
                )
            case .error(let error, let newState):
                await delegate.onSignInResendCodeError(error: error, newState: newState)
            }
        }
    }

    /// Submits the code to the server for verification.
    /// - Parameters:
    ///   - code: Verification code that the user supplies.
    ///   - correlationId: Optional. UUID to correlate this request with the server for debugging.
    ///   - delegate: Delegate that receives callbacks for the operation.
    public func submitCode(code: String, correlationId: UUID? = nil, delegate: SignInVerifyCodeDelegate) {
        Task {
            let result = await submitCodeInternal(code: code, correlationId: correlationId)

            switch result {
            case .completed(let accountResult):
                await delegate.onSignInCompleted(result: accountResult)
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
        continuationToken: String) {
        self.scopes = scopes
        self.username = username
        super.init(controller: controller, inputValidator: inputValidator, continuationToken: continuationToken)
    }

    /// Submits the password to the server for verification.
    /// - Parameters:
    ///   - password: Password that the user supplied.
    ///   - correlationId: Optional. UUID to correlate this request with the server for debugging.
    ///   - delegate: Delegate that receives callbacks for the operation.
    public func submitPassword(password: String, correlationId: UUID? = nil, delegate: SignInPasswordRequiredDelegate) {
        Task {
            let result = await submitPasswordInternal(password: password, correlationId: correlationId)

            switch result {
            case .completed(let accountResult):
                await delegate.onSignInCompleted(result: accountResult)
            case .error(let error, let newState):
                await delegate.onSignInPasswordRequiredError(error: error, newState: newState)
            }
        }
    }
}
