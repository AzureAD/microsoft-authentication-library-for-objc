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

enum MSALNativeAuthSignInTokenValidatedResponse {
    case success(MSIDTokenResult, MSIDTokenResponse)
    case credentialRequired(String)
    case error(MSALNativeAuthSignInTokenValidatedErrorType)
}

enum MSALNativeAuthSignInTokenValidatedErrorType: Error {
    case generalError
    case expiredToken
    case invalidClient
    case invalidRequest
    case invalidServerResponse
    case userNotFound
    case invalidPassword
    case invalidAuthenticationType
    case invalidOOBCode
    case unsupportedChallengeType
    case invalidScope
    case authorizationPending
    case slowDown

    func convertToSignInPasswordStartError() -> SignInPasswordStartError {
        switch self {
        case .generalError, .expiredToken, .authorizationPending, .slowDown, .invalidRequest, .invalidServerResponse, .invalidOOBCode:
            return SignInPasswordStartError(type: .generalError)
        case .invalidClient:
            return SignInPasswordStartError(type: .generalError, message: MSALNativeAuthErrorMessage.invalidClient)
        case .unsupportedChallengeType:
            return SignInPasswordStartError(type: .generalError, message: MSALNativeAuthErrorMessage.unsupportedChallengeType)
        case .invalidScope:
            return SignInPasswordStartError(type: .generalError, message: MSALNativeAuthErrorMessage.invalidScope)
        case .userNotFound:
            return SignInPasswordStartError(type: .userNotFound)
        case .invalidPassword:
            return SignInPasswordStartError(type: .invalidPassword)
        case .invalidAuthenticationType:
            return SignInPasswordStartError(type: .invalidAuthenticationType, message: MSALNativeAuthErrorMessage.useSignInCode)
        }
    }

    func convertToVerifyCodeError() -> VerifyCodeError {
        switch self {
        case .invalidOOBCode:
            return VerifyCodeError(type: .invalidCode)
        default:
            return VerifyCodeError(type: .generalError, message: self.localizedDescription)
        }
    }

    func convertToPasswordRequiredError() -> PasswordRequiredError {
        return PasswordRequiredError(signInPasswordError: convertToSignInPasswordStartError())
    }
}
