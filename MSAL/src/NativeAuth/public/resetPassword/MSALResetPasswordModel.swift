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
public class ResetPasswordStartError: MSALNativeError {
    let type: ResetPasswordStartErrorType

    init(type: ResetPasswordStartErrorType, message: String? = nil) {
        self.type = type
        super.init(message: message)
    }
}

@objc
public enum ResetPasswordStartErrorType: Int {
    case userNotFound
    case generalError
    case userDoesNotHavePassword
}

//TODO: this is the almost same as SignUpStart
public protocol ResetPasswordStartDelegate {
    func onOOBSent(flow: OOBSentResetPasswordFlow)
    func onError(error: SignInStartError)
    func onRedirect()
}

//TODO: reuse verify code from signUp
public protocol VerifyCodeResetPasswordDelegate {
    //TODO: this need to return a MSALNativeAuthAccount
    func passwordRequired(flow: PasswordRequiredResetPasswordFlow)
    //TODO: do we need the state for the error? can the ext dev use the existing flow instance?
    func onError(error: ResetPasswordStartError, state: VerifyCodeResetPasswordDelegate?)
    //TODO: do we need this method for verifyCode?
    func onRedirect()
}

@objcMembers
public class PasswordRequiredResetPasswordFlow {
    private let credentialToken: String

    init(credentialToken: String) {
        self.credentialToken = credentialToken
    }

    public func setPassword(password: String, callback: PasswordRequiredResetPasswordDelegate, correlationId: UUID? = nil) {
        
    }
}

public protocol PasswordRequiredResetPasswordDelegate {
    func completed()
    //TODO: do we need the state for the error? can the ext dev use the existing flow instance?
    func onError(error: PasswordRequiredError, state: PasswordRequiredResetPasswordFlow?)
    // TODO: exception
    func onRedirect()
}


//TODO: create class to share code with SignUp
@objcMembers
public class OOBSentResetPasswordFlow {
    private let credentialToken: String

    init(credentialToken: String) {
        self.credentialToken = credentialToken
    }

    // TODO: we need a delegate to manage unexpected errors, maybe we need a new delegate to manage less errors than signUp and not redirect
    public func resendCode(delegate: ResetPasswordStartDelegate, correlationId: UUID? = nil) {
        delegate.onOOBSent(flow: self)
    }

    public func verifyCode(otp: String, flow: VerifyCodeResetPasswordDelegate, correlationId: UUID? = nil) {
        flow.passwordRequired(flow: PasswordRequiredResetPasswordFlow(credentialToken: "credentialToken"))
    }
}
