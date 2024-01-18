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

enum MSALNativeAuthTokenValidatedResponse {
    case success(MSIDTokenResponse)
    case error(MSALNativeAuthTokenValidatedErrorType)
}

enum MSALNativeAuthTokenValidatedErrorType: Error {
    case generalError
    case expiredToken(MSALNativeAuthTokenResponseError)
    case expiredRefreshToken(MSALNativeAuthTokenResponseError)
    case unauthorizedClient(MSALNativeAuthTokenResponseError)
    case invalidRequest(MSALNativeAuthTokenResponseError)
    case unexpectedError(message: String?)
    case userNotFound(MSALNativeAuthTokenResponseError)
    case invalidPassword(MSALNativeAuthTokenResponseError)
    case invalidOOBCode(MSALNativeAuthTokenResponseError)
    case unsupportedChallengeType(MSALNativeAuthTokenResponseError)
    case strongAuthRequired(MSALNativeAuthTokenResponseError)
    case invalidScope(MSALNativeAuthTokenResponseError)
    case authorizationPending(MSALNativeAuthTokenResponseError)
    case slowDown(MSALNativeAuthTokenResponseError)

    // swiftlint:disable:next function_body_length
    func convertToSignInPasswordStartError(context: MSIDRequestContext) -> SignInStartError {
        switch self {
        case .expiredToken(let apiError),
             .authorizationPending(let apiError),
             .slowDown(let apiError),
             .invalidOOBCode(let apiError),
             .unauthorizedClient(let apiError),
             .unsupportedChallengeType(let apiError),
             .invalidScope(let apiError),
             .invalidRequest(let apiError):
            return SignInStartError(
                type: .generalError,
                message: apiError.errorDescription,
                correlationId: apiError.getHeaderCorrelationId() ?? context.correlationId(),
                errorCodes: apiError.errorCodes ?? []
            )
        case .generalError:
            return SignInStartError(type: .generalError, correlationId: context.correlationId())
        case .unexpectedError(let message):
            return SignInStartError(
                type: .generalError,
                message: message,
                correlationId: context.correlationId()
            )
        case .userNotFound(let apiError):
            return SignInStartError(
                type: .userNotFound,
                message: apiError.errorDescription,
                correlationId: apiError.getHeaderCorrelationId() ?? context.correlationId(),
                errorCodes: apiError.errorCodes ?? []
            )
        case .invalidPassword(let apiError):
            return SignInStartError(
                type: .invalidCredentials,
                message: apiError.errorDescription,
                correlationId: apiError.getHeaderCorrelationId() ?? context.correlationId(),
                errorCodes: apiError.errorCodes ?? []
            )
        case .strongAuthRequired(let apiError):
            return SignInStartError(
                type: .browserRequired,
                message: apiError.errorDescription,
                correlationId: apiError.getHeaderCorrelationId() ?? context.correlationId(),
                errorCodes: apiError.errorCodes ?? []
            )
        case .expiredRefreshToken(let apiError):
            MSALLogger.log(level: .error, context: nil, format: "Error not treated - \(self))")
            return SignInStartError(
                type: .generalError,
                message: apiError.errorDescription,
                correlationId: apiError.getHeaderCorrelationId() ?? context.correlationId(),
                errorCodes: apiError.errorCodes ?? []
            )
        }
    }

    func convertToRetrieveAccessTokenError(context: MSIDRequestContext) -> RetrieveAccessTokenError {
        switch self {
        case .expiredToken(let apiError),
             .authorizationPending(let apiError),
             .slowDown(let apiError),
             .unauthorizedClient(let apiError),
             .unsupportedChallengeType(let apiError),
             .invalidScope(let apiError),
             .invalidRequest(let apiError):
            return RetrieveAccessTokenError(
                type: .generalError,
                message: apiError.errorDescription,
                correlationId: apiError.getHeaderCorrelationId() ?? context.correlationId(),
                errorCodes: apiError.errorCodes ?? []
            )
        case .generalError:
            return RetrieveAccessTokenError(type: .generalError, correlationId: context.correlationId())
        case .unexpectedError(message: let message):
            return RetrieveAccessTokenError(
                type: .generalError,
                message: message,
                correlationId: context.correlationId()
            )
        case .expiredRefreshToken(let apiError):
            return RetrieveAccessTokenError(
                type: .refreshTokenExpired,
                message: apiError.errorDescription,
                correlationId: apiError.getHeaderCorrelationId() ?? context.correlationId(),
                errorCodes: apiError.errorCodes ?? []
            )
        case .strongAuthRequired(let apiError):
            return RetrieveAccessTokenError(
                type: .browserRequired,
                message: apiError.errorDescription,
                correlationId: apiError.getHeaderCorrelationId() ?? context.correlationId(),
                errorCodes: apiError.errorCodes ?? []
            )
        case .userNotFound(let apiError),
             .invalidPassword(let apiError),
             .invalidOOBCode(let apiError):
            MSALLogger.log(level: .error, context: nil, format: "Error not treated - \(self))")
            return RetrieveAccessTokenError(
                type: .generalError,
                message: apiError.errorDescription,
                correlationId: apiError.getHeaderCorrelationId() ?? context.correlationId(),
                errorCodes: apiError.errorCodes ?? []
            )
        }
    }

    func convertToVerifyCodeError(context: MSIDRequestContext) -> VerifyCodeError {
        switch self {
        case .invalidOOBCode(let apiError):
            return VerifyCodeError(
                type: .invalidCode,
                message: apiError.errorDescription,
                correlationId: apiError.getHeaderCorrelationId() ?? context.correlationId(),
                errorCodes: apiError.errorCodes ?? []
            )
        case .strongAuthRequired(let apiError):
            return VerifyCodeError(
                type: .browserRequired,
                message: apiError.errorDescription,
                correlationId: apiError.getHeaderCorrelationId() ?? context.correlationId(),
                errorCodes: apiError.errorCodes ?? []
            )
        case .expiredToken(let apiError),
             .authorizationPending(let apiError),
             .slowDown(let apiError),
             .unauthorizedClient(let apiError),
             .unsupportedChallengeType(let apiError),
             .invalidScope(let apiError),
             .expiredRefreshToken(let apiError),
             .userNotFound(let apiError),
             .invalidPassword(let apiError),
             .invalidRequest(let apiError):
            return VerifyCodeError(
                type: .generalError,
                message: apiError.errorDescription,
                correlationId: apiError.getHeaderCorrelationId() ?? context.correlationId(),
                errorCodes: apiError.errorCodes ?? []
            )
        case .generalError:
            return VerifyCodeError(type: .generalError, correlationId: context.correlationId())
        case .unexpectedError(let message):
            return VerifyCodeError(type: .generalError, message: message, correlationId: context.correlationId())
        }
    }

    func convertToPasswordRequiredError(context: MSIDRequestContext) -> PasswordRequiredError {
        return PasswordRequiredError(signInStartError: convertToSignInPasswordStartError(context: context))
    }
}
