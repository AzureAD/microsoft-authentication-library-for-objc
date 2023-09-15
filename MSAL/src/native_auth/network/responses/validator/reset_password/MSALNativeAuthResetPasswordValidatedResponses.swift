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
    case error(MSALNativeAuthResetPasswordStartValidatedErrorType)
    case unexpectedError
}

enum MSALNativeAuthResetPasswordStartValidatedErrorType: Error {
    case invalidRequest(message: String?)
    case invalidClient(message: String?)
    case userNotFound(message: String?)
    case unsupportedChallengeType(message: String?)
    case userDoesNotHavePassword

    func toResetPasswordStartPublicError() -> ResetPasswordStartError {
        switch self {
        case .userNotFound(let message):
            return .init(type: .userNotFound, message: message)
        case .unsupportedChallengeType(let message),
             .invalidRequest(let message),
             .invalidClient(let message):
            return .init(type: .generalError, message: message)
        case .userDoesNotHavePassword:
            return .init(type: .userDoesNotHavePassword, message: MSALNativeAuthErrorMessage.userDoesNotHavePassword)
        }
    }
}

enum MSALNativeAuthResetPasswordChallengeValidatedResponse: Equatable {
    case success(_ sentTo: String, _ channelTargetType: MSALNativeAuthChannelType, _ codeLength: Int, _ resetPasswordChallengeToken: String)
    case redirect
    case error(MSALNativeAuthResetPasswordChallengeResponseError)
    case unexpectedError
}

enum MSALNativeAuthResetPasswordContinueValidatedResponse: Equatable {
    case success(passwordSubmitToken: String)
    case invalidOOB
    case error(MSALNativeAuthResetPasswordContinueResponseError)
    case unexpectedError
}

enum MSALNativeAuthResetPasswordSubmitValidatedResponse: Equatable {
    case success(passwordResetToken: String, pollInterval: Int)
    case passwordError(error: MSALNativeAuthResetPasswordSubmitResponseError)
    case error(MSALNativeAuthResetPasswordSubmitResponseError)
    case unexpectedError
}

enum MSALNativeAuthResetPasswordPollCompletionValidatedResponse: Equatable {
    case success(status: MSALNativeAuthResetPasswordPollCompletionStatus)
    case passwordError(error: MSALNativeAuthResetPasswordPollCompletionResponseError)
    case error(MSALNativeAuthResetPasswordPollCompletionResponseError)
    case unexpectedError
}
