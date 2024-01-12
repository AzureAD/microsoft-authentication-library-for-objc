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

struct MSALNativeAuthSignUpContinueResponseError: MSALNativeAuthResponseError {
    let error: MSALNativeAuthSignUpContinueOauth2ErrorCode
    let subError: MSALNativeAuthSubErrorCode?
    let errorDescription: String?
    let errorCodes: [Int]?
    let errorURI: String?
    let innerErrors: [MSALNativeAuthInnerError]?
    let continuationToken: String?
    let requiredAttributes: [MSALNativeAuthRequiredAttributeInternal]?
    let unverifiedAttributes: [MSALNativeAuthErrorBasicAttributes]?
    let invalidAttributes: [MSALNativeAuthErrorBasicAttributes]?

    enum CodingKeys: String, CodingKey {
        case error
        case subError = "suberror"
        case errorDescription = "error_description"
        case errorCodes = "error_codes"
        case errorURI = "error_uri"
        case innerErrors = "inner_errors"
        case continuationToken = "continuation_token"
        case requiredAttributes = "required_attributes"
        case unverifiedAttributes = "unverified_attributes"
        case invalidAttributes = "invalid_attributes"
    }
}

extension MSALNativeAuthSignUpContinueResponseError {

    func toVerifyCodePublicError() -> VerifyCodeError {
        switch error {
        case .invalidGrant:
            return subError == .invalidOOBValue ? .init(type: .invalidCode, message: errorDescription)
                                                : .init(type: .generalError, message: errorDescription)
        case .unauthorizedClient,
             .expiredToken,
             .invalidRequest,
             .userAlreadyExists,
             .attributesRequired,
             .verificationRequired,
             .credentialRequired:
            return .init(type: .generalError, message: errorDescription)
        }
    }

    func toPasswordRequiredPublicError() -> PasswordRequiredError {
        switch error {
        case .invalidGrant:
            if let subError, subError.isAnyPasswordError {
                return .init(type: .invalidPassword, message: errorDescription)
            } else {
                return .init(type: .generalError, message: errorDescription)
            }
        case .unauthorizedClient,
             .expiredToken,
             .invalidRequest,
             .userAlreadyExists,
             .attributesRequired,
             .verificationRequired,
             .credentialRequired:
            return .init(type: .generalError, message: errorDescription)
        }
    }

    func toAttributesRequiredPublicError() -> AttributesRequiredError {
        return AttributesRequiredError(message: errorDescription)
    }
}
