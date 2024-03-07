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

struct MSALNativeAuthSignUpChallengeResponseError: MSALNativeAuthResponseError {
    let error: MSALNativeAuthSignUpChallengeOauth2ErrorCode
    let errorDescription: String?
    let errorCodes: [Int]?
    let errorURI: String?
    let innerErrors: [MSALNativeAuthInnerError]?
    var correlationId: UUID?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
        case errorCodes = "error_codes"
        case errorURI = "error_uri"
        case innerErrors = "inner_errors"
        case correlationId
    }

    init(
        error: MSALNativeAuthSignUpChallengeOauth2ErrorCode = .unknown,
        errorDescription: String? = nil,
        errorCodes: [Int]? = nil,
        errorURI: String? = nil,
        innerErrors: [MSALNativeAuthInnerError]? = nil,
        correlationId: UUID? = nil
    ) {
        self.error = error
        self.errorDescription = errorDescription
        self.errorCodes = errorCodes
        self.errorURI = errorURI
        self.innerErrors = innerErrors
        self.correlationId = correlationId
    }
}

extension MSALNativeAuthSignUpChallengeResponseError {

    func toSignUpStartPublicError(correlationId: UUID) -> SignUpStartError {
        switch error {
        case .unauthorizedClient,
             .unsupportedChallengeType,
             .expiredToken,
             .invalidRequest,
             .unknown:
            return .init(
                type: .generalError,
                message: errorDescription,
                correlationId: correlationId,
                errorCodes: errorCodes ?? [],
                errorUri: errorURI
            )
        }
    }

    func toResendCodePublicError(correlationId: UUID) -> ResendCodeError {
        switch error {
        case .unauthorizedClient,
             .unsupportedChallengeType,
             .expiredToken,
             .invalidRequest,
             .unknown:
            return .init(
                message: errorDescription,
                correlationId: correlationId,
                errorCodes: errorCodes ?? [],
                errorUri: errorURI
            )
        }
    }

    func toPasswordRequiredPublicError(correlationId: UUID) -> PasswordRequiredError {
        switch error {
        case .unauthorizedClient,
             .unsupportedChallengeType,
             .expiredToken,
             .invalidRequest,
             .unknown:
            return .init(
                type: .generalError,
                message: errorDescription,
                correlationId: correlationId,
                errorCodes: errorCodes ?? [],
                errorUri: errorURI
            )
        }
    }
}
