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

enum MSALNativeAuthSignUpChallengeOauth2ErrorCode: String, Decodable, CaseIterable {
    case invalidRequest = "invalid_request"
    case invalidClient = "invalid_client"
    case unsupportedChallengeType = "unsupported_challenge_type"
    case expiredToken = "expired_token"
}

extension MSALNativeAuthSignUpChallengeOauth2ErrorCode {

    func toSignUpPasswordStartPublicError() -> SignUpPasswordStartError {
        switch self {
        case .invalidClient:
            return .init(type: .generalError, message: MSALNativeAuthErrorMessage.invalidClient)
        case .unsupportedChallengeType:
            return .init(type: .generalError, message: MSALNativeAuthErrorMessage.unsupportedChallengeType)
        case .expiredToken:
            return .init(type: .generalError, message: MSALNativeAuthErrorMessage.expiredToken)
        case .invalidRequest:
            return .init(type: .generalError)
        }
    }

    func toSignUpCodeStartPublicError() -> SignUpCodeStartError {
        switch self {
        case .invalidClient:
            return .init(type: .generalError, message: MSALNativeAuthErrorMessage.invalidClient)
        case .unsupportedChallengeType:
            return .init(type: .generalError, message: MSALNativeAuthErrorMessage.unsupportedChallengeType)
        case .expiredToken:
            return .init(type: .generalError, message: MSALNativeAuthErrorMessage.expiredToken)
        case .invalidRequest:
            return .init(type: .generalError)
        }
    }

    func toResendCodePublicError() -> MSALNativeAuthGenericError {
        switch self {
        case .invalidClient:
            return .init(message: MSALNativeAuthErrorMessage.invalidClient)
        case .unsupportedChallengeType:
            return .init(message: MSALNativeAuthErrorMessage.unsupportedChallengeType)
        case .expiredToken:
            return .init(message: MSALNativeAuthErrorMessage.expiredToken)
        case .invalidRequest:
            return .init()
        }
    }

    func toPasswordRequiredPublicError() -> PasswordRequiredError {
        switch self {
        case .invalidClient:
            return .init(type: .generalError, message: MSALNativeAuthErrorMessage.invalidClient)
        case .unsupportedChallengeType:
            return .init(type: .generalError, message: MSALNativeAuthErrorMessage.unsupportedChallengeType)
        case .expiredToken:
            return .init(type: .generalError, message: MSALNativeAuthErrorMessage.expiredToken)
        case .invalidRequest:
            return .init(type: .generalError)
        }
    }
}
