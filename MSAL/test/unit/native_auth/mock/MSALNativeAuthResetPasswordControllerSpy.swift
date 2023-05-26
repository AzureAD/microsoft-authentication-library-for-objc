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

@testable import MSAL
@_implementationOnly import MSAL_Private

class MSALNativeAuthResetPasswordControllerSpy: MSALNativeAuthResetPasswordControlling {
    func resetPassword(parameters: MSAL.MSALNativeAuthResetPasswordStartRequestProviderParameters, delegate: MSAL.ResetPasswordStartDelegate) async {
        <#code#>
    }


    func submitCode(code: String, flowToken: String, context: MSIDRequestContext, delegate: MSAL.ResetPasswordVerifyCodeDelegate) async {
        <#code#>
    }

    func submitPassword(password: String, flowToken: String, context: MSIDRequestContext, delegate: MSAL.ResetPasswordRequiredDelegate) async {
        <#code#>
    }

    private(set) var context: MSIDRequestContext?
    private(set) var resetPasswordCalled = false
    private(set) var resendCodeCalled = false
    private(set) var submitCodeCalled = false
    private(set) var submitPasswordCalled = false

    func resetPassword(parameters: MSAL.MSALNativeAuthResetPasswordStartRequestProviderParameters, delegate: MSAL.ResetPasswordStartDelegate) {
        self.context = parameters.context
        resetPasswordCalled = true
    }

    func resendCode(flowToken: String, context: MSIDRequestContext, delegate: MSAL.ResetPasswordResendCodeDelegate) {
        self.context = context
        resendCodeCalled = true
    }

    func submitCode(code: String, context: MSIDRequestContext, delegate: MSAL.ResetPasswordVerifyCodeDelegate) {
        self.context = context
        submitCodeCalled = true
    }

    func submitPassword(password: String, context: MSIDRequestContext, delegate: MSAL.ResetPasswordRequiredDelegate) {
        self.context = context
        submitPasswordCalled = true
    }
}
