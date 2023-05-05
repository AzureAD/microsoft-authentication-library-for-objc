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

class SignUpResendCodeDelegateSpy: SignUpResendCodeDelegate {
    private(set) var error: ResendCodeError?
    private(set) var newState: SignUpCodeSentState?
    private(set) var displayName: String?
    private(set) var codeLength: Int?

    func onSignUpResendCodeError(error: MSAL.ResendCodeError, newState: MSAL.SignUpCodeSentState?) {
        self.error = error
        self.newState = newState
    }

    func onSignUpResendCodeSent(newState: MSAL.SignUpCodeSentState, displayName: String, codeLength: Int) {
        self.newState = newState
        self.displayName = displayName
        self.codeLength = codeLength
    }
}

class SignUpVerifyCodeDelegateSpy: SignUpVerifyCodeDelegate {
    private(set) var error: VerifyCodeError?
    private(set) var newCodeSentState: SignUpCodeSentState?
    private(set) var newAttributesRequiredState: SignUpAttributesRequiredState?
    private(set) var newPasswordRequiredState: SignUpPasswordRequiredState?
    private(set) var signUpCompletedCalled = false

    func onSignUpVerifyCodeError(error: MSAL.VerifyCodeError, newState: MSAL.SignUpCodeSentState?) {
        self.error = error
        newCodeSentState = newState
    }

    func onSignUpAttributesRequired(newState: MSAL.SignUpAttributesRequiredState) {
        newAttributesRequiredState = newState
    }

    func onPasswordRequired(newState: MSAL.SignUpPasswordRequiredState) {
        newPasswordRequiredState = newState
    }

    func onSignUpCompleted() {
        signUpCompletedCalled = true
    }
}

class SignUpPasswordRequiredDelegateSpy: SignUpPasswordRequiredDelegate {
    private(set) var error: PasswordRequiredError?
    private(set) var newPasswordRequiredState: SignUpPasswordRequiredState?
    private(set) var newAttributesRequiredState: SignUpAttributesRequiredState?
    private(set) var signUpCompletedCalled = false

    func onSignUpPasswordRequiredError(error: MSAL.PasswordRequiredError, newState: MSAL.SignUpPasswordRequiredState?) {
        self.error = error
        newPasswordRequiredState = newState
    }

    func onSignUpAttributesRequired(newState: MSAL.SignUpAttributesRequiredState) {
        newAttributesRequiredState = newState
    }

    func onSignUpCompleted() {
        signUpCompletedCalled = true
    }
}

class SignUpAttributesRequiredDelegateSpy: SignUpAttributesRequiredDelegate {
    private(set) var error: AttributesRequiredError?
    private(set) var newState: SignUpAttributesRequiredState?
    private(set) var signUpCompletedCalled = false

    func onSignUpAttributesRequiredError(error: MSAL.AttributesRequiredError, newState: MSAL.SignUpAttributesRequiredState?) {
        self.error = error
        self.newState = newState
    }

    func onSignUpCompleted() {
        self.signUpCompletedCalled = true
    }
}
