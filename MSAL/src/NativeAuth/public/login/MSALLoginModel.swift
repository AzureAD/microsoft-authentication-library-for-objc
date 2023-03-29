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
public class SignInStartError: MSALNativeError {
    let type: SignInStartErrorType

    init(type: SignInStartErrorType, message: String? = nil) {
        self.type = type
        super.init(message: message)
    }
}

@objc
public enum SignInStartErrorType: Int {
    case userNotFound
    case passwordInvalid
    case generalError
    case invalidAuthenticationType
}

//TODO: this is the almost same as SignUpStart
public protocol SignInStartDelegate {
    func onOOBSent(flow: OOBSentFlowSignIn)
    func onError(error: SignInStartError)
    func onRedirect()
}

//TODO: reuse verify code from signUp
public protocol VerifyCodeSignInDelegate {
    //TODO: this need to return a MSALNativeAuthAccount
    func completed(result: MSALNativeAuthenticationResult)
    //TODO: do we need the state for the error? can the ext dev use the existing flow instance?
    func onError(error: VerifyCodeError, state: OOBSentFlowSignIn?)
    //TODO: do we need this method for verifyCode?
    func onRedirect()
}

//TODO: create class to share code with SignUp
@objcMembers
public class OOBSentFlowSignIn {
    private let credentialToken: String

    init(credentialToken: String) {
        self.credentialToken = credentialToken
    }

    // TODO: we need a delegate to manage unexpected errors, maybe we need a new delegate to manage less errors than signUp and not redirect
    public func resendCode(delegate: SignInStartDelegate, correlationId: UUID? = nil) {
        delegate.onOOBSent(flow: self)
    }

    public func verifyCode(otp: String, flow: VerifyCodeSignInDelegate, correlationId: UUID? = nil) {
        flow.completed(result: MSALNativeAuthenticationResult(accessToken: "accessToken", idToken: "idToken", scopes: [], expiresOn: Date(), tenantId: "tenantId"))
    }
}
