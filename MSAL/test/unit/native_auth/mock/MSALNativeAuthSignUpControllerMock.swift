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

import XCTest
@testable import MSAL
@_implementationOnly import MSAL_Private

class MSALNativeAuthSignUpControllerMock: MSALNativeAuthSignUpControlling {

    var startPasswordResult: MSALNativeAuthSignUpControlling.SignUpStartPasswordControllerResponse!
    var startResult: MSALNativeAuthSignUpControlling.SignUpStartCodeControllerResponse!
    var resendCodeResult: SignUpResendCodeResult!
    var submitCodeResult: MSALNativeAuthSignUpControlling.SignUpSubmitCodeControllerResponse!
    var submitPasswordResult: MSALNativeAuthSignUpControlling.SignUpSubmitPasswordControllerResponse!
    var submitAttributesResult: SignUpAttributesRequiredResult!

    func signUpStartPassword(parameters: MSAL.MSALNativeAuthSignUpStartRequestProviderParameters) async -> MSALNativeAuthSignUpControlling.SignUpStartPasswordControllerResponse {
        return startPasswordResult
    }

    func signUpStartCode(parameters: MSAL.MSALNativeAuthSignUpStartRequestProviderParameters) async -> MSALNativeAuthSignUpControlling.SignUpStartCodeControllerResponse {
        return startResult
    }

    func resendCode(username: String, context: MSIDRequestContext, signUpToken: String) async -> SignUpResendCodeResult {
        return resendCodeResult
    }

    func submitCode(_ code: String, username: String, signUpToken: String, context: MSIDRequestContext) async -> MSALNativeAuthSignUpControlling.SignUpSubmitCodeControllerResponse {
        return submitCodeResult
    }

    func submitPassword(_ password: String, username: String, signUpToken: String, context: MSIDRequestContext) async -> MSALNativeAuthSignUpControlling.SignUpSubmitPasswordControllerResponse {
        return submitPasswordResult
    }

    func submitAttributes(_ attributes: [String : Any], username: String, signUpToken: String, context: MSIDRequestContext) async -> SignUpAttributesRequiredResult {
        return submitAttributesResult
    }
}
