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

@_implementationOnly import MSAL_Private

enum MSALNativeAuthSignInChallengeValidatedResponse {
    case codeRequired(continuationToken: String, sentTo: String, channelType: MSALNativeAuthChannelType, codeLength: Int, correlationId: UUID?)
    case passwordRequired(continuationToken: String, correlationId: UUID?)
    case error(MSALNativeAuthSignInChallengeValidatedErrorType)
}

enum MSALNativeAuthSignInChallengeValidatedErrorType: Error {
    case redirect
    case expiredToken(MSALNativeAuthSignInChallengeResponseError)
    case invalidToken(MSALNativeAuthSignInChallengeResponseError)
    case unauthorizedClient(MSALNativeAuthSignInChallengeResponseError)
    case invalidRequest(message: String?, correlationId: UUID?)
    case unexpectedError(message: String?)
    case userNotFound(MSALNativeAuthSignInChallengeResponseError)
    case unsupportedChallengeType(MSALNativeAuthSignInChallengeResponseError)

    func convertToSignInStartError(context: MSIDRequestContext) -> SignInStartError {
        switch self {
        case .redirect:
            return .init(type: .browserRequired, correlationId: context.correlationId())
        case .unexpectedError(let message):
            return .init(type: .generalError, message: message, correlationId: context.correlationId())
        case .invalidRequest(let message, let correlationId):
            return .init(type: .generalError, message: message, correlationId: correlationId ?? context.correlationId())
        case .expiredToken(let apiError),
             .invalidToken(let apiError),
             .unauthorizedClient(let apiError),
             .unsupportedChallengeType(let apiError):
            return .init(
                type: .generalError,
                message: apiError.errorDescription,
                correlationId: apiError.getHeaderCorrelationId() ?? context.correlationId(),
                errorCodes: apiError.errorCodes ?? []
            )
        case .userNotFound(let apiError):
            return .init(
                type: .userNotFound,
                message: apiError.errorDescription,
                correlationId: apiError.getHeaderCorrelationId() ?? context.correlationId(),
                errorCodes: apiError.errorCodes ?? []
            )
        }
    }

    func convertToResendCodeError(context: MSIDRequestContext) -> ResendCodeError {
        switch self {
        case .redirect:
            return .init(correlationId: context.correlationId())
        case .invalidRequest(let message, let correlationId):
            return .init(message: message, correlationId: correlationId ?? context.correlationId())
        case .expiredToken(let apiError),
             .invalidToken(let apiError),
             .unauthorizedClient(let apiError),
             .userNotFound(let apiError),
             .unsupportedChallengeType(let apiError):
            return .init(
                message: apiError.errorDescription,
                correlationId: apiError.getHeaderCorrelationId() ?? context.correlationId(),
                errorCodes: apiError.errorCodes ?? []
            )
        case .unexpectedError(let message):
            return .init(message: message, correlationId: context.correlationId())
        }
    }
}
