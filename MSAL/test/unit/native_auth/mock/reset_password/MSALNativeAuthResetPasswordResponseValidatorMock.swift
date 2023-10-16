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

@testable import MSAL
@_implementationOnly import MSAL_Private

class MSALNativeAuthResetPasswordResponseValidatorMock: MSALNativeAuthResetPasswordResponseValidating {

    // MARK: Start

    private var resetPasswordStartValidatedResponse: MSALNativeAuthResetPasswordStartValidatedResponse?

    func mockValidateResetPasswordStartFunc(_ response: MSALNativeAuthResetPasswordStartValidatedResponse) {
        self.resetPasswordStartValidatedResponse = response
    }

    func validate(_ result: Result<MSAL.MSALNativeAuthResetPasswordStartResponse, Error>, with context: MSIDRequestContext) -> MSALNativeAuthResetPasswordStartValidatedResponse {

        if let resetPasswordStartValidatedResponse = resetPasswordStartValidatedResponse {
            return resetPasswordStartValidatedResponse
        } else {
            fatalError("Make sure you call mockValidateResetPasswordStartFunc()")
        }
    }

    // MARK: Challenge

    private var resetPasswordChallengeValidatedResponse: MSALNativeAuthResetPasswordChallengeValidatedResponse?

    func mockValidateResetPasswordChallengeFunc(_ response: MSALNativeAuthResetPasswordChallengeValidatedResponse) {
        self.resetPasswordChallengeValidatedResponse = response
    }

    func validate(_ result: Result<MSAL.MSALNativeAuthResetPasswordChallengeResponse, Error>, with context: MSIDRequestContext) -> MSAL.MSALNativeAuthResetPasswordChallengeValidatedResponse {
        if let resetPasswordChallengeValidatedResponse = resetPasswordChallengeValidatedResponse {
            return resetPasswordChallengeValidatedResponse
        } else {
            fatalError("Make sure you call mockValidateResetPasswordChallengeFunc()")
        }
    }

    // MARK: Continue

    private var resetPasswordContinueValidatedResponse: MSALNativeAuthResetPasswordContinueValidatedResponse?

    func mockValidateResetPasswordContinueFunc(_ response: MSALNativeAuthResetPasswordContinueValidatedResponse) {
        self.resetPasswordContinueValidatedResponse = response
    }

    func validate(_ result: Result<MSAL.MSALNativeAuthResetPasswordContinueResponse, Error>, with context: MSIDRequestContext) -> MSAL.MSALNativeAuthResetPasswordContinueValidatedResponse {
        if let resetPasswordContinueValidatedResponse = resetPasswordContinueValidatedResponse {
            return resetPasswordContinueValidatedResponse
        } else {
            fatalError("Make sure you call mockValidateResetPasswordContinueFunc()")
        }
    }

    // MARK: Submit

    private var resetPasswordSubmitValidatedResponse: MSALNativeAuthResetPasswordSubmitValidatedResponse?

    func mockValidateResetPasswordSubmitFunc(_ response: MSALNativeAuthResetPasswordSubmitValidatedResponse) {
        self.resetPasswordSubmitValidatedResponse = response
    }

    func validate(_ result: Result<MSAL.MSALNativeAuthResetPasswordSubmitResponse, Error>, with context: MSIDRequestContext) -> MSAL.MSALNativeAuthResetPasswordSubmitValidatedResponse {
        if let resetPasswordSubmitValidatedResponse = resetPasswordSubmitValidatedResponse {
            return resetPasswordSubmitValidatedResponse
        } else {
            fatalError("Make sure you call mockValidateResetPasswordSubmitFunc()")
        }
    }

    // MARK: PollCompletion

    private var resetPasswordPollCompletionValidatedResponse: MSALNativeAuthResetPasswordPollCompletionValidatedResponse?

    func mockValidateResetPasswordPollCompletionFunc(_ response: MSALNativeAuthResetPasswordPollCompletionValidatedResponse) {
        self.resetPasswordPollCompletionValidatedResponse = response
    }

    func validate(_ result: Result<MSAL.MSALNativeAuthResetPasswordPollCompletionResponse, Error>, with context: MSIDRequestContext) -> MSAL.MSALNativeAuthResetPasswordPollCompletionValidatedResponse {
        if let resetPasswordPollCompletionValidatedResponse = resetPasswordPollCompletionValidatedResponse {
            return resetPasswordPollCompletionValidatedResponse
        } else {
            fatalError("Make sure you call mockValidateResetPasswordPollCompletionFunc()")
        }
    }
}
