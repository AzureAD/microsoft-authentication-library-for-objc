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

struct MSALNativeAuthResetPasswordSubmitResponseError: MSALNativeAuthResponseError {

    let error: MSALNativeAuthResetPasswordSubmitOauth2ErrorCode
    let subError: MSALNativeAuthSubErrorCode?
    let errorDescription: String?
    let errorCodes: [Int]?
    let errorURI: String?
    let innerErrors: [MSALNativeAuthInnerError]?
    let target: String?

    enum CodingKeys: String, CodingKey {
        case error
        case subError = "suberror"
        case errorDescription = "error_description"
        case errorCodes = "error_codes"
        case errorURI = "error_uri"
        case innerErrors = "inner_errors"
        case target
    }
}

extension MSALNativeAuthResetPasswordSubmitResponseError {

    func toPasswordRequiredPublicError() -> PasswordRequiredError {
        switch error {
        case .invalidGrant:
            if let subError, subError.isAnyPasswordError {
                return .init(type: .invalidPassword, message: errorDescription)
            } else {
                return .init(type: .generalError, message: errorDescription)
            }
        case .invalidClient,
             .expiredToken,
             .invalidRequest:
            return .init(type: .generalError, message: errorDescription)
        }
    }
}
