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

import Foundation

enum MSALNativeAuthSignInChallengeValidatedResponse {
    case codeRequired(credentialToken: String, sentTo: String, channelType: MSALNativeAuthChannelType, codeLength: Int)
    case passwordRequired(credentialToken: String)
    case error(MSALNativeAuthSignInChallengeValidatedErrorType)
}

enum MSALNativeAuthSignInChallengeValidatedErrorType: Error {
    case redirect
    case expiredToken
    case invalidToken
    case invalidClient
    case invalidRequest
    case invalidServerResponse
    case userNotFound
    case unsupportedChallengeType

    func convertToSignInCodeStartError() -> SignInStartError {
        switch self {
        case .redirect:
            return .init(type: .browserRequired)
        case .expiredToken, .invalidToken, .invalidRequest, .invalidServerResponse:
            return .init(type: .generalError)
        case .invalidClient:
            return .init(type: .generalError, message: MSALNativeAuthErrorMessage.invalidClient)
        case .userNotFound:
            return .init(type: .userNotFound)
        case .unsupportedChallengeType:
            return .init(type: .generalError, message: MSALNativeAuthErrorMessage.unsupportedChallengeType)
        }
    }

    func convertToSignInPasswordStartError() -> SignInPasswordStartError {
        let codeSignInError = convertToSignInCodeStartError()
        switch codeSignInError.type {
        case .browserRequired:
            return .init(type: .browserRequired, message: codeSignInError.errorDescription)
        case .userNotFound:
            return .init(type: .userNotFound, message: codeSignInError.errorDescription)
        case .invalidUsername:
            return .init(type: .invalidUsername, message: codeSignInError.errorDescription)
        case .generalError:
            return .init(type: .generalError, message: codeSignInError.errorDescription)
        }
    }
}
