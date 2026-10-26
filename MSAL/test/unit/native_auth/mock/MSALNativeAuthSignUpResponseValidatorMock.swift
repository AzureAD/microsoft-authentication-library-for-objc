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

class MSALNativeAuthSignUpResponseValidatorMock: MSALNativeAuthSignUpResponseValidating {

    private var signUpStartValidatedResponse: MSALNativeAuthSignUpStartValidatedResponse?
    private var signUpChallengeValidatedResponse: MSALNativeAuthSignUpChallengeValidatedResponse?
    private var signUpContinueContinueResponse: MSALNativeAuthSignUpContinueValidatedResponse?

    func mockValidateSignUpStartFunc(_ response: MSALNativeAuthSignUpStartValidatedResponse) {
        self.signUpStartValidatedResponse = response
    }

    func validate(_ result: Result<MSAL.MSALNativeAuthSignUpStartResponse, Error>, with context: MSIDRequestContext) -> MSAL.MSALNativeAuthSignUpStartValidatedResponse {
        if let signUpStartValidatedResponse = signUpStartValidatedResponse {
            return signUpStartValidatedResponse
        } else {
            fatalError("Make sure you call mockValidateSignUpStartFunc()")
        }
    }

    func mockValidateSignUpChallengeFunc(_ response: MSALNativeAuthSignUpChallengeValidatedResponse) {
        self.signUpChallengeValidatedResponse = response
    }

    func validate(_ result: Result<MSAL.MSALNativeAuthSignUpChallengeResponse, Error>, with context: MSIDRequestContext) -> MSAL.MSALNativeAuthSignUpChallengeValidatedResponse {
        if let signUpChallengeValidatedResponse = signUpChallengeValidatedResponse {
            return signUpChallengeValidatedResponse
        } else {
            fatalError("Make sure you call mockValidateSignUpChallengeFunc()")
        }
    }

    func mockValidateSignUpContinueFunc(_ response: MSALNativeAuthSignUpContinueValidatedResponse) {
        self.signUpContinueContinueResponse = response
    }

    func validate(_ result: Result<MSAL.MSALNativeAuthSignUpContinueResponse, Error>, with context: MSIDRequestContext) -> MSAL.MSALNativeAuthSignUpContinueValidatedResponse {
        if let signUpContinueContinueResponse = signUpContinueContinueResponse {
            return signUpContinueContinueResponse
        } else {
            fatalError("Make sure you call mockValidateSignUpContinueFunc()")
        }
    }
}
