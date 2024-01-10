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
    case codeRequired(continuationToken: String, sentTo: String, channelType: MSALNativeAuthChannelType, codeLength: Int)
    case passwordRequired(continuationToken: String)
    case error(MSALNativeAuthSignInChallengeValidatedErrorType)
}

enum MSALNativeAuthSignInChallengeValidatedErrorType: Error {
    case redirect
    case expiredToken(message: String?)
    case invalidToken(message: String?)
    case invalidClient(message: String?)
    case invalidRequest(message: String?)
    case invalidServerResponse
    case userNotFound(message: String?)
    case unsupportedChallengeType(message: String?)

    func convertToSignInStartError() -> SignInStartError {
        switch self {
        case .redirect:
            return .init(type: .browserRequired)
        case .invalidServerResponse:
            return .init(type: .generalError)
        case .expiredToken(let message),
             .invalidToken(let message),
             .invalidRequest(let message):
            return .init(type: .generalError, message: message)
        case .invalidClient(let message):
            return .init(type: .generalError, message: message)
        case .userNotFound(let message):
            return .init(type: .userNotFound, message: message)
        case .unsupportedChallengeType(let message):
            return .init(type: .generalError, message: message)
        }
    }
}
