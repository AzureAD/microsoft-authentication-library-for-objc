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
    fileprivate let controller: MSALNativeAuthSignInControlling
    fileprivate let inputValidator: MSALNativeAuthInputValidating

    init(
        controller: MSALNativeAuthSignInControlling,
        inputValidator: MSALNativeAuthInputValidating = MSALNativeAuthInputValidator(),
        flowToken: String) {
        self.controller = controller
        self.inputValidator = inputValidator
        super.init(flowToken: flowToken)
    }
}

/// An object of this type is created when a user is required to supply a verification code to continue a sign in flow.
@objcMembers public class SignInCodeRequiredState: SignInBaseState {

    private let scopes: [String]

    init(
        scopes: [String],
        controller: MSALNativeAuthSignInControlling,
        inputValidator: MSALNativeAuthInputValidating = MSALNativeAuthInputValidator(),
        flowToken: String) {
        self.scopes = scopes
        super.init(controller: controller, inputValidator: inputValidator, flowToken: flowToken)
    }

    /// Requests the server to resend the verfication code to the user.
    /// - Parameters:
    ///   - delegate: Delegate that receives callbacks for the operation.
    ///   - correlationId: UUID to correlate this request with the server for debugging.
    public func resendCode(delegate: SignInResendCodeDelegate, correlationId: UUID? = nil) {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        MSALLogger.log(level: .verbose, context: context, format: "SignIn flow, resend code requested")
        Task {
            await controller.resendCode(credentialToken: flowToken, context: context, scopes: scopes, delegate: delegate)
        }
    }

    /// Submits the code to the server for verification.
    /// - Parameters:
    ///   - code: Verification code that the user supplies.
    ///   - delegate: Delegate that receives callbacks for the operation.
    ///   - correlationId: UUID to correlate this request with the server for debugging.
    public func submitCode(code: String, delegate: SignInVerifyCodeDelegate, correlationId: UUID? = nil) {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        MSALLogger.log(level: .verbose, context: context, format: "SignIn flow, code submitted")
        guard inputValidator.isInputValid(code) else {
            delegate.onSignInVerifyCodeError(error: VerifyCodeError(type: .invalidCode), newState: self)
            MSALLogger.log(level: .error, context: context, format: "SignIn flow, invalid code")
            return
        }
        Task {
            await controller.submitCode(code, credentialToken: flowToken, context: context, scopes: scopes, delegate: delegate)
        }
    }
}

/// An object of this type is created when a user is required to supply a password to continue a sign in flow.
@objcMembers public class SignInPasswordRequiredState: SignInBaseState {

    private let scopes: [String]
    private let username: String

    init(
        scopes: [String],
        username: String,
        controller: MSALNativeAuthSignInControlling,
        inputValidator: MSALNativeAuthInputValidating = MSALNativeAuthInputValidator(),
        flowToken: String) {
        self.scopes = scopes
        self.username = username
        super.init(controller: controller, inputValidator: inputValidator, flowToken: flowToken)
    }

    /// Submits the password to the server for verification.
    /// - Parameters:
    ///   - password: Password that the user supplies.
    ///   - delegate: Delegate that receives callbacks for the operation.
    ///   - correlationId: UUID to correlate this request with the server for debugging.
    public func submitPassword(password: String, delegate: SignInPasswordRequiredDelegate, correlationId: UUID? = nil) {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        MSALLogger.log(level: .info, context: context, format: "SignIn flow, password submitted")

        guard inputValidator.isInputValid(password) else {
            delegate.onSignInPasswordRequiredError(error: PasswordRequiredError(type: .invalidPassword), newState: self)
            MSALLogger.log(level: .error, context: context, format: "SignIn flow, invalid password")
            return
        }
        Task {
            await controller.submitPassword(
                password,
                username: username,
                credentialToken: flowToken,
                context: context,
                scopes: scopes,
                delegate: delegate)
        }
    }
}
