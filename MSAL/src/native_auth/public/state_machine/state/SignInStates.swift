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
public class SignInBaseState: MSALNativeAuthBaseState {
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

@objcMembers
public class SignInCodeSentState: SignInBaseState {

    public func resendCode(delegate: SignInResendCodeDelegate, correlationId: UUID? = nil) {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        MSALLogger.log(level: .verbose, context: context, format: "SignIn flow, resend code requested")
        controller.resendCode(credentialToken: flowToken, context: context, delegate: delegate)
    }

    public func submitCode(code: String, delegate: SignInVerifyCodeDelegate, correlationId: UUID? = nil) {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        MSALLogger.log(level: .verbose, context: context, format: "SignIn flow, code submitted")
        guard inputValidator.isInputValid(code) else {
            delegate.onSignInVerifyCodeError(error: VerifyCodeError(type: .invalidCode), newState: self)
            MSALLogger.log(level: .error, context: context, format: "SignIn flow, invalid code")
            return
        }
        controller.submitCode(code, credentialToken: flowToken, context: context, delegate: delegate)
    }
}
