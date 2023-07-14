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
public class SignUpBaseState: MSALNativeAuthBaseState {
    fileprivate let controller: MSALNativeAuthSignUpControlling
    fileprivate let inputValidator: MSALNativeAuthInputValidating

    init(
        controller: MSALNativeAuthSignUpControlling,
        flowToken: String,
        inputValidator: MSALNativeAuthInputValidating = MSALNativeAuthInputValidator()
    ) {
        self.controller = controller
        self.inputValidator = inputValidator
        super.init(flowToken: flowToken)
    }
}

/// An object of this type is created when a user is required to supply a verification code to continue a sign up flow.
@objcMembers public class SignUpCodeRequiredState: SignUpBaseState {
    /// Requests the server to resend the verfication code to the user.
    /// - Parameters:
    ///   - delegate: Delegate that receives callbacks for the operation.
    ///   - correlationId: Optional. UUID to correlate this request with the server for debugging.
    public func resendCode(delegate: SignUpResendCodeDelegate, correlationId: UUID? = nil) {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        Task {
            await controller.resendCode(context: context, signUpToken: flowToken, delegate: delegate)
        }
    }

    /// Submits the code to the server for verification.
    /// - Parameters:
    ///   - code: Verification code that the user supplies.
    ///   - delegate: Delegate that receives callbacks for the operation.
    ///   - correlationId: Optional. UUID to correlate this request with the server for debugging.
    public func submitCode(code: String, delegate: SignUpVerifyCodeDelegate, correlationId: UUID? = nil) {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)

        guard inputValidator.isInputValid(code) else {
            delegate.onSignUpVerifyCodeError(error: VerifyCodeError(type: .invalidCode), newState: self)
            MSALLogger.log(level: .error, context: context, format: "SignUp flow, invalid code")
            return
        }

        Task {
            await controller.submitCode(code, signUpToken: flowToken, context: context, delegate: delegate)
        }
    }
}

/// An object of this type is created when a user is required to supply a password to continue a sign up flow.
@objcMembers public class SignUpPasswordRequiredState: SignUpBaseState {

    /// Submits the password to the server for verification.
    /// - Parameters:
    ///   - password: Password that the user supplied.
    ///   - delegate: Delegate that receives callbacks for the operation.
    ///   - correlationId: Optional. UUID to correlate this request with the server for debugging.
    public func submitPassword(password: String, delegate: SignUpPasswordRequiredDelegate, correlationId: UUID? = nil) {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)

        guard inputValidator.isInputValid(password) else {
            delegate.onSignUpPasswordRequiredError(error: PasswordRequiredError(type: .invalidPassword), newState: self)
            MSALLogger.log(level: .error, context: context, format: "SignUp flow, invalid password")
            return
        }

        Task {
            await controller.submitPassword(password, signUpToken: flowToken, context: context, delegate: delegate)
        }
    }
}

/// An object of this type is created when a user is required to supply attributes to continue a sign up flow.
@objcMembers public class SignUpAttributesRequiredState: SignUpBaseState {
    /// Submits the attributes to the server for verification.
    /// - Parameters:
    ///   - attributes: Dictionary of attributes that the user supplied.
    ///   - delegate: Delegate that receives callbacks for the operation.
    ///   - correlationId: Optional. UUID to correlate this request with the server for debugging.
    public func submitAttributes(
        attributes: [String: Any],
        delegate: SignUpAttributesRequiredDelegate,
        correlationId: UUID? = nil
    ) {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)

        guard inputValidator.isInputValid(attributes) else {
            delegate.onSignUpAttributesRequiredError(error: AttributesRequiredError(type: .invalidAttributes), newState: self)
            MSALLogger.log(level: .error, context: context, format: "SignUp flow, invalid attributes")
            return
        }

        Task {
            await controller.submitAttributes(attributes, signUpToken: flowToken, context: context, delegate: delegate)
        }
    }
}
