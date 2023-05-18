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

    func convertToSignInStartError() -> SignInStartError {
        switch self {
        case .generalError, .expiredToken, .authorizationPending, .slowDown, .invalidRequest, .invalidServerResponse, .invalidOOBCode:
            return SignInStartError(type: .generalError)
        case .invalidClient:
            return SignInStartError(type: .generalError, message: "Invalid Client ID")
        case .unsupportedChallengeType:
            return SignInStartError(type: .generalError, message: "Unsupported challenge type")
        case .invalidScope:
            return SignInStartError(type: .generalError, message: "Invalid scope")
        case .userNotFound:
            return SignInStartError(type: .userNotFound)
        case .invalidPassword:
            return SignInStartError(type: .invalidPassword)
        case .invalidAuthenticationType:
            return SignInStartError(type: .invalidAuthenticationType)
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
}
