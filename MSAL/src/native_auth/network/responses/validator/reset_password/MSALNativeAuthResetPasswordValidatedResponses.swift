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

@_implementationOnly import MSAL_Private

enum MSALNativeAuthResetPasswordStartValidatedResponse: Equatable {
    case success(continuationToken: String)
    case redirect
    case error(MSALNativeAuthResetPasswordStartValidatedErrorType)
    case unexpectedError(MSALNativeAuthResetPasswordStartResponseError?)
}

enum MSALNativeAuthResetPasswordStartValidatedErrorType: Equatable, Error {
    case invalidRequest(MSALNativeAuthResetPasswordStartResponseError)
    case unauthorizedClient(MSALNativeAuthResetPasswordStartResponseError)
    case userNotFound(MSALNativeAuthResetPasswordStartResponseError)
    case unsupportedChallengeType(MSALNativeAuthResetPasswordStartResponseError)
    case userDoesNotHavePassword(MSALNativeAuthResetPasswordStartResponseError)
    case unexpectedError(MSALNativeAuthResetPasswordStartResponseError?)

    func toResetPasswordStartPublicError(context: MSIDRequestContext) -> ResetPasswordStartError {
        switch self {
        case .userNotFound(let apiError):
            return .init(
                type: .userNotFound,
                message: apiError.errorDescription,
                correlationId: context.correlationId(),
                errorCodes: apiError.errorCodes ?? [],
                errorUri: apiError.errorURI
            )
        case .unsupportedChallengeType(let apiError),
             .invalidRequest(let apiError),
             .unauthorizedClient(let apiError):
            return .init(
                type: .generalError,
                message: apiError.errorDescription,
                correlationId: context.correlationId(),
                errorCodes: apiError.errorCodes ?? [],
                errorUri: apiError.errorURI
            )
        case .userDoesNotHavePassword(let apiError):
            return .init(
                type: .userDoesNotHavePassword,
                message: apiError.errorDescription,
                correlationId: context.correlationId(),
                errorCodes: apiError.errorCodes ?? [],
                errorUri: apiError.errorURI
            )
        case .unexpectedError(let apiError):
            return .init(
                type: .generalError,
                message: apiError?.errorDescription,
                correlationId: context.correlationId(),
                errorUri: apiError?.errorURI
            )
        }
    }
}

enum MSALNativeAuthResetPasswordChallengeValidatedResponse: Equatable {
    case success(_ sentTo: String, _ channelTargetType: MSALNativeAuthChannelType, _ codeLength: Int, _ resetPasswordChallengeToken: String)
    case redirect
    case error(MSALNativeAuthResetPasswordChallengeResponseError)
    case unexpectedError(MSALNativeAuthResetPasswordChallengeResponseError?)
}

enum MSALNativeAuthResetPasswordContinueValidatedResponse: Equatable {
    case success(continuationToken: String)
    case invalidOOB(MSALNativeAuthResetPasswordContinueResponseError)
    case error(MSALNativeAuthResetPasswordContinueResponseError)
    case unexpectedError(MSALNativeAuthResetPasswordContinueResponseError?)
}

enum MSALNativeAuthResetPasswordSubmitValidatedResponse: Equatable {
    case success(continuationToken: String, pollInterval: Int)
    case passwordError(error: MSALNativeAuthResetPasswordSubmitResponseError)
    case error(MSALNativeAuthResetPasswordSubmitResponseError)
    case unexpectedError(MSALNativeAuthResetPasswordSubmitResponseError?)
}

enum MSALNativeAuthResetPasswordPollCompletionValidatedResponse: Equatable {
    case success(status: MSALNativeAuthResetPasswordPollCompletionStatus, continuationToken: String?)
    case passwordError(error: MSALNativeAuthResetPasswordPollCompletionResponseError)
    case error(MSALNativeAuthResetPasswordPollCompletionResponseError)
    case unexpectedError(MSALNativeAuthResetPasswordPollCompletionResponseError?)
}
