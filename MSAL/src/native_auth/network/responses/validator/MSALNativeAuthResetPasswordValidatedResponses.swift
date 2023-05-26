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

enum MSALNativeAuthResetPasswordStartValidatedResponse {
    case success(passwordResetToken: String)
    case redirect
    case error(MSALNativeAuthResetPasswordStartResponseError)
    case unexpectedError
}

enum MSALNativeAuthResetPasswordChallengeValidatedResponse {
    case success(_ displayName: String, _ displayType: String, _ codeLength: Int, _ resetPasswordChallengeToken: String)
    case redirect
    case error(MSALNativeAuthResetPasswordChallengeOauth2ErrorCode)
    case unexpectedError
}

enum MSALNativeAuthResetPasswordContinueValidatedResponse {
    case success(passwordSubmitToken: String)
    case invalidOOB(passwordResetToken: String)
    case error(MSALNativeAuthResetPasswordContinueResponseError)
    case unexpectedError
}

enum MSALNativeAuthResetPasswordSubmitValidatedResponse {
    case success(passwordResetToken: String, pollInterval: Int)
    case passwordError(error: MSALNativeAuthResetPasswordSubmitOauth2ErrorCode, passwordSubmitToken: String?)
    case error(MSALNativeAuthResetPasswordSubmitOauth2ErrorCode)
    case unexpectedError
}

enum MSALNativeAuthResetPasswordPollCompletionValidatedResponse {
    case success(status: MSALNativeAuthResetPasswordPollCompletionStatus)
    case passwordError(error: MSALNativeAuthResetPasswordPollCompletionOauth2ErrorCode, passwordSubmitToken: String?)
    case error(MSALNativeAuthResetPasswordPollCompletionOauth2ErrorCode)
    case unexpectedError
}
