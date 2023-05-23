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
    fileprivate weak var controller: MSALNativeAuthSignUpControlling?

    init(controller: MSALNativeAuthSignUpControlling, flowToken: String) {
        self.controller = controller
        super.init(flowToken: flowToken)
    }
}

@objcMembers
public class SignUpCodeRequiredState: SignUpBaseState {

    public func resendCode(delegate: SignUpResendCodeDelegate, correlationId: UUID? = nil) {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)

        guard let controller = controller else {
            MSALLogger.log(level: .error, context: context, format: "Error - Controller is nil")
            DispatchQueue.main.async {
                delegate.onSignUpResendCodeError(error: .init(type: .generalError), newState: nil)
            }
            return
        }

        controller.resendCode(context: context, delegate: delegate)
    }

    public func submitCode(code: String, delegate: SignUpVerifyCodeDelegate, correlationId: UUID? = nil) {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)

        guard let controller = controller else {
            MSALLogger.log(level: .error, context: context, format: "Error - Controller is nil")
            DispatchQueue.main.async {
                delegate.onSignUpVerifyCodeError(error: .init(type: .generalError), newState: nil)
            }
            return
        }

        controller.submitCode(code, context: context, delegate: delegate)
    }
}

@objcMembers
public class SignUpPasswordRequiredState: SignUpBaseState {

    public func submitPassword(password: String, delegate: SignUpPasswordRequiredDelegate, correlationId: UUID? = nil) {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)

        guard let controller = controller else {
            MSALLogger.log(level: .error, context: context, format: "Error - Controller is nil")
            DispatchQueue.main.async {
                delegate.onSignUpPasswordRequiredError(error: .init(type: .generalError), newState: nil)
            }
            return
        }

        controller.submitPassword(password, context: context, delegate: delegate)
    }
}

@objcMembers
public class SignUpAttributesRequiredState: SignUpBaseState {

    public func submitAttributes(
        attributes: [String: Any],
        delegate: SignUpAttributesRequiredDelegate,
        correlationId: UUID? = nil
    ) {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)

        guard let controller = controller else {
            MSALLogger.log(level: .error, context: context, format: "Error - Controller is nil")
            DispatchQueue.main.async {
                delegate.onSignUpAttributesRequiredError(error: .init(type: .generalError), newState: nil)
            }
            return
        }

        controller.submitAttributes(attributes, context: context, delegate: delegate)
    }
}
