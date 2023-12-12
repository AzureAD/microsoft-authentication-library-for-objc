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
import XCTest

class MSALNativeAuthSignInControllerMock: MSALNativeAuthSignInControlling {

    private(set) var username: String?
    private(set) var slt: String?
    var expectation: XCTestExpectation?

    var signInPasswordStartResult: MSALNativeAuthSignInControlling.SignInPasswordControllerResponse!
    var signInStartResult: MSALNativeAuthSignInControlling.SignInCodeControllerResponse!
    var signInSLTResult: SignInAfterPreviousFlowControllerResponse!
    var submitCodeResult: SignInSubmitCodeControllerResponse!
    var submitPasswordResult: SignInSubmitPasswordControllerResponse!
    var resendCodeResult: SignInResendCodeControllerResponse!

    func signIn(params: MSAL.MSALNativeAuthSignInWithPasswordParameters) async -> MSALNativeAuthSignInControlling.SignInPasswordControllerResponse {
        return signInPasswordStartResult
    }

    func signIn(params: MSAL.MSALNativeAuthSignInWithCodeParameters) async -> MSALNativeAuthSignInControlling.SignInCodeControllerResponse {
        return signInStartResult
    }

    func signIn(username: String, slt: String?, scopes: [String]?, context: MSAL.MSALNativeAuthRequestContext) async -> SignInAfterPreviousFlowControllerResponse {
        self.username = username
        self.slt = slt
        expectation?.fulfill()

        return signInSLTResult
    }

    func submitCode(_ code: String, credentialToken: String, context: MSAL.MSALNativeAuthRequestContext, scopes: [String]) async -> SignInSubmitCodeControllerResponse {
        submitCodeResult
    }

    func submitPassword(_ password: String, username: String, credentialToken: String, context: MSAL.MSALNativeAuthRequestContext, scopes: [String]) async -> SignInSubmitPasswordControllerResponse {
        return submitPasswordResult
    }

    func resendCode(credentialToken: String, context: MSAL.MSALNativeAuthRequestContext, scopes: [String]) async -> SignInResendCodeControllerResponse {
        return resendCodeResult
    }
}
