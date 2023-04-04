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
public class SignInCodeSentState: MSALNativeAuthBaseState {

    public func resendCode(delegate: ResendCodeSignInDelegate, correlationId: UUID? = nil) {
        delegate.onCodeSent(state: self, displayName: nil)
    }

    public func submitCode(code: String, delegate: VerifyCodeSignInDelegate, correlationId: UUID? = nil) {
        switch code {
        case "0000": delegate.onError(error: VerifyCodeError(type: .invalidCode), state: self)
        case "2222": delegate.onError(error: VerifyCodeError(type: .generalError), state: self)
        case "3333": delegate.onError(error: VerifyCodeError(type: .tooManyCodesRequested), state: self)
        case "4444": delegate.verifyCodeFlowInterrupted(reason: .redirect)
        default: delegate.completed(result:
                                        MSALNativeAuthUserAccount(
                                            email: "email@contoso.com",
                                            accessToken: "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsIng1dCI6Imk2bEdrM0ZaenhSY1ViMkMzbkVRN3N5SEpsWSIsImtpZCI6Imk2bEdrM0ZaenhSY1ViMkMzbkVRN3N5SEpsWSJ9"))
        }
    }
}
