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
    case expiredToken(message: String?)
    case expiredRefreshToken(message: String?)
    case invalidClient(message: String?)
    case invalidRequest(message: String?)
    case invalidServerResponse
    case userNotFound(message: String?)
    case invalidPassword(message: String?)
    case invalidOOBCode(message: String?)
    case unsupportedChallengeType(message: String?)
    case strongAuthRequired(message: String?)
    case invalidScope(message: String?)
    case authorizationPending(message: String?)
    case slowDown(message: String?)

    func convertToSignInPasswordStartError() -> SignInPasswordStartError {
        switch self {
        case .expiredToken(let message),
             .authorizationPending(let message),
             .slowDown(let message),
             .invalidRequest(let message),
             .invalidOOBCode(let message),
             .invalidClient(let message),
             .unsupportedChallengeType(let message),
             .invalidScope(let message):
            return SignInPasswordStartError(type: .generalError, message: message)
        case .generalError:
            return SignInPasswordStartError(type: .generalError)
        case .invalidServerResponse:
            return SignInPasswordStartError(type: .generalError, message: MSALNativeAuthErrorMessage.invalidServerResponse)
        case .userNotFound(let message):
            return SignInPasswordStartError(type: .userNotFound, message: message)
        case .invalidPassword(let message):
            return SignInPasswordStartError(type: .invalidPassword, message: message)
        case .strongAuthRequired(let message):
            return SignInPasswordStartError(type: .browserRequired, message: message)
        case .expiredRefreshToken(let message):
            MSALLogger.log(level: .error, context: nil, format: "Error not treated - \(self))")
            return SignInPasswordStartError(type: .generalError, message: message)
        }
    }

    func convertToRetrieveAccessTokenError() -> RetrieveAccessTokenError {
        switch self {
        case .expiredToken(let message),
             .authorizationPending(let message),
             .slowDown(let message),
             .invalidRequest(let message),
             .invalidClient(let message),
             .unsupportedChallengeType(let message),
             .invalidScope(let message):
            return RetrieveAccessTokenError(type: .generalError, message: message)
        case .generalError:
            return RetrieveAccessTokenError(type: .generalError)
        case .invalidServerResponse:
            return RetrieveAccessTokenError(type: .generalError, message: MSALNativeAuthErrorMessage.invalidServerResponse)
        case .expiredRefreshToken:
            return RetrieveAccessTokenError(type: .refreshTokenExpired)
        case .strongAuthRequired(let message):
            return RetrieveAccessTokenError(type: .browserRequired, message: message)
        case .userNotFound(let message),
             .invalidPassword(let message),
             .invalidOOBCode(let message):
            MSALLogger.log(level: .error, context: nil, format: "Error not treated - \(self))")
            return RetrieveAccessTokenError(type: .generalError, message: message)
        }
    }

    func convertToVerifyCodeError() -> VerifyCodeError {
        switch self {
        case .invalidOOBCode(let message):
            return VerifyCodeError(type: .invalidCode, message: message)
        case .strongAuthRequired(let message):
            return VerifyCodeError(type: .browserRequired, message: message)
        case .expiredToken(let message),
             .authorizationPending(let message),
             .slowDown(let message),
             .invalidRequest(let message),
             .invalidClient(let message),
             .unsupportedChallengeType(let message),
             .invalidScope(let message),
             .expiredRefreshToken(let message),
             .userNotFound(let message),
             .invalidPassword(let message):
            return VerifyCodeError(type: .generalError, message: message)
        case .generalError:
            return VerifyCodeError(type: .generalError)
        case .invalidServerResponse:
            return VerifyCodeError(type: .generalError, message: MSALNativeAuthErrorMessage.invalidServerResponse)
        }
    }

    func convertToPasswordRequiredError() -> PasswordRequiredError {
        return PasswordRequiredError(signInPasswordError: convertToSignInPasswordStartError())
    }
}
